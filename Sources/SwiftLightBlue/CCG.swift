// Status: Syntax: DONE
// Status: Semantics: NOT DONE
import Foundation

struct Node: Equatable {
    /// The name of the rule
    var rs: RuleSymbol
    /// The phonetic form
    var pf: String
    /// The syntactic category (in CCG)
    var cat: Cat
    /// The semantic representation (in DTS)
    // var sem: Preterm
    /// Signature
    // var sig: Signature
    /// The daughter nodes
    var daughters: [Node]
    /// The log of score (between 0.00 to 1.00, larger the better)
    ///  - note: オリジナルは`Rational`だったが、Swiftだと無限精度小数がないのでとりあえずlogにした
    var logScore: Double
    /// The source of the lexical entry
    var source: String

    /// `logScore`を計算しなおしたもの
    var score: Double {
        pow(2.7182, logScore)
    }
}

extension Node: Comparable {
    static func < (lhs: Node, rhs: Node) -> Bool {
        lhs.score < rhs.score
    }
}

extension Node: CustomDebugStringConvertible {
    var debugDescription: String {
        let daughterDescription = daughters.isEmpty ? "" : "\n    daughters: [\n" + daughters.map{$0.debugDescription.components(separatedBy: "\n").map{"        "+$0}.joined(separator: "\n")}.joined(separator: "\n") + "\n    ]"
        return """
        Node(
            pf:        \(pf)
            rs:        \(rs)
            score:     \(score)
            cat:       \(cat)\(source.isEmpty ? "" : "\n    source:    " + source)\(daughterDescription)
        )
        """
    }
}

indirect enum Cat {
    /// `[Feature]`は常に7つの値を取り、以下のようになる。
    /// - `[0]`: 用言の品詞
    /// - `[1]`: 活用の種類
    /// - `[2]`: 非過去形(`[.M]`) / 過去形(`[.P]`)
    /// - `[3]`: 非丁寧形(`[.M]`) / 丁寧形(`[.P]`)
    /// - `[4]`: 肯定形(`[.M]`) / 否定形(`[.P]`)
    /// - `[5]`: 非鼻音化形(`[.M]`) / 鼻音化形(`[.P]`)
    /// - `[6]`: 非取り立て形(`[.M]`) / 取り立て形(`[.P]`)
    ///
    /// このうち、原著では`[2]`の位置に以下があるが、これはこの実装では除かれている。このことは、例えば(353)の「ん」が`MyLexicon.hs`の記述において`+l`の素性が記述されていないことからわかる。
    /// - `[2]`: 口語形(`[.M]`) / 文語残存形(`[.P]`)
    case S([Feature])
    /// `[Feature]`は常に1つの値(格)を取る。
    case NP([Feature])
    case N
    /// `[Feature]`は常に1つの値を取る。
    case Sbar([Feature])
    case CONJ
    case LPAREN
    case RPAREN
    /// X / Y
    case SL(Cat, Cat)
    /// X \ Y
    case BS(Cat, Cat)

    /// Category variables, where Int is an index, Cat is a restriction for its head
    ///
    /// (要検証)`Bool`の値の意味は、`T`が`Cat`をHeadとするComplex Typeを許すか否かである。例えば`Cat`に`modifiableS`が指定されているとき、`true`であれば`modifiableS/N`や`modifiableS\NP`のような型と`T`を同一化できるが、`false`の場合は`modifiableS`に同一化可能な範疇のみが許される。
    ///
    /// `Int`の値はインデックスである。
    ///
    /// `Cat`は常にほとんどの場合`S`であり、唯一`MyLexicon.hs`においてsourceを(531)?として定義される格助詞の「の」のみ`N`が指定されている。ただし、これは原著の範疇指定と一致しない。、範疇変数のHeadとはそれが置き換えられる対象のことを指すようである。このことと、`unifyCategory`および`unifyWithHead`の実装から、`Cat`の値はHeadとなる範疇への制約であり、`Cat`の下位範疇のみが許されていると解釈できる。
    case T(Bool, Int, Cat)
}

extension Cat: CustomStringConvertible {
    var description: String {
        switch self {
        case let .S(v):
            return "S(\(v))"
        case let .NP(v):
            return "NP(\(v))"
        case .N:
            return "N"
        case let .Sbar(v):
            return "Sbar(\(v))"
        case .CONJ:
            return "CONJ"
        case .LPAREN:
            return "LPAREN"
        case .RPAREN:
            return "RPAREN"
        case let .SL(l, r):
            return "(\(l)) / (\(r))"
        case let .BS(l, r):
            return "(\(l)) \\ (\(r))"
        case let .T(b, i, c):
            return "T(\(b), \(i), \(c))"
        }
    }
}

extension Cat: Equatable {
    static func == (lhs: Cat, rhs: Cat) -> Bool {
        switch (lhs, rhs) {
        case (.SL(let x1, let x2), .SL(let y1, let y2)):
            return x1 == y1 && x2 == y2
        case (.BS(let x1, let x2), .BS(let y1, let y2)):
            return x1 == y1 && x2 == y2
        case (.T(let f1, _, let x), .T(let f2, _, let y)):
            return f1 == f2 && x == y
        case (.S(let f1) , .S(let f2)):
            // TODO: 検証: 他を無視する意味がよくわからない
            if f1.count > 1 && f2.count > 1 {
                return unifyFeature([], f1: f1[1], f2: f2[1]) != nil
            } else {
                return false
            }
        case (let .NP(f1), let .NP(f2)):
            return unifiable(f1: f1, f2: f2)
        case (.N, .N):
            return true
        case (let .Sbar(f1), let .Sbar(f2)):
            return unifiable(f1: f1, f2: f2)
        case (.CONJ, .CONJ), (.LPAREN, .LPAREN), (.RPAREN, .RPAREN):
            return true
        default:
            return false
        }
    }
}

extension Cat {
    /// A test to check if a given category is a base category (i.e. not a functional category nor a category variable).
    var isBaseCategory: Bool {
        switch self {
        case .S(_):
            return true
        case .NP(_):
            return true
        case .N:
            return true
        case .Sbar(_):
            return true
        case .CONJ:
            return true
        case .LPAREN:
            return true
        case .RPAREN:
            return true
        case .SL(_, _):
            return false
        case .BS(_, _):
            return false
        case .T(let f, _, let cat):
            if f {
                return true
            } else {
                return cat.isBaseCategory
            }
        }
    }

    var isArgumentCategory: Bool {
        if case .NP(_) = self {
            return !self.isNoncaseNP
        } else if case .Sbar(_) = self {
            return true
        } else {
            return false
        }
    }

    /// A test to check if a given category is T\NPnc.
    var isTNoncaseNP: Bool {
        if case .BS(let x1, let x2) = self {
            if case .T = x1 {
                return x2.isNoncaseNP
            } else {
                return false
            }
        } else {
            return false
        }
    }

    var isNoncaseNP: Bool {
        if case .NP(let features) = self, let first = features.first {
            switch first {
            case let .F(v), let .SF(_, v):
                return v.contains(.Nc)
            }
        }
        return false
    }

    /// A test to check if a given category is the one that can appear on the left adjacent of a punctuation.
    var isBunsetsu: Bool {
        switch self {
        case .SL(let x, _), .BS(let x, _): return x.isBunsetsu
        case .LPAREN: return false
        case .S(let features):
            if features.count > 1 {
                switch features[1] {
                case .F(let feat), .SF(_, let feat):
                    let intersection = Set(feat).intersection([.Cont, .Term, .Attr, .Hyp, .Imper, .Pre, .NTerm, .NStem, .TeForm, .NiForm])
                    return !intersection.isEmpty
                }
            } else {
                return true
            }
        case .N: return false
        case .NP, .Sbar, .CONJ, .RPAREN, .T: return true
        }
    }

    var endsWithT: Bool {
        switch self {
        case .SL(let x, _): return x.endsWithT
        case .T: return true
        default: return false
        }
    }

    var isNStem: Bool {
        switch self {
        case .BS(let x, _): return x.isNStem
        case .S(let features):
            if features.count > 1 {
                return unifyFeature([], f1: features[1], f2: .F([.NStem])) != nil
            }
            return false
        default: return false
        }
    }

    var numberOfArguments: Int {
        switch self {
        case .SL(let c1, _), .BS(let c1, _): return 1 + c1.numberOfArguments
        default: return 0
        }
    }
}

enum Feature: Equatable, CustomStringConvertible {
    /// 素性の集合。順序は考慮しない。
    case F([FeatureValue])
    /// 原著で`S_1️⃣`のように表記されていたもの。`Int`はインデックス、`[FeatureValue]`が取りうる値を示す。
    case SF(Int, [FeatureValue])

    var description: String {
        switch self {
        case .F(let v):
            return "F(\(v))"
        case .SF(let i, let v):
            return "SF(\(i), \(v))"
        }
    }
}

enum FeatureValue: String, Equatable, CustomStringConvertible {
    /// 動詞:五段:カ行
    case V5k
    /// 動詞:五段:サ行
    case V5s
    /// 動詞:五段:タ行
    case V5t
    /// 動詞:五段:ナ行
    case V5n
    /// 動詞:五段:マ行
    case V5m
    /// 動詞:五段:ラ行
    case V5r
    /// 動詞:五段:ワ行
    case V5w
    /// 動詞:五段:ガ行
    case V5g
    /// 動詞:五段:ザ行
    case V5z
    /// 動詞:五段:バ行
    case V5b
    /// 動詞:五段:カ行:促音便型 (行く→行った)
    case V5IKU
    /// 動詞:五段:カ行:特殊ユク
    case V5YUK
    /// 動詞:五段:ラ行:特殊:アル (\*あらない)
    case V5ARU
    /// 動詞:五段:バ行
    case V5NAS
    /// 動詞:五段:ワ行:ウ音便型 (問う→問うた)
    case V5TOW
    /// 動詞:一段
    case V1
    /// 動詞:カ変
    case VK
    /// 動詞:サ変
    case VS
    /// 動詞:サ変名詞
    case VSN
    /// 動詞:ザ変
    case VZ
    /// 動詞:特殊:得る
    case VURU
    /// 形容詞:アウオ段
    case Aauo
    /// 形容詞:イ段
    case Ai
    /// 形容詞:ナシ型
    case ANAS
    /// 形容詞:チイ型 (ちゃちい)
    case ATII
    /// 形容詞:ベシ型
    case ABES
    /// 状詞: ダ接続可能
    case Nda
    /// 状詞: ナ接続可能
    case Nna
    /// 状詞: ノ接続可能
    case Nno
    /// 状詞: タリ接続可能
    case Ntar
    /// 状詞: ニ接続可能
    case Nni
    /// 状詞: 単独で副詞可能
    case Nemp
    /// 状詞: ト接続可能
    case Nto
    /// 感動詞 (Lexicon.swiftを参照)
    case Exp
    /// 活用種: 語幹形
    case Stem
    /// 活用種: 文語連用接続形
    case UStem
    /// (推測) 状詞語幹
    case NStem
    /// 活用種: 打消形
    case Neg
    /// 活用種: 連用形
    case Cont
    /// 活用種: 終止形
    case Term
    /// 活用種: 連体形
    case Attr
    /// 活用種: 条件形
    case Hyp
    /// 活用種: 命令形
    case Imper
    /// 活用種: 推量形
    case Pre
    /// (推測) 状詞終止形
    case NTerm
    /// 活用種: 文語打消形
    case NegL
    /// 活用種: テ形
    case TeForm
    /// 活用種: ニ形
    case NiForm
    /// 活用種:過去接続形:タ接続形
    case EuphT
    /// 活用種:過去接続形:ダ接続形
    case EuphD
    /// 活用種:様相接続形:ウ接続形
    case ModU
    /// 活用種:様相接続形:ダロウ接続形
    case ModD
    /// 活用種:様相接続形:ソウダ接続形
    case ModS
    /// (推測) 活用種:様相接続形:マス接続形 (MyLexicon.hsに基づく)
    case ModM
    /// 活用種:態接続形:受身接続形
    case VoR
    /// 活用種:態接続形:使役接続形
    case VoS
    /// 活用種:態接続形:可能接続形
    case VoE
    /// 素性値: Plus
    case P
    /// 素性値: Minus
    case M
    /// 格無し
    case Nc
    /// ガ格
    case Ga
    /// ヲ格
    case O
    /// ニ格
    case Ni
    /// ト格
    case To
    /// ニヨッテ格
    case Niyotte
    /// ノ格
    case No
    /// 引用形式:ト (走ったと言う)
    case ToCL
    /// (推測) 引用形式:ヨウニ (走ったように見える)
    case YooniCL
    /// 発話形式:平叙文
    case Decl

    var description: String {
        return self.rawValue
    }
}

func unifiable(f1: [Feature], f2: [Feature]) -> Bool {
    return unifyFeatures([], f1, f2) != nil
}

enum RuleSymbol: String, Equatable, CustomStringConvertible {
    case LEX //A lexical item
    case EC //An empty category
    case FFA //Forward function application rule.
    case BFA //Backward function application rule
    case FFC1 //Forward function composition rule 1
    case BFC1 //Backward function composition rule 1
    case FFC2 //Forward function composition rule 2
    case BFC2 //Backward function composition rule 2
    case FFC3 //Forward function composition rule 3
    case BFC3 //Backward function composition rule 3
    case FFCx1 //Forward function crossed composition rule 1
    case FFCx2 //Forward function crossed composition rule 2
    case FFSx //Forward function crossed substitution rule
    case COORD //Coordination rule
    case PAREN //Parenthesis rule
    case WRAP //Wrap rule
    case DC //Dynamic conjunction rule
    case DREL //Discourse Relation rule

    var description: String {
        return self.rawValue
    }
}

func unaryRules(node: Node) -> [Node] {
    return []
}

func binaryRules(lnode: Node, rnode: Node) -> [Node] {
    return [
        forwardFunctionCrossedSubstitutionRule(lnode: lnode, rnode: rnode),
        forwardFunctionCrossedComposition2Rule(lnode: lnode, rnode: rnode),
        forwardFunctionCrossedComposition1Rule(lnode: lnode, rnode: rnode),
        backwardFunctionComposition3Rule(lnode: lnode, rnode: rnode),
        backwardFunctionComposition2Rule(lnode: lnode, rnode: rnode),
        forwardFunctionComposition2Rule(lnode: lnode, rnode: rnode),
        backwardFunctionComposition1Rule(lnode: lnode, rnode: rnode),
        forwardFunctionComposition1Rule(lnode: lnode, rnode: rnode),
        backwardFunctionApplicationRule(lnode: lnode, rnode: rnode),
        forwardFunctionApplicationRule(lnode: lnode, rnode: rnode),

    ].reversed().flatMap{$0}
}

func forwardFunctionApplicationRule(lnode: Node, rnode: Node) -> [Node] {
    guard case let .SL(x, y1) = lnode.cat else {
        return []
    }
    if lnode.rs == .FFC1 || lnode.rs == .FFC2 || lnode.rs == .FFC3 {
        return []
    }
    if case .T(true, _, _) = y1 {
        return []
    }
    let inc = maximumIndexC(rnode.cat)
    if let (_, csub, fsub) = unifyCategory([], [], [], rnode.cat, incrementIndexC(y1, inc)) {
        let newcat = simulSubstituteCV(csub, fsub, incrementIndexC(x, inc))
        return [
            Node(
                rs: .FFA,
                pf: lnode.pf + rnode.pf,
                cat: newcat,
                // sem: ,
                // sig: ,
                daughters: [lnode, rnode],
                logScore: lnode.logScore + rnode.logScore,
                source: ""
            )
        ]
    }
    return []
}

func backwardFunctionApplicationRule(lnode: Node, rnode: Node) -> [Node] {
    guard case let .BS(x, y2) = rnode.cat else {
        return []
    }
    if rnode.rs == .BFC1 || rnode.rs == .BFC2 || rnode.rs == .BFC3 {
        return []
    }
    let inc = maximumIndexC(lnode.cat)
    if let (_, csub, fsub) = unifyCategory([], [], [], lnode.cat, incrementIndexC(y2, inc)) {
        let newcat = simulSubstituteCV(csub, fsub, incrementIndexC(x, inc))
        return [
            Node(
                rs: .BFA,
                pf: lnode.pf + rnode.pf,
                cat: newcat,
                // sem: ,
                // sig: ,
                daughters: [lnode, rnode],
                logScore: lnode.logScore + rnode.logScore,
                source: ""
            )
        ]
    }
    return []
}


func forwardFunctionComposition1Rule(lnode: Node, rnode: Node) -> [Node] {
    guard case let .SL(x, y1) = lnode.cat,
          case let .SL(y2, z) = rnode.cat else {
        return []
    }
    if lnode.rs == .FFC1 || lnode.rs == .FFC2 || lnode.rs == .FFC3 || y1.isTNoncaseNP {
        return []
    }
    let inc = maximumIndexC(rnode.cat)
    if let (_, csub, fsub) = unifyCategory([], [], [], y2, incrementIndexC(y1, inc)) {
        let _z = simulSubstituteCV(csub, fsub, z)
        if _z.numberOfArguments > 3 {
            return []
        } else {
            let newcat: Cat = .SL(simulSubstituteCV(csub, fsub, incrementIndexC(x, inc)), _z)
            return [
                Node(
                    rs: .FFC1,
                    pf: lnode.pf + rnode.pf,
                    cat: newcat,
                    // sem: ,
                    // sig: ,
                    daughters: [lnode, rnode],
                    logScore: lnode.logScore + rnode.logScore,
                    source: ""
                )
            ]
        }
    }
    return []
}

func forwardFunctionComposition2Rule(lnode: Node, rnode: Node) -> [Node] {
    guard case let .SL(x, y1) = lnode.cat,
          case let .SL(y, z2) = rnode.cat,
          case let .SL(y2, z1) = y else {
        return []
    }
    if lnode.rs == .FFC1 || lnode.rs == .FFC2 || lnode.rs == .FFC3 || y1.isTNoncaseNP {
        return []
    }
    let inc = maximumIndexC(rnode.cat)
    if let (_, csub, fsub) = unifyCategory([], [], [], incrementIndexC(y1, inc), y2) {
        let _z1 = simulSubstituteCV(csub, fsub, z1)
        if _z1.numberOfArguments > 2 {
            return []
        } else {
            let newcat: Cat = simulSubstituteCV(csub, fsub, .SL(.SL(incrementIndexC(x, inc), z1), z2))
            return [
                Node(
                    rs: .FFC2,
                    pf: lnode.pf + rnode.pf,
                    cat: newcat,
                    daughters: [lnode, rnode],
                    logScore: lnode.logScore + rnode.logScore,
                    source: ""
                )
            ]
        }
    }
    return []
}

func backwardFunctionComposition1Rule(lnode: Node, rnode: Node) -> [Node] {
    guard case let .BS(y1, z) = lnode.cat,
          case let .BS(x, y2) = rnode.cat else {
        return []
    }
    if rnode.rs == .BFC1 || rnode.rs == .BFC2 || rnode.rs == .BFC3 {
        return []
    }
    let inc = maximumIndexC(lnode.cat)
    if let (_, csub, fsub) = unifyCategory([], [], [], y1, incrementIndexC(y2, inc)) {
        let newcat: Cat = simulSubstituteCV(csub, fsub, .BS(incrementIndexC(x, inc), z))
        return [
            Node(
                rs: .BFC1,
                pf: lnode.pf + rnode.pf,
                cat: newcat,
                // sem: ,
                // sig: ,
                daughters: [lnode, rnode],
                logScore: lnode.logScore + rnode.logScore,
                source: ""
            )
        ]
    }
    return []
}

func backwardFunctionComposition2Rule(lnode: Node, rnode: Node) -> [Node] {
    guard case let .BS(y, z2) = lnode.cat,
          case let .BS(y1, z1) = y,
          case let .BS(x, y2) = rnode.cat else {
        return []
    }
    if rnode.rs == .BFC1 || rnode.rs == .BFC2 || rnode.rs == .BFC3 {
        return []
    }
    let inc = maximumIndexC(lnode.cat)
    if let (_, csub, fsub) = unifyCategory([], [], [], incrementIndexC(y2, inc), y1) {
        let newcat: Cat = simulSubstituteCV(csub, fsub, .BS(.BS(incrementIndexC(x, inc), z1), z2))
        return [
            Node(
                rs: .BFC2,
                pf: lnode.pf + rnode.pf,
                cat: newcat,
                // sem: ,
                // sig: ,
                daughters: [lnode, rnode],
                logScore: lnode.logScore + rnode.logScore,
                source: ""
            )
        ]
    }
    return []
}

func backwardFunctionComposition3Rule(lnode: Node, rnode: Node) -> [Node] {
    guard case let .BS(y, z3) = lnode.cat,
          case let .BS(y_, z2) = y,
          case let .BS(y1, z1) = y_,
          case let .BS(x, y2) = rnode.cat else {
        return []
    }
    if rnode.rs == .BFC1 || rnode.rs == .BFC2 || rnode.rs == .BFC3 {
        return []
    }
    let inc = maximumIndexC(lnode.cat)
    if let (_, csub, fsub) = unifyCategory([], [], [], incrementIndexC(y2, inc), y1) {
        let newcat: Cat = simulSubstituteCV(csub, fsub, .BS(.BS(.BS(incrementIndexC(x, inc), z1), z2), z3))
        return [
            Node(
                rs: .BFC3,
                pf: lnode.pf + rnode.pf,
                cat: newcat,
                // sem: ,
                // sig: ,
                daughters: [lnode, rnode],
                logScore: lnode.logScore + rnode.logScore,
                source: ""
            )
        ]
    }
    return []
}

func forwardFunctionCrossedComposition1Rule(lnode: Node, rnode: Node) -> [Node] {
    guard case let .SL(x, y1) = lnode.cat,
          case let .BS(y2, z) = rnode.cat else {
        return []
    }
    if lnode.rs == .FFC1 || lnode.rs == .FFC2 || lnode.rs == .FFC3 || y1.isTNoncaseNP || !z.isArgumentCategory {
        return []
    }
    let inc = maximumIndexC(rnode.cat)
    if let (_, csub, fsub) = unifyCategory([], [], [], y2, incrementIndexC(y1, inc)) {
        let z_ = simulSubstituteCV(csub, fsub, z)
        let newcat: Cat = simulSubstituteCV(csub, fsub, .BS(incrementIndexC(x, inc), z_))
        return [
            Node(
                rs: .FFCx1,
                pf: lnode.pf + rnode.pf,
                cat: newcat,
                daughters: [lnode, rnode],
                // TODO: 検証: 元の実装では`(100 % 100)`をかけていた。'degrade'させるとの記述があるため、とりあえず`-2`で対処した。
                logScore: lnode.logScore + rnode.logScore - 2,
                source: ""
            )
        ]
    }
    return []
}

func forwardFunctionCrossedComposition2Rule(lnode: Node, rnode: Node) -> [Node] {
    guard case let .SL(x, y1) = lnode.cat,
          case let .BS(y, z2) = rnode.cat,
          case let .BS(y2, z1) = y else {
        return []
    }
    if lnode.rs == .FFC1 || lnode.rs == .FFC2 || lnode.rs == .FFC3 || y1.isTNoncaseNP || !z2.isArgumentCategory || !z1.isArgumentCategory {
        return []
    }
    let inc = maximumIndexC(rnode.cat)
    if let (_, csub, fsub) = unifyCategory([], [], [], incrementIndexC(y1, inc), y2) {
        let z1_ = simulSubstituteCV(csub, fsub, z1)
        if z1_.numberOfArguments > 2 {
            return []
        }
        let newcat: Cat = simulSubstituteCV(csub, fsub, .BS(.BS(incrementIndexC(x, inc), z1_), z2))
        return [
            Node(
                rs: .FFCx2,
                pf: lnode.pf + rnode.pf,
                cat: newcat,
                daughters: [lnode, rnode],
                // TODO: 検証: 元の実装では`(100 % 100)`をかけていた。'degrade more'させるとの記述があるため、とりあえず`-3`で対処した。
                logScore: lnode.logScore + rnode.logScore - 3,
                source: ""
            )
        ]
    }
    return []
}


func forwardFunctionCrossedSubstitutionRule(lnode: Node, rnode: Node) -> [Node] {
    guard case let .BS(y, z1) = lnode.cat,
          case let .SL(x, y1) = y,
          case let .BS(y2, z2) = rnode.cat else {
        return []
    }
    if !z1.isArgumentCategory || !z2.isArgumentCategory {
        return []
    }
    let inc = maximumIndexC(rnode.cat)
    if let (z, csub1, fsub1) = unifyCategory([], [], [], incrementIndexC(z1, inc), z2) {
        if let (_, csub2, fsub2) = unifyCategory(csub1, fsub1, [], incrementIndexC(y1, inc), y2) {
            let newcat: Cat = simulSubstituteCV(csub2, fsub2, .BS(incrementIndexC(x, inc), z))
            return [
                Node(
                    rs: .FFSx,
                    pf: lnode.pf + rnode.pf,
                    cat: newcat,
                    daughters: [lnode, rnode],
                    // TODO: 検証: 元の実装では`(100 % 100)`をかけていた。'degrade'させるとの記述があるため、とりあえず`-2`で対処した。
                    logScore: lnode.logScore + rnode.logScore - 2,
                    source: ""
                )
            ]
        }
    }
    return []
}

func coordinationRule(lnode: Node, cnode: Node, rnode: Node) -> [Node] {
    guard cnode.cat == .CONJ else {
        return []
    }
    if lnode.rs == .COORD {
        return []
    }
    if (rnode.cat.endsWithT || rnode.cat.isNStem) && lnode.cat == rnode.cat {
        return [Node(
            rs: .COORD,
            pf: lnode.pf + cnode.pf + rnode.pf,
            cat: rnode.cat,
            daughters: [lnode, cnode, rnode],
            logScore: lnode.logScore + rnode.logScore,
            source: ""
        )]
    }
    return []
}

func parenthesisRule(lnode: Node, cnode: Node, rnode: Node) -> [Node] {
    guard lnode.cat == .LPAREN, rnode.cat == .RPAREN else {
        return []
    }
    return [
        Node(
            rs: .PAREN,
            pf: lnode.pf + cnode.pf + rnode.pf,
            cat: cnode.cat,
            daughters: [lnode, cnode, rnode],
            logScore: cnode.logScore,
            source: ""
        )
    ]
}

func maximumIndexC(_ cat: Cat) -> Int {
    switch cat {
    case .T(_, let i, let cat2):
        return max(i, maximumIndexC(cat2))
    case .SL(let c1, let c2), .BS(let c1, let c2):
        return max(maximumIndexC(c1), maximumIndexC(c2))
    case .S(let features), .NP(let features), .Sbar(let features):
        return maximumIndexF(features)
    default:
        return 0
    }
}

// 再帰を使わずに書き直した
func maximumIndexF(_ features: some Collection<Feature>) -> Int {
    features.map{
        switch $0 {
        case .SF(let i, _):
            return i
        case .F:
            return 0
        }
    }.max() ?? 0
}

func incrementIndexC(_ cat: Cat, _ i: Int) -> Cat {
    switch cat {
    case let .T(f, j, u):
        return .T(f, i+j, incrementIndexC(u, i))
    case let .SL(c1, c2):
        return .SL(incrementIndexC(c1, i), incrementIndexC(c2, i))
    case let .BS(c1, c2):
        return .BS(incrementIndexC(c1, i), incrementIndexC(c2, i))
    case let .S(f):
        return .S(incrementIndexF(f, i))
    case let .Sbar(f):
        return .Sbar(incrementIndexF(f, i))
    case let .NP(f):
        return .NP(incrementIndexF(f, i))
    default: return cat
    }
}

// 再帰を使わずに書き直した
func incrementIndexF(_ features: [Feature], _ i: Int) -> [Feature] {
    features.map{
        switch $0 {
        case let .SF(j, f):
            return .SF(i+j, f)
        case let .F(f):
            return .F(f)
        }
    }
}

enum SubstData<T: Equatable>: Equatable {
    case substLink(Int)
    case substVal(T)
}
typealias Assignment<T: Equatable> = [(Int, SubstData<T>)]

func alter<T, U>(_ i: T, _ v: U, _ mp: [(T, U)]) -> [(T, U)] where T: Comparable, T: Equatable {
    return [(i, v)] + mp.filter{$0.0 != i}
}

func fetchValue<T>(_ sub: Assignment<T>, _ i: Int, _ v: T) -> (Int, T) {
    switch sub.first(where: {$0.0 == i})?.1 {
    case .substLink(let j) where j < i:
        return fetchValue(sub, j, v)
    case .substVal(let u):
        return (i, u)
    default:
        return (i, v)
    }
}

func simulSubstituteCV(_ csub: Assignment<Cat>, _ fsub: Assignment<[FeatureValue]>, _ c: Cat) -> Cat {
    switch c {
    case .T(_, let i, _):
        return fetchValue(csub, i, c).1
    case let .SL(ca, cb):
        return .SL(simulSubstituteCV(csub, fsub, ca), simulSubstituteCV(csub, fsub, cb))
    case let .BS(ca, cb):
        return .BS(simulSubstituteCV(csub, fsub, ca), simulSubstituteCV(csub, fsub, cb))
    case let .S(f):
        return .S(simulSubstituteFV(fsub, f))
    case let .Sbar(f):
        return .Sbar(simulSubstituteFV(fsub, f))
    case let .NP(f):
        return .NP(simulSubstituteFV(fsub, f))
    default:
        return c
    }
}

/// unifies two syntactic categories (`Cat`) and returns a unified syntactic category, under a given category assignment and a given feature assignment.
/// - note: `c1`と`c2`の順序は無関係である。
func unifyCategory(_ csub: Assignment<Cat>, _ fsub: Assignment<[FeatureValue]>, _ banned: [Int], _ c1: Cat, _ c2: Cat) -> (Cat, Assignment<Cat>, Assignment<[FeatureValue]>)? {
    let c3: Cat
    switch c1 {
    case .T(_, let i, _):
        c3 = fetchValue(csub, i, c1).1
    default:
        c3 = c1
    }
    let c4: Cat
    switch c2 {
    case .T(_, let i, _):
        c4 = fetchValue(csub, i, c2).1
    default:
        c4 = c2
    }
    return unifyCategory2(csub, fsub, banned, c3, c4)
}

/// - note: `c1`と`c2`の順序は無関係である。
func unifyCategory2(_ csub: Assignment<Cat>, _ fsub: Assignment<[FeatureValue]>, _ banned: [Int], _ c1: Cat, _ c2: Cat) -> (Cat, Assignment<Cat>, Assignment<[FeatureValue]>)? {
    switch (c1, c2) {
    case let (.T(f1, i, u1), .T(f2, j, u2)):
        if banned.contains(i) || banned.contains(j) {
            return nil
        }
        if i == j {
            return (c1, csub, fsub)
        }
        let ijmax = max(i, j)
        let ijmin = min(i, j)
        if let (u3, csub2, fsub2) = {
            switch (f1, f2) {
            case (true, true), (false, false):
                return unifyCategory2(csub, fsub, [ijmin] + banned, u1, u2)
            case (true, false):
                return unifyWithHead(csub, fsub, [ijmin] + banned, u1, u2)
            case (false, true):
                return unifyWithHead(csub, fsub, [ijmin] + banned, u2, u1)
            }
        }() {
            let result = Cat.T(f1 && f2, ijmin, u3)
            return (result, alter(ijmin, .substVal(result), alter(ijmax, .substLink(ijmin), csub2)), fsub2)
        }
        return nil
    case let (.T(f, i, u), _):
        if banned.contains(i) {
            return nil
        }
        // fがtrueの場合: uにc2でunifyWithHeadできれば
        // fがfalseの場合: uにc2でunifyCategoryできれば
        // その結果を返す。
        guard let (c3, csub2, fsub2) = {
            f ? unifyWithHead(csub, fsub, [i] + banned, u, c2)
            : unifyCategory(csub, fsub, [i] + banned, u, c2)
        }() else {
            return nil
        }
        return (c3, alter(i, .substVal(c3), csub2), fsub2)
    case let (_, .T(f, i, u)):
        if banned.contains(i) {
            return nil
        }
        // fがtrueの場合: uにc2でunifyWithHeadできれば
        // fがfalseの場合: uにc2でunifyCategoryできれば
        // その結果を返す。
        guard let (c3, csub2, fsub2) = {
            f ? unifyWithHead(csub, fsub, [i] + banned, u, c1)
            : unifyCategory(csub, fsub, [i] + banned, u, c1)
        }() else {
            return nil
        }
        return (c3, alter(i, .substVal(c3), csub2), fsub2)
    case let (.NP(f1), .NP(f2)):
        // 素性が同一化可能であれば
        guard let (f3, fsub2) = unifyFeatures(fsub, f1, f2) else {
            return nil
        }
        return (.NP(f3), csub, fsub2)
    case let (.S(f1), .S(f2)):
        // 素性が同一化可能であれば
        guard let (f3, fsub2) = unifyFeatures(fsub, f1, f2) else {
            return nil
        }
        return (.S(f3), csub, fsub2)
    case let (.Sbar(f1), .Sbar(f2)):
        // 素性が同一化可能であれば
        guard let (f3, fsub2) = unifyFeatures(fsub, f1, f2) else {
            return nil
        }
        return (.Sbar(f3), csub, fsub2)
    case let (.SL(c3, c4), .SL(c5, c6)):
        guard let (c7, csub2, fsub2) = unifyCategory(csub, fsub, banned, c4, c6),
              let (c8, csub3, fsub3) = unifyCategory(csub2, fsub2, banned, c3, c5) else {
            return nil
        }
        return (.SL(c8, c7), csub3, fsub3)
    case let (.BS(c3, c4), .BS(c5, c6)):
        guard let (c7, csub2, fsub2) = unifyCategory(csub, fsub, banned, c4, c6),
              let (c8, csub3, fsub3) = unifyCategory(csub2, fsub2, banned, c3, c5) else {
            return nil
        }
        return (.BS(c8, c7), csub3, fsub3)
    case (.N, .N): return (.N, csub, fsub)
    case (.CONJ, .CONJ): return (.CONJ, csub, fsub)
    case (.LPAREN, .LPAREN): return (.LPAREN, csub, fsub)
    case (.RPAREN, .RPAREN): return (.RPAREN, csub, fsub)
    default:
        return nil
    }
}

/// unifies a cyntactic category `c1` (in `T(true, i, c1)`) with the head of `c2`, under a given feature assignment.
///
/// 「Head」とはComplex Typeにおける「一番左側の範疇」である。`unifyWithHead`により、このHeadと`T`の同一化を行う。
///
/// 例えば`c1`が`S(f1)`、`c2`が`S(f2)\NP\NP`のとき、`T`と`S(f2)`でunifyすることは通常できない。
/// `unifyCategory`の実装では、`c1`と`c2`を渡した場合、単純に失敗する。
/// このようなケースで、`unifyWithHead`は、`f1`と`f2`が`unify`可能であれば、`T==c2`となるように`unify`を実施する。
func unifyWithHead(_ csub: Assignment<Cat>, _ fsub: Assignment<[FeatureValue]>, _ banned: [Int], _ c1: Cat, _ c2: Cat) -> (Cat, Assignment<Cat>, Assignment<[FeatureValue]>)? {
    switch c2 {
    case let .SL(x, y):
        // SLの場合、Resultの側が制約c1を満たせば十分であると判断する
        guard let (z, csub2, fsub2) = unifyWithHead(csub, fsub, banned, c1, x) else {
            return nil
        }
        return (.SL(z, y), csub2, fsub2)
    case let .BS(x, y):
        // BSの場合、Resultの側が制約c1を満たせば十分であると判断する
        guard let (z, csub2, fsub2) = unifyWithHead(csub, fsub, banned, c1, x) else {
            return nil
        }
        return (.BS(z, y), csub2, fsub2)
    case let .T(f, i, u):
        if banned.contains(i) {
            return nil
        }
        // c2が`T`の場合、c2の持つ制約と同一化を試み、成功すればそれに基づいて同一化を行う
        guard let (z, csub2, fsub2) = unifyCategory(csub, fsub, [i] + banned, c1, u) else {
            return nil
        }
        return (.T(f, i, z), alter(i, .substVal(.T(f, i, z)), csub2), fsub2)
    default:
        // c2がc1と同一化可能であれば、それを返す
        return unifyCategory(csub, fsub, banned, c1, c2)
    }
}

func substituteFV(_ fsub: Assignment<[FeatureValue]>, _ f1: Feature) -> Feature {
    switch f1 {
    case let .SF(i, v):
        let (j, u) = fetchValue(fsub, i, v)
        return .SF(j, u)
    default:
        return f1
    }
}

func simulSubstituteFV(_ fsub: Assignment<[FeatureValue]>, _ f: [Feature]) -> [Feature] {
    f.map {
        substituteFV(fsub, $0)
    }
}

/// - note: `f1`と`f2`の順序は無関係である。
func unifyFeature(_ fsub: Assignment<[FeatureValue]>, f1: Feature, f2: Feature) -> (Feature, Assignment<[FeatureValue]>)? {
    switch (f1, f2) {
    case let (.SF(i, v1), .SF(j, v2)):
        if i == j {
            let (_i, _v1) = fetchValue(fsub, i, v1)
            // note: 順序について検証→FeatureValueの段階では順序は特に問題にならないため、Setでintersectionして良い。
            let v3 = Array(Set(_v1).intersection(v2))
            if v3.isEmpty {
                return nil
            } else {
                return (.SF(_i, v3), alter(_i, .substVal(v3), fsub))
            }
        } else {
            let (_i, _v1) = fetchValue(fsub, i, v1)
            let (_j, _v2) = fetchValue(fsub, i, v2)
            let v3 = Array(Set(_v1).intersection(_v2))
            if v3.isEmpty {
                return nil
            } else {
                let ijmax = max(_i, _j)
                let ijmin = min(_i, _j)
                return (.SF(ijmin, v3), alter(ijmax, .substLink(ijmin), alter(ijmin, .substVal(v3), fsub)))
            }
        }
    case let (.SF(i, v1), .F(v2)):
        let (_i, _v1) = fetchValue(fsub, i, v1)
        let v3 = Array(Set(_v1).intersection(v2))
        if v3.isEmpty {
            return nil
        } else {
            return (.SF(_i, v3), alter(_i, .substVal(v3), fsub))
        }
    case let (.F(v1), .SF(j, v2)):
        let (_j, _v2) = fetchValue(fsub, j, v2)
        let v3 = Array(Set(v1).intersection(_v2))
        if v3.isEmpty {
            return nil
        } else {
            return (.SF(_j, v3), alter(_j, .substVal(v3), fsub))
        }
    case let (.F(v1), .F(v2)):
        let v3 = Array(Set(v1).intersection(v2))
        if v3.isEmpty {
            return nil
        } else {
            return (.F(v3), fsub)
        }
    }
}

// 再帰を使わずに書き直した
/// - note: `f1`と`f2`の順序は無関係である。
func unifyFeatures(_ fsub: Assignment<[FeatureValue]>, _ f1: some Collection<Feature>, _ f2: some Collection<Feature>) -> ([Feature], Assignment<[FeatureValue]>)? {
    guard f1.count == f2.count else {
        return nil
    }
    var features: [Feature] = []
    var fsub = fsub
    for (f1h, f2h) in zip(f1, f2) {
        guard let (f3, fsub2) = unifyFeature(fsub, f1: f1h, f2: f2h) else {
            return nil
        }
        features.append(f3)
        fsub = fsub2
    }
    return (features, fsub)
}

func wrapNode(_ node: Node) -> Node {
    Node (rs: .WRAP, pf: node.pf, cat: .Sbar([.F([.Decl])]), daughters: [node], logScore: node.logScore + log(0.9), source: "")
}

func conjoinNodes(_ lnode: Node, _ rnode: Node) -> Node {
    Node(rs: .DC, pf: lnode.pf + rnode.pf, cat: .Sbar([.F([.Decl])]), daughters: [lnode, rnode], logScore: lnode.logScore + rnode.logScore, source: "")
}
