struct MyLexiconParser {
    func parseMyLexicon(_ haskellProgram: String) -> [Node] {
        var myLexicon: [Node] = []
        var lines = haskellProgram.split(separator: "\n", omittingEmptySubsequences: false)[...]
        var buffer: String = String(lines.popFirst()?.drop(while: \.isWhitespace) ?? "")
        while !buffer.isEmpty || !lines.isEmpty {
            defer {
                // bufferを更新する
                var line = lines.popFirst()?.drop(while: \.isWhitespace) ?? ""
                // コメントを無視する
                while line.starts(with: "--") {
                    line = lines.popFirst()?.drop(while: \.isWhitespace) ?? ""
                }
                buffer.append(contentsOf: line)
            }

            if buffer.starts(with: "--") {
                buffer = ""
                continue
            }
            if let match = buffer.wholeMatch(of: #/.*[^\s](?<comment>\s*\-\-.*)$/#) {
                buffer.removeLast(match.output.comment.count)
                // print(buffer)
                // print(match.output.comment)
            }
            // 次の行に続く場合
            if buffer.last != "," {
                if !lines.isEmpty {
                    buffer += " "
                    continue
                } else {
                    break
                }
            }
            // 行を取得する
            let line = buffer[...]
            if let index = line.firstIndex(where: \.isWhitespace) {
                let order = line[..<index]
                if ["conjSuffix", "conjNSuffix"].contains(order) {
                    guard let (startIndex, endIndex) = rangeOfString(line: line[index...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[index...]) as string in \(line)")
                        buffer += " "
                        continue
                    }
                    let word = String(line[startIndex ..< endIndex])
                    guard let (startIndex, endIndex) = rangeOfString(line: line[line.index(after: endIndex)...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[line.index(after: endIndex)...]) as string in \(line)")
                        buffer += " "
                        continue
                    }
                    let source = String(line[startIndex ..< endIndex])
                    guard let (startIndex, endIndex, f1) = parseFeatureValues(line: line[endIndex...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[endIndex...]) as feature values in \(line)")
                        buffer += " "
                        continue
                    }
                    guard let (startIndex, endIndex, f2) = parseFeatureValues(line: line[endIndex...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[endIndex...]) as feature values in \(line)")
                        buffer += " "
                        continue
                    }
                    if "conjNSuffix" == order {
                        myLexicon.append(
                            conjNSuffix(
                                word,
                                source,
                                f1,
                                f2
                            )
                        )
                    } else if "conjSuffix" == order {
                        myLexicon.append(
                            conjSuffix(
                                word,
                                source,
                                f1,
                                f2
                            )
                        )
                    } else {
                        fatalError("Unknown case \(order)")
                    }
                } else if order == "verblex" {
                    guard let (startIndex, endIndex) = rangeOfBlacketMatch(line: line[index...]) else {
                        buffer += " "
                        continue
                    }
                    let words = line[startIndex ..< endIndex].dropFirst().dropLast().split(separator: ",").map { (word: Substring) in
                        word.dropFirst().dropLast()
                    }
                    guard let (startIndex, endIndex) = rangeOfString(line: line[endIndex...]) else {
                        buffer += " "
                        continue
                    }
                    let source = line[startIndex ..< endIndex]
                    guard let (startIndex, endIndex) = rangeOfBlacketMatch(line: line[endIndex...]) else {
                        buffer += " "
                        continue
                    }
                    let f1 = parseBracketAsFeatureValues(part: line[startIndex ..< endIndex])
                    guard let (startIndex, endIndex) = rangeOfBlacketMatch(line: line[line.index(after: endIndex)...]) else {
                        buffer += " "
                        continue
                    }
                    let f2 = parseBracketAsFeatureValues(part: line[startIndex ..< endIndex])
                    guard let (_, endIndex) = rangeOfString(line: line[index...]) else {
                        buffer += " "
                        continue
                    }
                    //                let daihyo = line[startIndex ..< endIndex]
                    guard let (startIndex, endIndex) = rangeOfString(line: line[line.index(after: endIndex)...]) else {
                        buffer += " "
                        continue
                    }
                    let cf = line[startIndex ..< endIndex]
                    myLexicon.append(contentsOf: verblex(
                        words,
                        source,
                        f1,
                        f2,
                        cf
                    ))
                } else if order == "mylex\'" {
                    guard let (startIndex, endIndex) = rangeOfBlacketMatch(line: line[index...]) else {
                        buffer += " "
                        continue
                    }
                    let words = line[startIndex ..< endIndex].dropFirst().dropLast().split(separator: ",").map { (word: Substring) in
                        word.dropFirst().dropLast()
                    }
                    guard let (startIndex, endIndex) = rangeOfString(line: line[endIndex...]) else {
                        buffer += " "
                        continue
                    }
                    let source = line[startIndex ..< endIndex]

                    guard let (endIndex, score) = parseIntegerFromStart(line: line[line.index(endIndex, offsetBy: 2)...]) else {
                        buffer += " "
                        continue
                    }

                    guard let (startIndex, endIndex, cat) = rangeOfCategory(line: line[endIndex...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[endIndex...]) as cat in \(line)")
                        buffer += " "
                        continue
                    }

                    guard let _ = rangeOfLf(line: line[endIndex...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[endIndex...]) as lf in \(line): cat: \(line[startIndex ..< endIndex])")
                        buffer += " "
                        continue
                    }
                    //                let lf = line[startIndex ..< endIndex]

                    myLexicon.append(contentsOf: mylex(
                        words,
                        source,
                        score,
                        cat
                    ))
                } else if order == "ec" {
                    guard let (startIndex, endIndex) = rangeOfString(line: line[index...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[index...]) as string in \(line)")
                        buffer += " "
                        continue
                    }
                    let word = String(line[startIndex ..< endIndex])
                    guard let (startIndex, endIndex) = rangeOfString(line: line[line.index(after: endIndex)...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[line.index(after: endIndex)...]) as string in \(line)")
                        buffer += " "
                        continue
                    }
                    let source = String(line[startIndex ..< endIndex])
                    guard let (endIndex, score) = parseIntegerFromStart(line: line[line.index(endIndex, offsetBy: 2)...]) else {
                        buffer += " "
                        continue
                    }

                    guard let (startIndex, endIndex, cat) = rangeOfCategory(line: line[endIndex...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[endIndex...]) as cat in \(line)")
                        buffer += " "
                        continue
                    }
                    guard let _ = rangeOfLf(line: line[endIndex...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[endIndex...]) as lf in \(line): cat: \(line[startIndex ..< endIndex])")
                        buffer += " "
                        continue
                    }
                    //                let lf = line[startIndex ..< endIndex]
                    myLexicon.append(ec(
                        word,
                        source,
                        score,
                        cat
                    ))
                } else {
                    guard let (startIndex, endIndex) = rangeOfBlacketMatch(line: line[index...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[index...]) as matched blacket")
                        buffer += " "
                        continue
                    }
                    let words = line[startIndex ..< endIndex].dropFirst().dropLast().split(separator: ",").map { (word: Substring) in
                        word.dropFirst().dropLast()
                    }
                    guard let (startIndex, endIndex) = rangeOfString(line: line[endIndex...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[endIndex...]) as string")
                        buffer += " "
                        continue
                    }
                    let source = line[startIndex ..< endIndex]

                    // 文字列の後なので
                    guard let (startIndex, endIndex, cat) = rangeOfCategory(line: line[line.index(after: endIndex)...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[endIndex...]) as cat")
                        buffer += " "
                        continue
                    }

                    guard let _ = rangeOfLf(line: line[endIndex...]) else {
                        print("parseMyLexicon: \(#line): failed to parse \(line[endIndex...]) as lf in \(line): cat: \(line[startIndex ..< endIndex])")
                        buffer += " "
                        continue
                    }
                    //                let lf = line[startIndex ..< endIndex]

                    if order == "mylex" {
                        myLexicon.append(contentsOf: mylex(
                            words,
                            source,
                            cat
                        ))
                    } else {
                        fatalError("Unknown order: \(order): \(line)")
                    }
                }
            } else {
                fatalError("Unknown situation: \(line)")
            }
            // bufferをクリアする
            buffer = ""
        }
        return myLexicon
    }

    func rangeOfString(line: Substring) -> (startIndex: String.Index, endIndex: String.Index)? {
        guard let startIndex = line.firstIndex(where: {$0 == "\""}) else {
            return nil
        }
        let nextStartIndex = line.index(startIndex, offsetBy: 1)

        guard let endIndex = line[nextStartIndex...].firstIndex(where: {$0 == "\""}) else {
            return nil
        }
        return (nextStartIndex, endIndex)
    }

    /// カッコが噛み合うように最大の範囲を取得する
    func rangeOfParenMatch(line: some StringProtocol) -> (startIndex: String.Index, endIndex: String.Index)? {
        guard let startIndex = line.firstIndex(where: {$0 == "("}) else {
            return nil
        }
        var endIndex = line.index(startIndex, offsetBy: 1)

        var count = 1
        var inStringLiteral = false
        while count != 0, endIndex < line.endIndex {
            let char = line[endIndex]
            if !inStringLiteral, char == "(" {
                count += 1
            } else if !inStringLiteral, char == ")" {
                count -= 1
            } else if char == "\"" {
                inStringLiteral.toggle()
            }
            endIndex = line.index(after: endIndex)
        }
        if count != 0 {
            return nil
        }
        return (startIndex, endIndex)
    }

    /// lf部分を取得する
    func rangeOfLf(line: Substring) -> (startIndex: String.Index, endIndex: String.Index)? {
        let part = line.drop(while: \.isWhitespace)
        let exp = ["andSR", "orSR", "argumentCM", "negOperator"]
        for string in exp {
            if part.starts(with: string) {
                return (part.startIndex, part.index(part.startIndex, offsetBy: string.count))
            }
        }
        return rangeOfParenMatch(line: part)
    }

    /// カテゴリ部分を取得する
    ///  - こいつが結局Catを返せばいいんじゃないか
    func rangeOfCategory(line: some StringProtocol, callerLine: Int = #line) -> (startIndex: String.Index, endIndex: String.Index, cat: Cat)? {
        let part = line.drop(while: \.isWhitespace)
        let tExp = ["T"]
        for string in tExp {
            if part.starts(with: string) {
                var p = part.dropFirst(string.count + 1)
                guard let (e, b) = parseBoolFromStart(line: p) else {
                    fatalError("Error in parsing Bool in \(p)")
                }
                p = p[e...].dropFirst()
                guard let (e, i) = parseIntegerFromStart(line: p) else {
                    fatalError("Error in parsing Int in \(p)")
                }
                p = p[e...].dropFirst()
                guard let (s, e, cat) = rangeOfCategory(line: p) else {
                    fatalError("Error in parsing in \(p) in \(part), others: \(b), \(i)")
                }
                // アドホックな実装だが、p[s..<e]がカッコの部分ではなく、かつcatがSL/BSだった場合は分析を変更する (結合性の問題)
                if p[s] != "(" {
                    if case let .SL(left, right) = cat {
                        return (part.startIndex, e, .SL(tGeneratorForString(string)(b, i, left), right))
                    } else if case let .BS(left, right) = cat {
                        return (part.startIndex, e, .BS(tGeneratorForString(string)(b, i, left), right))
                    }
                }
                guard s == p.startIndex else {
                    fatalError("Error in parsing in \(p) in \(part), others: \(b), \(i)")
                }
                p = p[e...]

                if p.starts(with: " `SL` ") || p.starts(with: " `BS` ") {
                    let op = p.dropFirst(2).prefix(2)
                    p = p.dropFirst(6)
                    guard let (_, endIndex, rhs) = rangeOfCategory(line: p) else {
                        fatalError("Error: \(line)")
                    }
                    return (part.startIndex, endIndex, operatorForString(op)(tGeneratorForString(string)(b, i, cat), rhs))
                } else {
                    return (part.startIndex, p.startIndex, tGeneratorForString(string)(b, i, cat))
                }
            }
        }
        let fExp = ["NP", "Sbar", "S"]
        for string in fExp {
            if part.starts(with: string) {
                var p = part.dropFirst(string.count).drop(while: \.isWhitespace)
                guard let (_, e, f) = parseFeatuers(part: p) else {
                    fatalError("Error: \(line)")
                }
                p = p[e...]
                if p.starts(with: " `SL` ") || p.starts(with: " `BS` ") {
                    let op = p.dropFirst(2).prefix(2)
                    p = p.dropFirst(6)
                    guard let (_, endIndex, rhs) = rangeOfCategory(line: p) else {
                        fatalError("Error: \(line)")
                    }
                    return (part.startIndex, endIndex, operatorForString(op)(fGeneratorForString(string)(f), rhs))
                } else {
                    return (part.startIndex, p.startIndex, fGeneratorForString(string)(f))
                }
            }
        }
        let defSExp = ["defS"]
        for string in defSExp {
            if part.starts(with: string) {
                var p = part.dropFirst(string.count).drop(while: \.isWhitespace)
                guard let (_, e, f1) = parseFeatureValues(line: p) else {
                    fatalError("Error: \(line)")
                }
                p = p[e...]
                guard let (_, e, f2) = parseFeatureValues(line: p) else {
                    fatalError("Error: \(line)")
                }
                p = p[e...]
                if p.starts(with: " `SL` ") || p.starts(with: " `BS` ") {
                    let op = p.dropFirst(2).prefix(2)
                    p = p.dropFirst(6)
                    guard let (_, endIndex, rhs) = rangeOfCategory(line: p) else {
                        fatalError("Error: \(line)")
                    }
                    return (part.startIndex, endIndex, operatorForString(op)(dGeneratorForString(string)(f1, f2), rhs))
                } else {
                    return (part.startIndex, p.startIndex, dGeneratorForString(string)(f1, f2))
                }
            }
        }

        let catExp = ["CONJ", "N", "modifiableS", "RPAREN", "LPAREN"]
        for string in catExp {
            if part.starts(with: string) {
                var p = part.dropFirst(string.count)
                if p.starts(with: " `SL` ") || p.starts(with: " `BS` ") {
                    let op = p.dropFirst(2).prefix(2)
                    p = p.dropFirst(6)
                    guard let (_, endIndex, rhs) = rangeOfCategory(line: p) else {
                        fatalError("Error: \(line)")
                    }
                    return (part.startIndex, endIndex, operatorForString(op)(cGeneratorForString(string), rhs))
                } else {
                    return (part.startIndex, p.startIndex, cGeneratorForString(string))
                }
            }
        }

        if let (s, e) = rangeOfParenMatch(line: part) {
            guard let (_, _, r) = rangeOfCategory(line: part[s..<e].dropFirst().dropLast()) else {
                fatalError("Error: \(line)")
            }
            var p = part[e...]
            if p.starts(with: " `SL` ") || p.starts(with: " `BS` ") {
                let op = p.dropFirst(2).prefix(2)
                p = p.dropFirst(6)
                guard let (_, endIndex, rhs) = rangeOfCategory(line: p) else {
                    fatalError("Error: \(line)")
                }
                return (s, endIndex, operatorForString(op)(r, rhs))
            } else {
                return (s, p.startIndex, r)
            }
        }
        return nil
    }

    /// カッコが噛み合うように最大の範囲を取得する
    func rangeOfBlacketMatch(line: some StringProtocol) -> (startIndex: String.Index, endIndex: String.Index)? {
        guard let startIndex = line.firstIndex(where: {$0 == "["}) else {
            return nil
        }
        var endIndex = line.index(startIndex, offsetBy: 1)

        var count = 1
        var inStringLiteral = false
        while count != 0, endIndex < line.endIndex {
            let char = line[endIndex]
            if !inStringLiteral, char == "[" {
                count += 1
            } else if !inStringLiteral, char == "]" {
                count -= 1
            } else if char == "\"" {
                inStringLiteral.toggle()
            }
            endIndex = line.index(after: endIndex)
        }
        if count != 0 {
            return nil
        }
        return (startIndex, endIndex)
    }

    /// カッコが噛み合うように最大の範囲を取得する
    func parseBoolFromStart(line: some StringProtocol) -> (endIndex: String.Index, value: Bool)? {
        if line.prefix(4) == "True" {
            return (line.index(line.startIndex, offsetBy: 4), true)
        } else if line.prefix(5) == "False" {
            return (line.index(line.startIndex, offsetBy: 5), false)
        }
        return nil
    }

    /// Int
    func parseIntegerFromStart(line: some StringProtocol) -> (endIndex: String.Index, value: Int)? {
        if let endIndex = line.firstIndex(where: {!$0.isNumber}), let v = Int(line[..<endIndex]) {
            return (endIndex, v)
        }
        return nil
    }

    func parseFeatureValues(line: some StringProtocol) -> (startIndex: String.Index, endIndex: String.Index, value: [FeatureValue])? {
        var p = line[...].drop(while: \.isWhitespace)
        let startIndex = p.startIndex
        let exp = ["verb", "anyPos", "nonStem", "adjective"]
        var result: [FeatureValue] = []
        for string in exp {
            if p.starts(with: string) {
                result.append(contentsOf: fvsGeneratorForString(string))
                p = p.dropFirst(string.count)
                break
            }
        }
        if let (s, e) = rangeOfBlacketMatch(line: p) {
            result.append(contentsOf: parseBracketAsFeatureValues(part: p[s..<e]))
            p = p[e...]
        }
        if p.starts(with: "++") {
            p = p.dropFirst(2)
            guard let (_, e, rest) = parseFeatureValues(line: p) else {
                fatalError("Error in parsing \(p)")
            }
            result.append(contentsOf: rest)
            p = p[e...]
        }
        return (startIndex, p.startIndex, result)
    }

    /// [...]を`[FeatureValue]`として解釈する
    func parseBracketAsFeatureValues(part: some StringProtocol) -> [FeatureValue] {
        return part.dropFirst().dropLast().split(separator: ",").compactMap{FeatureValue(rawValue: String($0))}
    }

    /// [...]を`[Feature]`として解釈する
    func parseBracketAsFeatures(part: some StringProtocol, callerLine: Int = #line) -> [Feature] {
        var features: [Feature] = []
        var p = part.dropFirst().dropLast().drop(while: \.isWhitespace)
        while !p.isEmpty {
            defer {
                p = p.drop(while: \.isWhitespace)
                // コンマの処理
                if p.starts(with: ",") {
                    p = p.dropFirst()
                }
                p = p.drop(while: \.isWhitespace)
            }
            if p.starts(with: "F") {
                p = p.dropFirst(1)
                if let (_, e, v) = parseFeatureValues(line: p) {
                    features.append(.F(v))
                    p = p[e...]
                    continue
                }
                fatalError("Error in parsing \(p) as FeatureValue in \(part)")
            }
            if p.starts(with: "SF") {
                p = p.dropFirst(2+1)
                guard let (e, i) = parseIntegerFromStart(line: p) else {
                    fatalError("Error in parsing head of \(p) as Int in \(part)")
                }
                if let (_, e, v) = parseFeatureValues(line: p[e...]) {
                    features.append(.SF(i, v))
                    p = p[e...]
                    continue
                }
                fatalError("Error in parsing \(p) as FeatureValue in \(part)")
            }
            fatalError("Error in parsing \(p) as FeatureValue in \(part)")
        }
        return features
    }

    func parseFeatuers(part: some StringProtocol) -> (startIndex: String.Index, endIndex: String.Index, features: [Feature])? {
        var p = part.drop(while: \.isWhitespace)
        guard let (s, e) = rangeOfBlacketMatch(line: p) else {
            fatalError("Error: \(part)")
        }
        p = p[e...]
        var f = parseBracketAsFeatures(part: part[s..<e])

    `while`: while p.starts(with: "++") {
        p = p.dropFirst(2)
        let exp = ["mmmpm", "mmpmm", "mpmmm", "mppmm", "m5"]
        for string in exp {
            if p.starts(with: string) {
                f.append(contentsOf: fsGeneratorForString(string))
                p = p.dropFirst(string.count)
                continue `while`
            }
        }
        fatalError("Unknown case \(p)")
    }
        return (s, p.startIndex, f)
    }


    func operatorForString(_ op: some StringProtocol) -> (Cat, Cat) -> Cat {
        if op == "SL" {
            return Cat.SL
        }
        if op == "BS" {
            return Cat.BS
        }
        fatalError("Unexpected case! \(op)")
    }

    func tGeneratorForString(_ cathead: some StringProtocol) -> (Bool, Int, Cat) -> Cat {
        if cathead == "T" {
            return Cat.T
        }
        fatalError("Unexpected case! \(cathead)")
    }


    func fGeneratorForString(_ cathead: some StringProtocol) -> ([Feature]) -> Cat {
        if cathead == "NP" {
            return Cat.NP
        }
        if cathead == "S" {
            return Cat.S
        }
        if cathead == "Sbar" {
            return Cat.Sbar
        }
        fatalError("Unexpected case! \(cathead)")
    }

    func dGeneratorForString(_ cathead: some StringProtocol) -> ([FeatureValue], [FeatureValue]) -> Cat {
        if cathead == "defS" {
            return defS
        }
        fatalError("Unexpected case! \(cathead)")
    }

    func cGeneratorForString(_ cathead: some StringProtocol) -> Cat {
        if cathead == "CONJ" {
            return .CONJ
        }
        if cathead == "N" {
            return .N
        }
        if cathead == "modifiableS" {
            return modifiableS
        }
        if cathead == "RPAREN" {
            return .RPAREN
        }
        if cathead == "LPAREN" {
            return .LPAREN
        }
        fatalError("Unexpected case! \(cathead)")
    }

    func fsGeneratorForString(_ string: some StringProtocol) -> [Feature] {
        if string == "mmmpm" {
            return mmmpm
        }
        if string == "mmpmm" {
            return mmpmm
        }
        if string == "mpmmm" {
            return mpmmm
        }
        if string == "mppmm" {
            return mppmm
        }
        if string == "m5" {
            return m5
        }
        fatalError("Unexpected case! \(string)")
    }

    func fvsGeneratorForString(_ p: some StringProtocol) -> [FeatureValue] {
        if p == "verb" {
            return verb
        }
        if p == "anyPos" {
            return anyPos
        }
        if p == "nonStem" {
            return nonStem
        }
        if p == "adjective" {
            return adjective
        }
        fatalError("Unexpected case! \(p)")
    }
}
