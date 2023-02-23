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


        // TODO: 検証: これはイコール扱いできないらしい
        XCTAssertNotEqual(Cat.S([]), Cat.S([]))
    }

    func testExecuteMacro() throws {
        let parser = MyLexiconParser()
        let result = parser.parseMyLexicon(haskellProgram)
        let dict = Dictionary(grouping: result, by: \.pf)
        XCTAssertEqual(dict["が"]?.count, 5)
        XCTAssertEqual(dict["の"]?.count, 8)
        XCTAssertEqual(dict["な"]?.count, 12)
        XCTAssertEqual(dict["い"]?.count, 9)
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

    func testSetupLexicon() throws {
        let input = "が"
        let result = setupLexicon(sentence: input)
        XCTAssertEqual(result.count, 5)
    }

    func testChartParser() throws {
        let parser = ChartParser()
        do {
            let sentence = "パンが"
            XCTAssertEqual(parser.purifyText(sentence: sentence), "パンが")
            let result = parser.simpleParse(10, sentence: sentence)
            XCTAssertFalse(result.isEmpty)
        }
        do {
            let sentence = "太郎が来られる"
            let result = parser.simpleParse(10, sentence: sentence)
            XCTAssertFalse(result.isEmpty)
            guard let top = result.first else {
                XCTFail("Wrong case")
                return
            }
            debugPrint(top)
            print(result.map(\.score))
        }
        do {
            let sentence = "小さなパンと大きなパン"
            let result = parser.simpleParse(10, sentence: sentence)
            XCTAssertFalse(result.isEmpty)
            guard let top = result.first else {
                XCTFail("Wrong case")
                return
            }
            debugPrint(top)
            print(result.map(\.score))
        }
    }

    func testParseMyLexicon() throws {
        let parser = MyLexiconParser()
        do {
            let line = """
        mylex ["無","な"] "(173)" (S ([F[ANAS], F[Stem]]++mmpmm) `BS` NP [F[Ga]]) (predSR 1 "無い/ない"), --  +nとした。「太郎しか財布にお金が無い」
        mylex ["無","な"] "(173)+" ((S ([F[ANAS], F[Stem]]++mmpmm) `BS` NP [F[Ga]]) `BS` NP [F[Ni]]) (predSR 2 "無い/ない"),
        mylex ["無","の"] "(173)" (S ([F[ANAS], F[UStem]]++mmpmm) `BS` NP [F[Ga]]) (predSR 1 "無い/ない"), -- +nとした
        """
            let result = parser.parseMyLexicon(line)
            print(result)
        }
        do {
            let line = """
              -- 格助詞
              -- argument:
              mylex ["が"] "(524)" ((T True 1 modifiableS `SL` (T True 1 modifiableS `BS` NP [F[Ga]])) `BS` NP [F[Nc]]) argumentCM,
            """
            let result = parser.parseMyLexicon(line)
            print(result)
        }
    }
}
