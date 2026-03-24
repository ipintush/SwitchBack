struct TextConverter {
    // SI-1452 Israeli layout on US QWERTY: English key → Hebrew character
    private static let enToHe: [Character: Character] = [
        "q": "/", "w": "'", "e": "ק", "r": "ר", "t": "א",
        "y": "ט", "u": "ו", "i": "ן", "o": "ם", "p": "פ",
        "a": "ש", "s": "ד", "d": "ג", "f": "כ", "g": "ע",
        "h": "י", "j": "ח", "k": "ל", "l": "ך", ";": "ף", "'": ",",
        "z": "ז", "x": "ס", "c": "ב", "v": "ה", "b": "נ",
        "n": "מ", "m": "צ", ",": "ת", ".": "ץ", "/": "."
    ]

    // Hebrew character → English key (inverse mapping)
    private static let heToEn: [Character: Character] = {
        var map: [Character: Character] = [:]
        for (en, he) in enToHe {
            map[he] = en
        }
        return map
    }()

    static func isHebrew(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value >= 0x05D0 && $0.value <= 0x05EA }
    }

    static func convert(_ text: String) -> String {
        let toHebrew = !isHebrew(text)
        let map = toHebrew ? enToHe : heToEn

        return String(text.map { ch in
            if toHebrew {
                // For English→Hebrew: lowercase the char before lookup so A and a both map
                let lower = Character(ch.lowercased())
                return map[lower] ?? ch
            } else {
                return map[ch] ?? ch
            }
        })
    }
}
