import Foundation

/// Localize fixed UI copy only. User-authored names, stories and letters are never lookup keys.
/// Positional tokens allow each language to choose its own word order.
func L(_ key: String, _ arguments: Any...) -> String {
    AppLocalization.format(Bundle.main.localizedString(forKey: key, value: key, table: nil), arguments: arguments)
}

enum AppLocalization {
    static let supportedLanguages = ["zh-Hans", "en", "ja", "de", "fr", "es", "zh-Hant-HK", "ko", "ar"]
    private static let token = try! NSRegularExpression(pattern: #"\{(\d+)\}"#)

    static func format(_ template: String, arguments: [Any]) -> String {
        // Replace from the end, once: a pet named "{1}" must remain exactly that name.
        let result = NSMutableString(string: template)
        let matches = token.matches(in: template, range: NSRange(template.startIndex..., in: template))
        for match in matches.reversed() {
            guard let range = Range(match.range(at: 1), in: template),
                  let index = Int(template[range]), arguments.indices.contains(index) else { continue }
            let value = String(describing: arguments[index])
            result.replaceCharacters(in: match.range, with: value)
        }
        return result as String
    }

    static func asciiDigits(_ value: String) -> String {
        value.compactMap { character in
            character.wholeNumberValue.flatMap { (0...9).contains($0) ? String($0) : nil }
        }.joined()
    }

    static func serverMessage(_ message: String?, fallback: String) -> String {
        guard var message, !message.isEmpty else { return fallback }
        if message == "Invalid phone number" { message = "请输入正确的手机号" }
        if message == "密码错误" { message = "账号或密码不正确" }
        let localized = Bundle.main.localizedString(forKey: message, value: "__missing__", table: nil)
        if localized != "__missing__" { return localized }
        // Do not show unlocalized server diagnostics in another language.
        return Bundle.main.preferredLocalizations.first?.hasPrefix("zh") == true ? message : fallback
    }
}
