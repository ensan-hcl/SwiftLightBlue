// Status: Syntax: DONE
// Status: Semantics: NOT DONE

import Foundation

struct ChartParser {
    struct Position: Hashable {
        internal init(_ i: Int, _ j: Int) {
            self.i = i
            self.j = j
        }

        var i: Int
        var j: Int


    }
    typealias Chart = [Position: [Node]]
    typealias PartialChart = (Chart, [Int], Int, String)

    func parse(_ beamWidth: Int, sentence: String) -> Chart {
        if sentence.isEmpty {
            return [:]
        }
        let lexicon = setupLexicon(sentence: sentence.replacing("―", with: "。"))
        let text = purifyText(sentence: sentence)
        let result = text.reduce(([:], [0], 0, "")) { (partialResult, char) in
            chartAccumulator(beamWidth, lexicon, partialResult, char)
        }
        return result.0
    }

    /// Removes occurrences of non-letters from an input text.
    func purifyText(sentence: some StringProtocol) -> String {
        return String(sentence.compactMap { (c: Character) in
            if c.isWhitespace {
                return nil
            }
            if "！？!?…「」◎○●▲△▼▽■□◆◇★☆※†‡.".contains(c) {
                return nil
            }
            if "，,-―?／＼".contains(c) {
                return "、"
            }
            return c
        })
    }


    func chartAccumulator(_ beamWidth: Int, _ lexicon: [Node], _ partialChart: PartialChart, _ char: Character) -> PartialChart {
        let (chart, seplist, i, stack) = partialChart
        guard let sep = seplist.first else {
            print("Empty seplist")
            return ([:], [0], 0, "")
        }
        if char == "、" {
            var newChart: Chart = chart.reduce(into: [:]) { (result: inout Chart, item) in
                punctFilter(sep, i, &result, item)
            }
            newChart[Position(i,i+1)] = [
                andCONJ(String(char)),
                emptyCM(String(char)),
            ]
            let newStack = String(char) + stack
            return (newChart, [i+1] + seplist, i+1, newStack)
        }
        if char == "。" {
            let newChart: Chart = chart.reduce(into: [:]) { (result: inout Chart, item) in
                punctFilter(sep, i, &result, item)
            }
            let newStack = String(char) + stack
            return (newChart, [i+1] + seplist, i+1, newStack)
        }

        let newStack = String(char) + stack
        let (newChart, _, _, _) = newStack.reduce((chart, "", i, i+1)) { (partialResult, c) in
            boxAccumulator(beamWidth, lexicon, partialResult, c)
        }
        let newSeps: [Int]
        if ["「", "『"].contains(char) {
            newSeps = [i+1] + seplist
        } else if ["」", "』"].contains(char) {
            newSeps = Array(seplist.dropFirst())
        } else {
            newSeps = seplist
        }
        return (newChart, newSeps, i+1, newStack)
    }

    func andCONJ(_ c: String) -> Node {
        lexicalitem(c, "punct", 100, .CONJ)
    }

    // Empty case marker
    func emptyCM(_ c: String) -> Node {
        lexicalitem(c, "punct", 99, .BS(.SL(.T(true, 1, modifiableS), .BS(.T(true, 1, modifiableS), .NP([.F([.Ga, .O])]))), .NP([.F([.Nc])])))
    }

     // Previous pivot
    func punctFilter(_ sep: Int, _ i: Int, _ charList: inout Chart, _ e: Chart.Element) {
        let from = e.key.i
        let to = e.key.j
        if to == i {
            charList[Position(from, to+1)] = e.value.filter(\.cat.isBunsetsu)
        }
        charList[e.key] = e.value
    }

    typealias PartialBox = (Chart, String, Int, Int)
    func boxAccumulator(_ beamWidth: Int, _ lexicon: [Node], _ partialBox: PartialBox, _ char: Character) -> PartialBox {
        let (chart, word, i, j) = partialBox
        let newWord = String(char) + word
        let list0 = newWord.count >= 23 ? [] : lookupLexicon(word: newWord, lexicon: lexicon)
        let list1 = checkEmptyCategories(
            checkParenthesisRule(
                i,
                j,
                chart,
                checkCoordinationRule(
                    i,
                    j,
                    chart,
                    checkBinaryRules(
                        i,
                        j,
                        chart,
                        checkUnaryRules(
                            prevlist: list0
                        )
                    )
                )
            )
        )

        var newChart = chart
        // 降順でソートする
        newChart[Position(i, j)] = Array(list1.sorted().reversed().prefix(beamWidth))
        return (newChart, newWord, i-1, j)
    }

    func lookupChart(_ i: Int, _ j: Int, _ chart: Chart) -> [Node] {
        return chart[Position(i, j), default: []]
    }

    func checkUnaryRules(prevlist: [Node]) -> [Node] {
        prevlist + prevlist.flatMap {
            unaryRules(node: $0)
        }
    }

    func checkBinaryRules(_ i: Int, _ j: Int, _ chart: Chart, _ prevlist: [Node]) -> [Node] {
        return (i+1..<j).reduce(into: prevlist) { acck, k in
            acck.append(contentsOf: lookupChart(i, k, chart).flatMap { lnode in
                lookupChart(k, j, chart).flatMap { rnode in
                    binaryRules(lnode: lnode, rnode: rnode)
                }
            })
        }
    }

    func checkCoordinationRule(_ i: Int, _ j: Int, _ chart: Chart, _ prevlist: [Node]) -> [Node] {
        if i+1 > j-1 {
            return prevlist
        }
        return (i+1..<j-1).reduce(prevlist) { acck, k in
            (lookupChart(k, k+1, chart)).reduce(acck) { accc, cnode in
                guard case .CONJ = cnode.cat else {
                    return accc
                }
                return (lookupChart(i, k, chart)).reduce(accc) { accl, lnode in
                    return (lookupChart(k+1, j, chart)).reduce(accl) { accr, rnode in
                        return accr + coordinationRule(lnode: lnode, cnode: cnode, rnode: rnode)
                    }
                }
            }
        }
    }

    func checkParenthesisRule(_ i: Int, _ j: Int, _ chart: Chart, _ prevlist: [Node]) -> [Node] {
        if (i+3 <= j) {
            let result = lookupChart(i, i+1, chart).filter{ $0.cat == .LPAREN }.reduce(prevlist) { accl, lnode in
                lookupChart(j-1, j, chart).filter {$0.cat == .RPAREN}.reduce(accl) { accr, rnode in
                    (lookupChart(i+1, j-1, chart)).reduce(accr) { accc, cnode in
                        accc + parenthesisRule(lnode: lnode, cnode: cnode, rnode: rnode)
                    }
                }
            }
            return result
        } else {
            return prevlist
        }
    }

    func checkEmptyCategories(_ prevlist: [Node]) -> [Node] {
        let result = emptyCategories.reduce(prevlist) { p, ec in
            p.flatMap { node in
                [node] + binaryRules(lnode: node, rnode: ec) + binaryRules(lnode: ec, rnode: node)
            }
        }
        return result
    }

    func simpleParse(_ beamWidth: Int, sentence: String) -> [Node] {
        let chart = parse(beamWidth, sentence: sentence)
        switch extractParseResult(beamWidth, chart) {
        case .failed: return []
        case let .full(nodes), let .partial(nodes): return nodes
        }
    }

    enum ParseResult: Equatable {
        case full([Node])
        case partial([Node])
        case failed
    }

    enum Ordering {
        case GT, LT, EQ
    }

    func isLessPriviledgedThan (lhs: Position, rhs: Position) -> Ordering {
        if lhs == rhs {
            return .EQ
        }
        if rhs.j > lhs.j {
            return .GT
        }
        if lhs.j == rhs.j && rhs.i < lhs.i {
            return .GT
        }
        return .LT
    }

    func extractParseResult(_ beamWidth: Int, _ chart: Chart) -> ParseResult {
        let result = chart.sorted(by: {isLessPriviledgedThan(lhs: $0.key, rhs: $1.key) == .LT})
        func f(_ c: [Chart.Element]) -> ParseResult {
            guard let first = c.first else {
                return .failed
            }
            let (p, nodes) = first
            let sorted = sortByNumberOfArgs(nodes)
            if p.i == 0 {
                return .full(sorted.map(wrapNode))
            } else  {
                return .partial(g(sorted.map(wrapNode), c.filter{$0.key.j <= p.i}))
            }
        }
        func g(_ results: [Node], _ c: [Chart.Element]) -> [Node] {
            guard let first = c.first else {
                return results
            }
            let (p, nodes) = first
            return g(Array(results.flatMap {y in
                nodes.map(wrapNode).map {x in
                    conjoinNodes(x, y)
                }
            }.prefix(beamWidth)), c.dropFirst().filter {$0.key.j <= p.i})
        }

        return f(result)
    }

    func sortByNumberOfArgs(_ nodes: [Node]) -> [Node] {
        return nodes.sorted(by: { (l, r) in
            let nl = numberOfArgs(l.cat)
            let nr = numberOfArgs(r.cat)
            if nl == nr {
                return l.score > r.score
            }
            return nl < nr
        })
    }

    /// receives a category and returns an integer based on the number of arguments of the category, which is used for sorting nodes with respect to which node is considered to be a better result of the parsing.  Lesser is better, but non-propositional categories (such as NP, CONJ, LPAREN and RPAREN) are the worst (=10) even if they take no arguments.
    /// - note: 元の実装で「numberOfArgs」と呼ばれているのをそのまま用いているが、どちらかというとカテゴリのスコアに近い概念だと考えると良い。少ないほど評価が高い。また、コメントでは`CONJ`や`LPAREN`、`RPAREN`も10となるように読めるが、実装に従って100にした。
    func numberOfArgs(_ cat: Cat) -> Int {
        switch cat {
        case let .SL(x, _), let .BS(x, _): return numberOfArgs(x) + 1
        case let .T(_, _, c): return numberOfArgs(c)
        case .S: return 1
        case .NP: return 10
        case .Sbar: return 0
        case .N: return 2
        case .CONJ, .LPAREN, .RPAREN: return 100
        }
    }
}
