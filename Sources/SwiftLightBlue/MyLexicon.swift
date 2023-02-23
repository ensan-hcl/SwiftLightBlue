import Foundation

func ec(_ word: some StringProtocol, _ source: String, _ score: Int, _ cat: Cat) -> Node {
    Node (rs: .EC, pf: "", cat: cat, daughters: [], logScore: log(Double(score)/100), source: "\(word):\(source)")
}

let emptyCategories: [Node] = {
    let parser = MyLexiconParser()
    return parser.parseMyLexicon(emptyCategoriesProgram)
}()

extension Node {
    static var が: Node {
        Node(
            rs: .LEX,
            pf: "が",
            // (T True 1 modifiableS `SL` (T True 1 modifiableS `BS` NP [F[Ga]])) `BS` NP [F[Nc]]
            cat: .BS(.SL(.T(true, 1, modifiableS), .BS(.T(true, 1, modifiableS), .NP([.F([.Ga])]))), .NP([.F([.Nc])])),
            daughters: [],
            logScore: -0.1,
            source: ""
        )
    }

    static var です: Node {
        Node(
            rs: .LEX,
            pf: "です",
            // "(318)" (S [SF 1 adjective, F[Term], SF 2 [P,M],F[P],F[M],F[M],F[M]] `BS` S [SF 1 adjective, F[Term],SF 2 [P,M],F[M],F[M],F[M],F[M]])
            cat: .BS(.S([
                .SF(1, adjective),
                .F([.Term]),
                .SF(2, [.P, .M]),
                .F([.P]),
                .F([.M]),
                .F([.M]),
                .F([.M]),
            ]), .S([
                .SF(1, adjective),
                .F([.Term]),
                .SF(2, [.P, .M]),
                .F([.M]),
                .F([.M]),
                .F([.M]),
                .F([.M]),
            ])),
            daughters: [],
            logScore: -0.1,
            source: ""
        )
    }
}


func conjSuffix(_ word: String, _ source: String, _ catpos: [FeatureValue], _ catconj: [FeatureValue]) -> Node {
    lexicalitem(word, source, 100, .BS(.S([.SF(1, catpos), .F(catconj)] + m5), .S([.SF(1, catpos), .F([.Stem])] + m5)))
}

func conjNSuffix(_ word: String, _ source: String, _ catpos: [FeatureValue], _ catconj: [FeatureValue]) -> Node {
    lexicalitem(word, source, 100, .BS(.S([.SF(1, catpos), .F(catconj)] + m5), .S([.SF(1, catpos), .F([.NStem])] + m5)))
}

/// 語彙項目登録用マクロ
func mylex(_ words: [some StringProtocol], _ source: some StringProtocol, _ cat: Cat) -> [Node] {
    words.map {
        lexicalitem($0, source, 100, cat)
    }
}

func mylex(_ words: [some StringProtocol], _ source: some StringProtocol, _ score: Int, _ cat: Cat) -> [Node] {
    words.map {
        lexicalitem($0, source, score, cat)
    }
}
func verblex(_ words: [some StringProtocol], _ source: some StringProtocol, _ posF: [FeatureValue], _ conjF: [FeatureValue], _ cf: some StringProtocol) -> [Node] {
    words.map {
        lexicalitem($0, source, 100, verbCat(cf, posF, conjF))
    }
}
