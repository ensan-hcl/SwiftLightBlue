// TODO: Preterm, Signatureのサポート
func constructPredicate(_ daihyo: String, _ posF: [FeatureValue], _ conjF: [FeatureValue]) -> Cat {
    return .BS(defS(posF, conjF), .NP([.F([.Ga])]))
}
