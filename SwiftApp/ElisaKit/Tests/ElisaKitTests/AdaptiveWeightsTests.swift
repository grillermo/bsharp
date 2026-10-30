import Testing
@testable import ElisaKit

/// Same tolerance as vitest's toBeCloseTo(x, 2).
private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.005 }

private func zeroMatrix(_ chords: [String]) -> ConfusionMatrix {
    Dictionary(uniqueKeysWithValues: chords.map { c in
        (c, Dictionary(uniqueKeysWithValues: chords.map { ($0, 0.0) }))
    })
}

@Suite struct ScoringTests {
    @Test func percentageIsZeroWithoutAnswers() {
        #expect(Scoring.percentage(correct: 0, identifications: 0) == 0)
        #expect(Scoring.percentage(correct: 3, identifications: 4) == 75)
    }

    @Test func neutralLevelMapsPercentagesToZeroThroughFour() {
        #expect(Scoring.neutralLevel(percentage: 30) == 0)
        #expect(Scoring.neutralLevel(percentage: 50) == 0)
        #expect(Scoring.neutralLevel(percentage: 60) == 1)
        #expect(Scoring.neutralLevel(percentage: 70) == 2)
        #expect(Scoring.neutralLevel(percentage: 80) == 3)
        #expect(Scoring.neutralLevel(percentage: 95) == 4)
        #expect(Scoring.neutralLevel(percentage: 100) == 4)
    }
}

@Suite struct AdaptiveWeightsTests {
    let firstThree = ["red", "yellow", "blue"]

    @Test func mergeSumsMatricesOverTheChordsInPlay() {
        let a: ConfusionMatrix = ["red": ["red": 5, "yellow": 1], "yellow": ["yellow": 3]]
        let b: ConfusionMatrix = ["red": ["red": 2, "yellow": 2], "blue": ["blue": 4]]
        let merged = AdaptiveWeights.merge([a, b], chords: firstThree)
        #expect(merged["red"]?["red"] == 7)
        #expect(merged["red"]?["yellow"] == 3)
        #expect(merged["blue"]?["blue"] == 4)
    }

    @Test func mergeOfNothingIsAllZeros() {
        let merged = AdaptiveWeights.merge([], chords: firstThree)
        #expect(merged["red"]?["yellow"] == 0)
    }

    @Test func mergeIgnoresChordsNotInPlay() {
        let merged = AdaptiveWeights.merge([["black": ["black": 10]]], chords: firstThree)
        #expect(merged["black"] == nil)
    }

    @Test func aPerfectPlayerGetsEvenWeights() {
        let chords = ["red", "yellow", "blue", "black", "green"]
        var m = zeroMatrix(chords)
        for c in chords { m[c]![c] = 25 }
        let weights = AdaptiveWeights.coefficients(m, chords: chords)
        #expect(weights.allSatisfy { close($0, 0.20) })
    }

    @Test func aConfusedChordIsBoostedAndItsLookalikeALittle() {
        let chords = ["red", "yellow", "blue", "black", "green"]
        var m = zeroMatrix(chords)
        m["red"]!["red"] = 20
        m["yellow"]!["yellow"] = 20
        m["blue"]!["blue"] = 8
        m["blue"]!["red"] = 12 // blue played, she said red
        m["black"]!["black"] = 20
        m["green"]!["green"] = 20
        let w = AdaptiveWeights.coefficients(m, chords: chords)
        #expect(close(w[0], 0.179))
        #expect(close(w[1], 0.167))
        #expect(close(w[2], 0.321))
        #expect(close(w[3], 0.167))
        #expect(close(w[4], 0.167))
    }

    @Test func aNewChordWithoutDataGetsTheDefaultShare() {
        let chords = ["red", "yellow", "blue", "black"]
        var m = zeroMatrix(chords)
        m["red"]!["red"] = 20
        m["yellow"]!["yellow"] = 20
        m["blue"]!["blue"] = 20
        let weights = AdaptiveWeights.coefficients(m, chords: chords)
        #expect(weights.allSatisfy { close($0, 0.25) })
    }

    @Test func easyChordsBottomOutAtTheFloor() {
        let chords = ["red", "yellow", "blue", "black", "green", "orange", "purple", "pink", "brown"]
        var m = zeroMatrix(chords)
        for c in chords.prefix(7) { m[c]![c] = 20 }
        m["pink"]!["pink"] = 5
        m["pink"]!["red"] = 15
        m["brown"]!["brown"] = 5
        m["brown"]!["yellow"] = 15
        let w = AdaptiveWeights.coefficients(m, chords: chords)
        for i in 0..<7 { #expect(close(w[i], 0.093)) }
        #expect(close(w[7], 0.175))
        #expect(close(w[8], 0.175))
    }

    @Test func twoChordsOneConfused() {
        let chords = ["red", "yellow"]
        var m = zeroMatrix(chords)
        m["red"]!["red"] = 12
        m["red"]!["yellow"] = 8
        m["yellow"]!["yellow"] = 20
        let w = AdaptiveWeights.coefficients(m, chords: chords)
        #expect(close(w[0], 0.583))
        #expect(close(w[1], 0.417))
    }

    @Test func weightedPickTakesTheOnlyNonzeroWeight() {
        #expect(AdaptiveWeights.pick(["a", "b", "c"], weights: [0, 1, 0], random: { 0.5 }) == "b")
    }

    @Test func weightedPickFallsBackToTheLastItem() {
        #expect(AdaptiveWeights.pick(["a", "b", "c"], weights: [0.1, 0.1, 0.1], random: { 0.99 }) == "c")
    }

    @Test func unweightedPickIsUniform() {
        #expect(AdaptiveWeights.pick(["a", "b", "c"], random: { 0.0 }) == "a")
        #expect(AdaptiveWeights.pick(["a", "b", "c"], random: { 0.999 }) == "c")
    }
}
