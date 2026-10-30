/// Answers per played chord: `matrix[played][chosen]` counts how often `played` sounded and
/// she tapped `chosen`. Counts are Double because older sessions get scaled down.
public typealias ConfusionMatrix = [String: [String: Double]]

/// Session scores (src/ts/stats.ts).
public enum Scoring {
    public static func percentage(correct: Int, identifications: Int) -> Double {
        identifications == 0 ? 0 : 100 * Double(correct) / Double(identifications)
    }

    /// 0...4 for the face shown next to a session: each 10 points above 50% is one step.
    public static func neutralLevel(percentage: Double) -> Int {
        min(max(0, Int(((percentage - 50) / 10).rounded(.down))), 4)
    }
}

/// "Adaptive" chord selection (src/ts/stats.ts): chords she gets wrong, and the chords she
/// mistakes them for, come up more often.
public enum AdaptiveWeights {
    /// Sums `matrices` into one square matrix over `chords`. Chords not in play are dropped.
    public static func merge(_ matrices: [ConfusionMatrix], chords: [String]) -> ConfusionMatrix {
        var out: ConfusionMatrix = Dictionary(uniqueKeysWithValues: chords.map { played in
            (played, Dictionary(uniqueKeysWithValues: chords.map { ($0, 0.0) }))
        })
        for matrix in matrices {
            for (played, row) in matrix {
                for (chosen, count) in row where out[played]?[chosen] != nil {
                    out[played]![chosen]! += count
                }
            }
        }
        return out
    }

    /// One weight per chord in `chords`, summing to 1. A wrong answer adds `wrongWeight` to the
    /// played chord and `mistakenForWeight` to the chosen one. A chord with fewer than
    /// `threshold` answers gets the even share 1/n, and no chord drops below 1/(1.2 n).
    public static func coefficients(
        _ matrix: ConfusionMatrix,
        chords: [String],
        wrongWeight: Double = 5,
        mistakenForWeight: Double = 1.5,
        threshold: Double = 5
    ) -> [Double] {
        let n = chords.count
        let defaultValue = 1 / Double(n)
        let floor = 1 / (1.2 * Double(n))
        var weights = [Double](repeating: 0, count: n)
        var chances = [Double](repeating: 0, count: n)

        for (playedIndex, played) in chords.enumerated() {
            for (chosenIndex, chosen) in chords.enumerated() {
                guard let count = matrix[played]?[chosen] else { continue }
                if chosenIndex != playedIndex {
                    weights[playedIndex] += count * wrongWeight
                    weights[chosenIndex] += count * mistakenForWeight
                } else {
                    weights[playedIndex] += count
                }
                chances[playedIndex] += count
            }
        }

        // Masked weights are fixed; the rest are scaled to fill what is left of 1.
        var mask = chances.map { $0 < threshold }
        weights = weights.indices.map { mask[$0] ? defaultValue : weights[$0] }
        while true {
            weights = normalize(weights, mask: mask)
            guard let low = weights.indices.first(where: { weights[$0] < floor }) else { break }
            mask[low] = true
            weights[low] = floor
        }
        return weights
    }

    private static func normalize(_ values: [Double], mask: [Bool]) -> [Double] {
        let fixed = zip(values, mask).filter { $0.1 }.map(\.0).reduce(0, +)
        let free = zip(values, mask).filter { !$0.1 }.map(\.0).reduce(0, +)
        let factor = free / (1 - fixed)
        return zip(values, mask).map { $1 ? $0 : $0 / factor }
    }

    /// A random item, weighted when `weights` is given (src/ts/utils.ts randomElem).
    /// `items` must not be empty.
    public static func pick<T>(
        _ items: [T],
        weights: [Double]? = nil,
        random: () -> Double = { Double.random(in: 0..<1) }
    ) -> T {
        guard let weights else {
            return items[min(items.count - 1, Int(random() * Double(items.count)))]
        }
        let r = random()
        var cumulative = 0.0
        for (item, weight) in zip(items, weights) {
            cumulative += weight
            if r <= cumulative { return item }
        }
        return items[items.count - 1]
    }
}
