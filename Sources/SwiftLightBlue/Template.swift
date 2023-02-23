import Foundation

/// defines a lexical item.
func lexicalitem(_ pf: some StringProtocol, _ source: some StringProtocol, _ score: Int, _ cat: Cat) -> Node {
    Node(rs: .LEX, pf: String(pf), cat: cat, daughters: [], logScore: log(Double(score) / 100), source: String(source))
}

func verbCat(_ caseFrame: some StringProtocol, _ posF: [FeatureValue], _ conjF: [FeatureValue]) -> Cat {
    return verbCat(caseFrame, defS(posF, conjF))
}

func verbCat(_ caseFrame: some StringProtocol, _ cat: Cat) -> Cat {
    if let c = caseFrame.first {
        if c == "ガ" {
            return verbCat(caseFrame.dropFirst(), .BS(cat, .NP([.F([.Ga])])))
        }
        if c == "ヲ" {
            return verbCat(caseFrame.dropFirst(), .BS(cat, .NP([.F([.O])])))
        }
        if c == "ニ" {
            return verbCat(caseFrame.dropFirst(), .BS(cat, .NP([.F([.Ni])])))
        }
        if c == "ト" {
            return verbCat(caseFrame.dropFirst(), .BS(cat, .Sbar([.F([.ToCL])])))
        }
        if c == "ヨ" {
            return verbCat(caseFrame.dropFirst(), .BS(cat, .NP([.F([.Niyotte])])))
        }
        return verbCat(caseFrame.dropFirst(), cat)
    }
    return cat
}

///  Category S with the default feature setting (mainly for stems).
func defS(_ p: [FeatureValue], _ c: [FeatureValue]) -> Cat {
    .S([.F(p), .F(c), .F([.M]), .F([.M]), .F([.M]), .F([.M]), .F([.M])])
}

let m5: [Feature] = [.F([.M]), .F([.M]), .F([.M]), .F([.M]), .F([.M])]
let mmmpm: [Feature] = [.F([.M]), .F([.M]), .F([.M]), .F([.P]), .F([.M])]
let mmpmm: [Feature] = [.F([.M]), .F([.M]), .F([.P]), .F([.M]), .F([.M])]
let mpmmm: [Feature] = [.F([.M]), .F([.P]), .F([.M]), .F([.M]), .F([.M])]
let mppmm: [Feature] = [.F([.M]), .F([.P]), .F([.P]), .F([.M]), .F([.M])]

/// A set of conjugation forms of JP verbs.
let verb : [FeatureValue] = [.V5k, .V5s, .V5t, .V5n, .V5m, .V5r, .V5w, .V5g, .V5z, .V5b, .V5IKU, .V5YUK, .V5ARU, .V5NAS, .V5TOW, .V1, .VK, .VS, .VSN, .VZ, .VURU]

/// A set of conjugation forms of JP adjectives.
let adjective : [FeatureValue] = [.Aauo, .Ai, .ANAS, .ATII, .ABES]

/// A set of conjugation forms of JP nominal predicates.
let nomPred : [FeatureValue] = [.Nda, .Nna, .Nno, .Nni, .Nemp, .Ntar]

/// All conjugation forms, i.e. `verb` + `adjective` + `nomPred`
let anyPos: [FeatureValue] = verb + adjective + nomPred

let nonStem : [FeatureValue] = [.Neg, .Cont, .Term, .Attr, .Hyp, .Imper, .Pre, .NStem, .VoR, .VoS, .VoE, .NegL, .TeForm]

let modifiableS: Cat = .S([
    .SF(2, anyPos),
    .SF(3, nonStem),
    .SF(4, [.P, .M]),
    .SF(5, [.P, .M]),
    .SF(6, [.P, .M]),
    .F([.M]),
    .F([.M])
])
