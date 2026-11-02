import Foundation

/// Where the streak snake's pieces go on a screen: it starts with its tail at the top centre and
/// grows clockwise along the screen edge, its back facing outward.
///
/// The body is whole pieces end to end, so the head always lands on a joint and never cuts a
/// stripe. A "stop" is one place the head can be; the head is straight, so there is none in a
/// corner or where its nose would pass the end of an edge.
public struct SnakeLayout: Sendable {
    public enum Kind: Sendable { case tail, segment, corner, head }

    /// A piece's top-left corner, its turn around that corner, and its stretch along the body.
    public struct Piece: Sendable {
        public let kind: Kind
        public let x: Double
        public let y: Double
        public let rotation: Double
        public let stretch: Double
    }

    /// The snake's body across, in points.
    public static let thickness = 26.0
    /// Empty space between the snake and the rest of the app, in points.
    public static let air = 12.0
    /// How far the app's content has to stay from a screen edge: the body, the head's bulge
    /// past it (26 units of the art's 100-unit body) and the air.
    public static let clearance = thickness * 1.26 + air

    /// The extra padding an edge needs on top of its safe area, which already keeps content away.
    public static func contentInset(safeArea: Double) -> Double {
        max(0, clearance - safeArea)
    }

    // The pieces' sizes in the art's units (scripts/snake-pieces.py).
    static let tailLength = 250.0
    static let segmentLength = 200.0
    static let cornerSize = 180.0
    static let headLength = 272.0
    /// Stretches every segment a touch so neighbours overlap instead of showing a hairline.
    private static let overlap = 0.003

    /// Points per unit of the art.
    public let scale: Double
    private let tail: Piece
    private let body: [Piece]
    private let heads: [(pieces: Int, head: Piece)]

    public var lastStop: Int { heads.count - 1 }

    public init(width: Double, height: Double, thickness: Double) {
        let scale = thickness / 100
        self.scale = scale
        let corner = Self.cornerSize * scale
        let tailLength = Self.tailLength * scale
        let headLength = Self.headLength * scale
        let segment = Self.segmentLength * scale
        let edges: [(length: Double, start: Double, last: Bool, at: (Double) -> (Double, Double), rotation: Double)] = [
            (width / 2 - corner, tailLength, false, { (width / 2 + $0, 0) }, 0),
            (height - 2 * corner, 0, false, { (width, corner + $0) }, 90),
            (width - 2 * corner, 0, false, { (width - corner - $0, height) }, 180),
            (height - 2 * corner, 0, false, { (0, height - corner - $0) }, 270),
            (width / 2 - corner, 0, true, { (corner + $0, 0) }, 0),
        ]
        let corners: [(Double, Double, Double)] = [
            (width - corner, 0, 0), (width, height - corner, 90), (corner, height, 180), (0, corner, 270),
        ]
        var body: [Piece] = []
        var heads: [(pieces: Int, head: Piece)] = []
        for (index, edge) in edges.enumerated() {
            let room = edge.length - edge.start - (edge.last ? headLength : 0)
            let count = max(0, Int((room / segment).rounded()))
            let step = count > 0 ? room / Double(count) : 0
            var along = edge.start
            for number in 0...count {
                let (x, y) = edge.at(along)
                if along + headLength <= edge.length + 0.01 {
                    heads.append((body.count, Piece(kind: .head, x: x, y: y, rotation: edge.rotation, stretch: 1)))
                }
                if number < count {
                    let stretch = step / segment + Self.overlap
                    body.append(Piece(kind: .segment, x: x, y: y, rotation: edge.rotation, stretch: stretch))
                    along += step
                }
            }
            if index < corners.count {
                let (x, y, rotation) = corners[index]
                body.append(Piece(kind: .corner, x: x, y: y, rotation: rotation, stretch: 1))
            }
        }
        self.tail = Piece(kind: .tail, x: width / 2, y: 0, rotation: 0, stretch: 1)
        self.body = body
        self.heads = heads
    }

    /// The stop for a share of the way round, 0...1, spread evenly so each hit moves the head.
    public func stop(forProgress progress: Double) -> Int {
        Int((min(1, max(0, progress)) * Double(lastStop)).rounded())
    }

    /// The tail, the body so far and the head last, so the head draws on top.
    public func pieces(atStop stop: Int) -> [Piece] {
        let (count, head) = heads[min(max(stop, 0), lastStop)]
        return [tail] + body.prefix(count) + [head]
    }
}
