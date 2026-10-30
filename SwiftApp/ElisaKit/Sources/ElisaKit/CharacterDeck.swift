/// The Bluey characters shown after a correct answer. Each name is an image in the app's
/// resources (copied from static/characters/ in Plan 3).
public enum Characters {
    public static let all = [
        "dad", "mum", "nana", "grandad", "stripe", "trixie",
        "indy", "chloe", "calypso", "rusty", "lucky", "mackenzie",
        "bluey", "bingo",
        "coco", "jack", "judo", "socks", "honey", "muffin",
        "buddy", "missy", "bently", "winton", "terriers",
    ]

    /// How long a character stays on screen.
    public static let revealSeconds = 3.0

    public static func label(_ name: String) -> String {
        name == "terriers" ? "The Terriers" : name.prefix(1).uppercased() + name.dropFirst()
    }
}

/// Deals every character once per round in random order, and never opens a round with the
/// character that closed the previous one.
public struct CharacterDeck {
    private var deck: [String] = []
    private var last = ""
    private let random: () -> Double

    public init(random: @escaping () -> Double = { Double.random(in: 0..<1) }) {
        self.random = random
    }

    public mutating func next() -> String {
        if deck.isEmpty {
            deck = shuffled(Characters.all)
            if deck.last == last { deck.swapAt(0, deck.count - 1) }
        }
        last = deck.removeLast()
        return last
    }

    // Fisher-Yates driven by `random`, so tests can pin the order.
    private func shuffled(_ items: [String]) -> [String] {
        var out = items
        for i in stride(from: out.count - 1, to: 0, by: -1) {
            out.swapAt(i, Int(random() * Double(i + 1)))
        }
        return out
    }
}
