import Foundation

enum HintGenerator {
    static let defaultAlphabet = [
        "A", "S", "D", "F", "J", "K", "L",
        "Q", "W", "E", "R", "U", "I", "O",
        "G", "H", "Z", "X", "C", "V", "B", "N", "M",
        "P", "T", "Y"
    ]

    static func generate(count: Int, alphabet: [String] = defaultAlphabet) -> [String] {
        guard count > 0, !alphabet.isEmpty else {
            return []
        }

        var hints: [String] = []
        hints.reserveCapacity(count)

        for letter in alphabet {
            hints.append(letter)

            if hints.count == count {
                return hints
            }
        }

        for first in alphabet {
            for second in alphabet {
                hints.append(first + second)

                if hints.count == count {
                    return hints
                }
            }
        }

        return hints
    }
}
