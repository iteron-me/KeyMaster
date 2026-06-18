import Foundation

struct KeyboardKey: Identifiable, Hashable {
    let id: String
    let label: String
    let keyCode: Int
    let width: Double

    init(_ id: String, _ label: String, keyCode: Int, width: Double = 1) {
        self.id = id
        self.label = label
        self.keyCode = keyCode
        self.width = width
    }
}

enum KeyCatalog {
    static let defaultRows: [[KeyboardKey]] = [
        [
            KeyboardKey("esc", "esc", keyCode: 53, width: 1.2),
            KeyboardKey("1", "1", keyCode: 18),
            KeyboardKey("2", "2", keyCode: 19),
            KeyboardKey("3", "3", keyCode: 20),
            KeyboardKey("4", "4", keyCode: 21),
            KeyboardKey("5", "5", keyCode: 23),
            KeyboardKey("6", "6", keyCode: 22),
            KeyboardKey("7", "7", keyCode: 26),
            KeyboardKey("8", "8", keyCode: 28),
            KeyboardKey("9", "9", keyCode: 25),
            KeyboardKey("0", "0", keyCode: 29),
            KeyboardKey("minus", "-", keyCode: 27),
            KeyboardKey("equal", "=", keyCode: 24),
            KeyboardKey("delete", "delete", keyCode: 51, width: 1.8)
        ],
        [
            KeyboardKey("tab", "tab", keyCode: 48, width: 1.5),
            KeyboardKey("q", "Q", keyCode: 12),
            KeyboardKey("w", "W", keyCode: 13),
            KeyboardKey("e", "E", keyCode: 14),
            KeyboardKey("r", "R", keyCode: 15),
            KeyboardKey("t", "T", keyCode: 17),
            KeyboardKey("y", "Y", keyCode: 16),
            KeyboardKey("u", "U", keyCode: 32),
            KeyboardKey("i", "I", keyCode: 34),
            KeyboardKey("o", "O", keyCode: 31),
            KeyboardKey("p", "P", keyCode: 35),
            KeyboardKey("leftBracket", "[", keyCode: 33),
            KeyboardKey("rightBracket", "]", keyCode: 30),
            KeyboardKey("backslash", "\\", keyCode: 42, width: 1.3)
        ],
        [
            KeyboardKey("caps", "caps", keyCode: 57, width: 1.8),
            KeyboardKey("a", "A", keyCode: 0),
            KeyboardKey("s", "S", keyCode: 1),
            KeyboardKey("d", "D", keyCode: 2),
            KeyboardKey("f", "F", keyCode: 3),
            KeyboardKey("g", "G", keyCode: 5),
            KeyboardKey("h", "H", keyCode: 4),
            KeyboardKey("j", "J", keyCode: 38),
            KeyboardKey("k", "K", keyCode: 40),
            KeyboardKey("l", "L", keyCode: 37),
            KeyboardKey("semicolon", ";", keyCode: 41),
            KeyboardKey("quote", "'", keyCode: 39),
            KeyboardKey("return", "return", keyCode: 36, width: 2.1)
        ],
        [
            KeyboardKey("shiftLeft", "shift", keyCode: 56, width: 2.3),
            KeyboardKey("z", "Z", keyCode: 6),
            KeyboardKey("x", "X", keyCode: 7),
            KeyboardKey("c", "C", keyCode: 8),
            KeyboardKey("v", "V", keyCode: 9),
            KeyboardKey("b", "B", keyCode: 11),
            KeyboardKey("n", "N", keyCode: 45),
            KeyboardKey("m", "M", keyCode: 46),
            KeyboardKey("comma", ",", keyCode: 43),
            KeyboardKey("period", ".", keyCode: 47),
            KeyboardKey("slash", "/", keyCode: 44),
            KeyboardKey("shiftRight", "shift", keyCode: 60, width: 2.6)
        ],
        [
            KeyboardKey("fn", "fn", keyCode: 63, width: 1),
            KeyboardKey("control", "control", keyCode: 59, width: 1.3),
            KeyboardKey("option", "option", keyCode: 58, width: 1.3),
            KeyboardKey("commandLeft", "command", keyCode: 55, width: 1.6),
            KeyboardKey("space", "space", keyCode: 49, width: 5),
            KeyboardKey("commandRight", "command", keyCode: 54, width: 1.6),
            KeyboardKey("optionRight", "option", keyCode: 61, width: 1.3),
            KeyboardKey("left", "left", keyCode: 123),
            KeyboardKey("down", "down", keyCode: 125),
            KeyboardKey("up", "up", keyCode: 126),
            KeyboardKey("right", "right", keyCode: 124)
        ]
    ]

    static let defaultKeys = defaultRows.flatMap { $0 }

    static func displayName(forKeyCode keyCode: Int) -> String {
        if let key = defaultKeys.first(where: { $0.keyCode == keyCode }) {
            return key.label
        }

        return "Key \(keyCode)"
    }
}
