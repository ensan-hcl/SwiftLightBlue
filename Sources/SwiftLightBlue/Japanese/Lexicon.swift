// Status: Syntax: NOT DONE
// Status: Semantics: NOT DONE

import Foundation

func getBundle() -> Bundle {
#if SWIFT_PACKAGE
    let bundle = Bundle.module
#else
    let bundle = Bundle(for: ChartParser.self)
#endif
    return bundle
}

enum LoadJumandicError: Error {
    case resourceNotFound
}
func loadJumandic() throws -> String {
    guard let resourceURL = getBundle().url(forResource: "Juman.dic", withExtension: "tsv") else {
        throw LoadJumandicError.resourceNotFound
    }
    let string = try String(contentsOf: resourceURL, encoding: .utf8)
    return string
}

// TODO: Preterm, Signatureのサポート
func constructPredicate(_ daihyo: String, _ posF: [FeatureValue], _ conjF: [FeatureValue]) -> Cat {
    return .BS(defS(posF, conjF), .NP([.F([.Ga])]))
}

let _jumandic = ((try? loadJumandic()) ?? "").split(separator: "\n")

func setupLexicon(sentence: String) -> [Node] {
    // 0. Add own leixcon
    let additionalLexiconFiltered = additionalLexicon.filter {sentence.contains($0.pf)}
    // 1. Setting up lexical items provided by JUMAN++
    let jumandicFiltered = _jumandic.compactMap { line in
        let items = line.split(separator: "\t", omittingEmptySubsequences: false)
        if sentence.contains(items[0]) {
            return items.map(String.init)
        }
        return nil
    }
    let (jumandicParsed, cn, pn) = jumandicFiltered.reduce(([], [:], [:]), parseJumanLine)
    // 2. Setting up private lexicon
    let mylexiconFiltered = myLexicon.filter {sentence.contains($0.pf)}
    // TODO: 3. Setting up compound nouns (returned from an execution of JUMAN)
    // 4. Accumulating common nons and proper names entries
    let commonNouns = cn.map { (hyoki, info) in
        lexicalitem(hyoki, "(CN)", info.1, .N)
    }
    let properNouns = pn.map { (hyoki, info) in
        lexicalitem(hyoki, "(PN)", info.1, .SL(.T(true, 1, modifiableS), .BS(.T(true, 1, modifiableS), .NP([.F([.Nc])]))))
    }
    // 5. 0+1+2+3+4
    let numeration = additionalLexiconFiltered + mylexiconFiltered + jumandicParsed + commonNouns + properNouns
    print(numeration.count)
    return numeration
}

func lookupLexicon(word: String, lexicon: [Node]) -> [Node] {
    lexicon.filter{$0.pf == word}
}

typealias ParseJumanLinePartialResult = (lexicalItems: [Node], commonNouns: [String: (String, Int)], properNouns: [String: (String, Int)])
func parseJumanLine(_ partialResult: ParseJumanLinePartialResult, _ jumanLine: [String]) -> ParseJumanLinePartialResult {
    if jumanLine.count < 7 {
        print("Unknwon case", jumanLine)
        return partialResult
    }
    let hyoki = jumanLine[0]
    let score = jumanLine[1]
    let cat = jumanLine[2]
    let daihyo = jumanLine[3]
    let yomi = jumanLine[4]
    let source = jumanLine[5]
    let caseframe = jumanLine[6]
    if cat.hasPrefix("名詞:普通名詞") {
        // let commonnouns' = M.insertWith (\(t1,s1) (t2,s2) -> (T.intercalate ";" [t1,t2], max s1 s2)) hyoki ((T.concat [daihyo',"/",yomi']),(read (T.unpack score')::Integer)) commonnouns in

        var newCommonNouns = partialResult.commonNouns
        let newItem = ("\(daihyo)/\(yomi)", Int(score)!)
        if let item = newCommonNouns.removeValue(forKey: hyoki) {
            newCommonNouns[hyoki] = ("\(item.0);\(newItem.0)", max(item.1, newItem.1))
        } else {
            newCommonNouns[hyoki] = newItem
        }
        return (partialResult.lexicalItems, newCommonNouns, partialResult.properNouns)
    }
    if cat.hasPrefix("名詞:固有名詞") ||  cat.hasPrefix("名詞:人名") ||  cat.hasPrefix("名詞:地名") ||  cat.hasPrefix("名詞:組織名") {
        var newProperNouns = partialResult.properNouns
        let newItem = ("\(daihyo)/\(yomi)", Int(score)!)
        if let item = newProperNouns.removeValue(forKey: hyoki) {
            newProperNouns[hyoki] = ("\(item.0);\(newItem.0)", max(item.1, newItem.1))
        } else {
            newProperNouns[hyoki] = newItem
        }
        return (partialResult.lexicalItems, partialResult.commonNouns, newProperNouns)
    }
    let cats = jumanPos2Cat("\(daihyo)/\(yomi)", cat, caseframe)
    let newItems = cats.map { cat in
        lexicalitem(hyoki, "(J\(source.prefix(3)))", Int(score)!, cat)
    }
    return (newItems + partialResult.lexicalItems, partialResult.commonNouns, partialResult.properNouns)
}

func jumanPos2Cat(_ daihyo: String, _ cat: String, _ caseframe: String) -> [Cat] {
    if cat.hasPrefix("名詞:副詞的名詞") {
        return constructSubordinateConjunction(daihyo)
    } else if cat.hasPrefix("名詞:時相名詞") {
        return constructPredicate(daihyo, [.Nda, .Nna, .Nno, .Nni, .Nemp], [.NStem])
    } else if cat.hasPrefix("動詞:子音動詞カ行促音便形") {
        return constructVerb(daihyo, caseframe, [.V5IKU, .V5YUK], [.Stem])
    } else if cat.hasPrefix("動詞:子音動詞カ行") {
        return constructVerb(daihyo, caseframe, [.V5k], [.Stem])
    } else if cat.hasPrefix("動詞:子音動詞サ行") {
        return constructVerb(daihyo, caseframe, [.V5s], [.Stem])
    } else if cat.hasPrefix("動詞:子音動詞タ行") {
        return constructVerb(daihyo, caseframe, [.V5t], [.Stem])
    } else if cat.hasPrefix("動詞:子音動詞ナ行") {
        return constructVerb(daihyo, caseframe, [.V5n], [.Stem])
    } else if cat.hasPrefix("動詞:子音動詞マ行") {
        return constructVerb(daihyo, caseframe, [.V5m], [.Stem])
    } else if cat.hasPrefix("動詞:子音動詞ラ行イ形") {
        return constructVerb(daihyo, caseframe, [.V5NAS], [.Stem])
    } else if cat.hasPrefix("動詞:子音動詞ラ行") {
        return constructVerb(daihyo, caseframe, [.V5r], [.Stem])
    } else if cat.hasPrefix("動詞:子音動詞ワ行文語音便形") {
        return constructVerb(daihyo, caseframe, [.V5TOW], [.Stem])
    } else if cat.hasPrefix("動詞:子音動詞ワ行") {
        return constructVerb(daihyo, caseframe, [.V5w], [.Stem])
    } else if cat.hasPrefix("動詞:子音動詞ガ行") {
        return constructVerb(daihyo, caseframe, [.V5g], [.Stem])
    } else if cat.hasPrefix("動詞:子音動詞バ行") {
        return constructVerb(daihyo, caseframe, [.V5b], [.Stem])
    } else if cat.hasPrefix("動詞:母音動詞") {
        return constructVerb(daihyo, caseframe, [.V1], [.Stem, .Neg, .Cont, .NegL, .EuphT])
    } else if cat.hasPrefix("動詞:カ変動詞") {
        return constructVerb(daihyo, caseframe, [.VK], [.Stem])
    } else if cat.hasPrefix("名詞:サ変名詞") {
        return constructCommonNoun(daihyo) + constructVerb(daihyo, caseframe, [.VS, .VSN], [.Stem]) + constructPredicate(daihyo, [.Nda, .Ntar], [.NStem])
    } else if cat.hasPrefix("動詞:サ変動詞") {
        return constructVerb(daihyo, caseframe, [.VS], [.Stem])
    } else if cat.hasPrefix("動詞:ザ変動詞") {
        return constructVerb(daihyo, caseframe, [.VZ], [.Stem])
    } else if cat.hasPrefix("動詞:動詞性接尾辞ます型") {
        return constructVerb(daihyo, caseframe, [.V5NAS], [.Stem])
    } else if cat.hasPrefix("形容詞:イ形容詞アウオ段") {
        return constructPredicate(daihyo, [.Aauo], [.Stem])
    } else if cat.hasPrefix("形容詞:イ形容詞イ段") {
        return constructPredicate(daihyo, [.Ai], [.Stem, .Term])
    } else if cat.hasPrefix("形容詞:イ形容詞イ段特殊") {
        return constructPredicate(daihyo, [.Ai, .Nna], [.Stem]) // 大きい
    } else if cat.hasPrefix("形容詞:ナ形容詞") {
        return constructPredicate(daihyo, [.Nda, .Nna, .Nni], [.NStem])
    } else if cat.hasPrefix("形容詞:ナ形容詞特殊") {
        return constructPredicate(daihyo, [.Nda, .Nna], [.NStem]) // 同じ
    } else if cat.hasPrefix("形容詞:ナノ形容詞") {
        return constructPredicate(daihyo, [.Nda, .Nna, .Nno, .Nni], [.NStem])
    } else if cat.hasPrefix("形容詞:タル形容詞") {
        return constructPredicate(daihyo, [.Ntar, .Nto], [.Stem])
    } else if cat.hasPrefix("副詞") {
        return constructPredicate(daihyo, [.Nda, .Nna, .Nno, .Nni, .Nto, .Nemp], [.NStem]) + constructCommonNoun(daihyo)
    } else if cat.hasPrefix("連体詞") {
        return constructNominalPrefix(daihyo)
    } else if cat.hasPrefix("接続詞") {
        return constructConjunction(daihyo)
    } else if cat.hasPrefix("接頭辞:名詞接頭辞") {
        return constructNominalPrefix(daihyo)
    } else if cat.hasPrefix("接頭辞:動詞接頭辞") {
        return [
            .SL(defS(verb, [.Stem]), defS(verb, [.Stem]))
        ]
    } else if cat.hasPrefix("接頭辞:イ形容詞接頭辞") {
        return [
            .SL(.BS(defS([.Aauo], [.Stem]), .NP([.F([.Ga])])), .BS(defS([.Aauo], [.Stem]), .NP([.F([.Ga])])))
        ]
    } else if cat.hasPrefix("接頭辞:ナ形容詞接頭辞") {
        return [
            .SL(.BS(defS([.Nda], [.NStem]), .NP([.F([.Ga])])), .BS(defS([.Nda], [.NStem]), .NP([.F([.Ga])])))
        ]
    } else if cat.hasPrefix("接尾辞:名詞性名詞助数辞") || cat.hasPrefix("接尾辞:名詞性特殊接尾辞") || cat.hasPrefix("接尾辞:名詞性述語接尾辞") {
        return constructNominalSuffix(daihyo)
    } else if cat.hasPrefix("特殊:括弧始") {
        return [.LPAREN]
    } else if cat.hasPrefix("特殊:括弧終") {
        return [.RPAREN]
    } else if cat.hasPrefix("数詞") {
        return constructCommonNoun(daihyo)
    } else if cat.hasPrefix("感動詞") {
        return [
            defS([.Exp], [.Term])
        ]
    } else {
        return [
            defS([.Exp], [.Term])
        ]
    }
}

func constructPredicate(_ daihyo: String, _ posF: [FeatureValue], _ conjF: [FeatureValue]) -> [Cat] {
    [
        .BS(defS(posF, conjF), .NP([.F([.Ga])]))
    ]
}

func constructCommonNoun(_ daihyo: String) -> [Cat] {
    [
        .N
    ]
}

func constructVerb(_ daihyo: String, _ caseFrame: String, _ posF: [FeatureValue], _ conjF: [FeatureValue]) -> [Cat] {
    let caseFrameList = (caseFrame.isEmpty ? "ガ" : caseFrame).split(separator: "#", omittingEmptySubsequences: false)
    return caseFrameList.map {
        verbCat($0, posF, conjF)
    }
}

func constructNominalPrefix(_ daihyo: String) -> [Cat] {
    [
        .SL(.N, .N)
    ]
}
func constructNominalSuffix(_ daihyo: String) -> [Cat] {
    [
        .SL(.N, .N)
    ]
}

func constructConjunction(_ daihyo: String) -> [Cat] {
    [
        .SL(
            .T(false, 1, .S([.F(anyPos), .F([.Term, .NTerm, .Pre, .Imper]), .SF(2, [.P, .M]), .SF(3, [.P, .M]), .SF(4, [.P, .M]), .F([.M]), .F([.M])])),
            .T(false, 1, .S([.F(anyPos), .F([.Term, .NTerm, .Pre, .Imper]), .SF(2, [.P, .M]), .SF(3, [.P, .M]), .SF(4, [.P, .M]), .F([.M]), .F([.M])]))
        )
    ]
}

func constructSubordinateConjunction(_ daihyo: String) -> [Cat] {
    [
        .BS(.SL(modifiableS, modifiableS), .S([.F(anyPos), .F([.Attr]), .SF(7, [.P, .M]), .SF(8, [.P, .M]), .SF(9, [.P, .M]), .F([.M]), .F([.M])]))
    ]
}
