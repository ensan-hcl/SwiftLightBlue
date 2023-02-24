import XCTest
@testable import SwiftLightBlue

final class SwiftLightBlueTests: XCTestCase {
    func testFFA() throws {
        let lnode = Node(
            rs: .LEX,
            pf: "美味しい",
            cat: .SL(.NP([.F([.Nc])]), .NP([.F([.Nc])])),
            daughters: [],
            logScore: -2,
            source: ""
        )
        let rnode = Node(
            rs: .LEX,
            pf: "パン",
            cat: .NP([.F([.Nc])]),
            daughters: [],
            logScore: -3,
            source: ""
        )

        let result = SwiftLightBlue.forwardFunctionApplicationRule(lnode: lnode, rnode: rnode)
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result[0].rs, .FFA)
        XCTAssertEqual(result[0].pf, "美味しいパン")
        XCTAssertEqual(result[0].cat, .NP([.F([.Nc])]))
        XCTAssertEqual(result[0].daughters, [lnode, rnode])
        XCTAssertEqual(result[0].logScore, -5)
        XCTAssertEqual(result[0].source, "")
    }

    func testBFA() throws {
        do {
            let lnode = Node(
                rs: .LEX,
                pf: "僕が",
                cat: .NP([.F([.Ga])]),
                daughters: [],
                logScore: -3,
                source: ""
            )
            let rnode = Node(
                rs: .LEX,
                pf: "行く",
                cat: .BS(.S([.F([.V5k]), .F([.Term])]), .NP([.F([.Ga])])),
                daughters: [],
                logScore: -4,
                source: ""
            )
            
            let result = SwiftLightBlue.backwardFunctionApplicationRule(lnode: lnode, rnode: rnode)
            XCTAssertFalse(result.isEmpty)
            XCTAssertEqual(result[0].rs, .BFA)
            XCTAssertEqual(result[0].pf, "僕が行く")
            XCTAssertEqual(result[0].cat, .S([.F([.V5k]), .F([.Term])]))
            XCTAssertEqual(result[0].daughters, [lnode, rnode])
            XCTAssertEqual(result[0].logScore, -7)
            XCTAssertEqual(result[0].source, "")
        }
        do {
            let lnode = Node(
                rs: .LEX,
                pf: "僕",
                cat: .NP([.F([.Nc])]),
                daughters: [],
                logScore: -3,
                source: ""
            )
            let rnode = Node.が

            let result = SwiftLightBlue.backwardFunctionApplicationRule(lnode: lnode, rnode: rnode)
            XCTAssertFalse(result.isEmpty)
            XCTAssertEqual(result[0].rs, .BFA)
            XCTAssertEqual(result[0].pf, "僕が")
            XCTAssertEqual(result[0].cat, .SL(.T(true, 1, modifiableS), .BS(.T(true, 1, modifiableS), .NP([.F([.Ga])]))))
            XCTAssertEqual(result[0].daughters, [lnode, rnode])

        }
        do {
            let lnode = Node(rs: .LEX, pf: "", cat: .S([.SF(9, [.VSN, .VS]), .SF(10, [.Term, .Attr]), .SF(11, [.M]), .SF(12, [.M]), .SF(13, [.M]), .F([.M]), .F([.M])]), daughters: [], logScore: 0, source: "")
            let rnode = Node(rs: .LEX, pf: "", cat: .BS(.SL(.N, .N), (.S([.F(anyPos), .F([.Attr]), .F([.P, .M]), .F([.P, .M]), .F([.P, .M]), .F([.M]), .F([.M])]))), daughters: [], logScore: 0, source: "")
            let result = SwiftLightBlue.backwardFunctionApplicationRule(lnode: lnode, rnode: rnode)
            XCTAssertFalse(result.isEmpty)
        }
    }

    func testFFC() throws {
        let lnode = Node(
            rs: .LEX,
            pf: "",
            cat: .SL(.N, .NP([.F([.Nc])])),
            daughters: [],
            logScore: -1,
            source: ""
        )
        let rnode = Node(
            rs: .LEX,
            pf: "",
            cat: .SL(.NP([.F([.Nc])]), .N),
            daughters: [],
            logScore: -2,
            source: ""
        )

        let result = SwiftLightBlue.forwardFunctionComposition1Rule(lnode: lnode, rnode: rnode)
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result[0].rs, .FFC1)
        XCTAssertEqual(result[0].pf, "")
        XCTAssertEqual(result[0].cat, .SL(.N, .N))
        XCTAssertEqual(result[0].daughters, [lnode, rnode])
        XCTAssertEqual(result[0].logScore, -3)
    }

    func testBFC() throws {
        let lnode = Node(
            rs: .LEX,
            pf: "長い",
            cat: constructPredicate("長い", [.Ai], [.Term, .Attr]),
            daughters: [],
            logScore: -4,
            source: ""
        )
        let rnode = Node.です

        let result = SwiftLightBlue.backwardFunctionComposition1Rule(lnode: lnode, rnode: rnode)
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result[0].rs, .BFC1)
        XCTAssertEqual(result[0].pf, "長いです")
        XCTAssertEqual(result[0].cat, .BS(
            .S([
                .SF(1, adjective),
                .F([.Term]),
                .SF(2, [.P, .M]),
                .F([.P]),
                .F([.M]),
                .F([.M]),
                .F([.M]),
            ]),
            .NP([.F([.Ga])])
        ))
        XCTAssertEqual(result[0].daughters, [lnode, rnode])
    }

    func testBinaryRules() throws {
        let 小さ = myLexicon.filter {$0.pf == "小さ"}.first!
        let な = myLexicon.filter {$0.pf == "な" && $0.source == "(220)"}.first!
        do {
            let result = binaryRules(lnode: 小さ, rnode: な)
            XCTAssertFalse(result.isEmpty)
        }

        let 食べ = constructVerb("食べる", "ヲガ", [.V1], [.Stem, .Neg, .Cont, .NegL, .EuphT]).map {
            lexicalitem("食べ", "", 100, $0)
        }.first!
        let る = conjSuffix("る", "", [.V5r, .V1, .V5ARU, .V5NAS], [.Term, .Attr])
        do {
            let result = binaryRules(lnode: 食べ, rnode: る)
            XCTAssertFalse(result.isEmpty)
        }
    }

    func testUnifyCategory() throws {
        guard let (cat, csub, fsub) = SwiftLightBlue.unifyCategory([], [], [], .NP([]), .NP([])) else {
            XCTFail("Result should not be nil")
            return
        }
        XCTAssertEqual(cat, .NP([]))
        XCTAssertTrue(csub.isEmpty)
        XCTAssertTrue(fsub.isEmpty)
    }

    func testUnifiable() throws {
        XCTAssertEqual(SwiftLightBlue.unifiable(f1: [], f2: []), true)
    }

    func testCatEqual() {
        XCTAssertEqual(Cat.N, .N)
        XCTAssertEqual(Cat.NP([]), Cat.NP([]))
        XCTAssertEqual(Cat.NP([.F([.Nc])]), Cat.NP([.F([.Nc])]))

        XCTAssertNotEqual(Cat.NP([.F([.Nc])]), Cat.NP([.F([.Ga])]))
    }

    func testExecuteMacro() throws {
        do {
            let parser = MyLexiconParser()
            let result = parser.parseMyLexicon(myLeiconProgram)
            let dict = Dictionary(grouping: result, by: \.pf)
            XCTAssertEqual(dict["が"]?.count, 5)
            XCTAssertEqual(dict["の"]?.count, 8)
            XCTAssertEqual(dict["な"]?.count, 12)
            XCTAssertEqual(dict["い"]?.count, 9)
            XCTAssertEqual(dict["る"]?.count, 1)
        }
        do {
            let parser = MyLexiconParser()
            let result = parser.parseMyLexicon(emptyCategoriesProgram)
            let rel_ext = result.first{$0.source.contains("rel-ext")}
            print(rel_ext?.cat)
        }
    }


    func testParseCategory() throws {
        let parser = MyLexiconParser()
        do {
            let s = "(T True 1 modifiableS `SL` (T True 1 modifiableS `BS` NP [F[Ga]]))"
            let e = Cat.SL(.T(true, 1, modifiableS), .BS(.T(true, 1, modifiableS), .NP([.F([.Ga])])))
            XCTAssertEqual(parser.rangeOfCategory(line: s)?.cat, e)
        }
        do {
            let s = "(N) `BS` N"
            let e = Cat.BS(.N, .N)
            XCTAssertEqual(parser.rangeOfCategory(line: s)?.cat, e)
        }
        do {
            let s = "(T True 1 N) `BS` N"
            let e = Cat.BS(.T(true, 1, .N), .N)
            XCTAssertEqual(parser.rangeOfCategory(line: s)?.cat, e)
        }
        do {
            let s = "((T True 1 modifiableS `SL` (T True 1 modifiableS `BS` NP [F[Ga]])) `BS` NP [F[Nc]])"
            let e = Cat.BS(.SL(.T(true, 1, modifiableS), .BS(.T(true, 1, modifiableS), .NP([.F([.Ga])]))), .NP([.F([.Nc])]))
            XCTAssertEqual(parser.rangeOfCategory(line: s)?.cat, e)
        }
    }

    func testChartParser() throws {
        let parser = ChartParser()
        do {
            let sentence = "パンが"
            XCTAssertEqual(parser.purifyText(sentence: sentence), "パンが")
            let result = parser.simpleParse(10, sentence: sentence)
            XCTAssertFalse(result.isEmpty)
            XCTAssertTrue(result.first?.rs == .WRAP)
        }
        do {
            let sentence = "来られる"
            let result = parser.simpleParse(10, sentence: sentence)
            XCTAssertFalse(result.isEmpty)
            XCTAssertTrue(result.first?.rs == .WRAP)
        }
        do {
            let sentence = "太郎が来られる"
            let result = parser.simpleParse(10, sentence: sentence)
            XCTAssertFalse(result.isEmpty)
            XCTAssertTrue(result.first?.rs == .WRAP)
        }
        do {
            let sentence = "象がパンを食べる"
            let result = parser.simpleParse(10, sentence: sentence)
            XCTAssertFalse(result.isEmpty)
        }
        do {
            let sentence = "小さなパン"
            let result = parser.simpleParse(10, sentence: sentence)
            XCTAssertFalse(result.isEmpty)
            XCTAssertTrue(result.first?.rs == .WRAP)
        }
        do {
            let sentence = "小さなパンと大きなパン"
            let result = parser.simpleParse(10, sentence: sentence)
            XCTAssertFalse(result.isEmpty)
            XCTAssertTrue(result.first?.rs == .WRAP)
        }
    }

    func testChartParser2() throws {
        let parser = ChartParser()
        do {
            let sentence = "文を処理するモデルです"
            let result = parser.simpleParse(10, sentence: sentence)
            XCTAssertFalse(result.isEmpty)
            XCTAssertTrue(result.first?.rs == .WRAP)
        }
        do {
            let sentence = "全員がそこに集まった"
            let result = parser.simpleParse(10, sentence: sentence)
            XCTAssertFalse(result.isEmpty)
            XCTAssertTrue(result.first?.rs == .WRAP)
        }
        do {
            let sentence = "選手が怪盗を捕まえた"
            let result = parser.simpleParse(10, sentence: sentence)
            XCTAssertFalse(result.isEmpty)
            XCTAssertTrue(result.first?.rs == .WRAP)
        }
        do {
            // 二重ガ格
            let sentence = "選手が怪盗が捕まえた"
            let result = parser.simpleParse(10, sentence: sentence)
            XCTAssertTrue(result.isEmpty)
        }
    }

    func testGetBundle() throws {
        let b = getBundle()
        print(b.bundleURL)
        print(b.url(forResource: "Juman.dic", withExtension: "tsv"))
    }

    func testUnifyWithCategory() throws {
        do {
            let c1 = defS(verb, [.Stem, .Attr])
            // c2のヘッド
            let c2Head = defS([.V1], [.Stem]) // v1 \in verb
            let c2 = Cat.BS(.BS(c2Head, .NP([.F([.Ga])])), Cat.SL(c2Head, .NP([.F([.O])])))
            let tForHead = Cat.T(true, 1, c1)
            let tNotForHead = Cat.T(false, 1, c1)
            // unifyWithHeadは成功する
            let uwh = unifyWithHead([], [], [], c1, c2)
            XCTAssertNotNil(uwh)
            // unifyCategoryはtForHeadに対してのみ成功する
            let uct = unifyCategory([], [], [], tForHead, c2)
            XCTAssertNotNil(uct)
            let ucf = unifyCategory([], [], [], tNotForHead, c2)
            XCTAssertNil(ucf)
        }
    }
}
