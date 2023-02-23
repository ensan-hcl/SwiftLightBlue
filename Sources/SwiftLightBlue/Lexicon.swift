// TODO: Preterm, Signatureのサポート
func constructPredicate(_ daihyo: String, _ posF: [FeatureValue], _ conjF: [FeatureValue]) -> Cat {
    return .BS(defS(posF, conjF), .NP([.F([.Ga])]))
}

func setupLexicon(sentence: String) -> [Node] {
    // 0. Add own leixcon
    let additionalLexiconFiltered = additionalLexicon.filter {sentence.contains($0.pf)}
    // TODO: 1. Setting up lexical items provided by JUMAN++
    // 2. Setting up private lexicon
    let myLexiconParser = MyLexiconParser()
    let mylexiconFiltered = myLexiconParser.parseMyLexicon(myLeiconProgram).filter {sentence.contains($0.pf)}
    // TODO: 3. Setting up compound nouns (returned from an execution of JUMAN)
    // TODO: 4. Accumulating common nons and proper names entries
    // 5. 0+1+2+3+4
    let numeration = additionalLexiconFiltered + mylexiconFiltered
    return numeration
}

func lookupLexicon(word: String, lexicon: [Node]) -> [Node] {
    lexicon.filter{$0.pf == word}
}
