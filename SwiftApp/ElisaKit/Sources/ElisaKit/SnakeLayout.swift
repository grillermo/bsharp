import Foundation

/// Where the streak snake's pieces go on a screen: it starts with its tail at the top centre and
/// grows clockwise along the screen edge, its back facing outward.
///
/// The body is whole pieces end to end, so the head always lands on a joint and never cuts a
/// stripe. A "stop" is one place the head can rest; the head is straight, so there is none in a
/// corner or where its nose would pass the end of an edge. Between stops the head rides the centre
/// line like a train car, with its neck and nose on the line, so it swings round the corners.
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
    public let tail: Piece
    /// Every body piece of a full circle, in order; a view reveals them behind the head.
    public let body: [Piece]
    /// How far along the centre line each stop's neck is.
    private let stops: [Double]
    private let lines: [Line]
    private let width: Double
    private let height: Double

    public var lastStop: Int { stops.count - 1 }
    /// The radius of the centre line round a corner, and where that line is from the screen edge.
    public var cornerRadius: Double { (Self.cornerSize - 50) * scale }
    public var edgeOffset: Double { 50 * scale }

    /// A stretch of the centre line: straight, or a quarter circle when `radius` is set.
    private struct Line {
        let start: Double
        let length: Double
        let x: Double
        let y: Double
        let degrees: Double
        var radius: Double?
    }

    public init(width: Double, height: Double, thickness: Double) {
        let scale = thickness / 100
        self.scale = scale
        self.width = width
        self.height = height
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
        var stops: [Double] = []
        var lines: [Line] = []
        var travelled = 0.0
        let half = 50 * scale
        let radius = (Self.cornerSize - 50) * scale
        for (index, edge) in edges.enumerated() {
            let turn = edge.rotation * .pi / 180
            let (startX, startY) = edge.at(0)
            lines.append(Line(start: travelled, length: edge.length, x: startX - sin(turn) * half,
                              y: startY + cos(turn) * half, degrees: edge.rotation))
            let room = edge.length - edge.start - (edge.last ? headLength : 0)
            let count = max(0, Int((room / segment).rounded()))
            let step = count > 0 ? room / Double(count) : 0
            var along = edge.start
            for number in 0...count {
                let (x, y) = edge.at(along)
                if along + headLength <= edge.length + 0.01 { stops.append(travelled + along) }
                if number < count {
                    let stretch = step / segment + Self.overlap
                    body.append(Piece(kind: .segment, x: x, y: y, rotation: edge.rotation, stretch: stretch))
                    along += step
                }
            }
            travelled += edge.length
            if index < corners.count {
                let (x, y, rotation) = corners[index]
                body.append(Piece(kind: .corner, x: x, y: y, rotation: rotation, stretch: 1))
                // The bend's centre: inward from the piece's far side by the corner's size.
                let centre = [(width - corner, corner), (width - corner, height - corner),
                              (corner, height - corner), (corner, corner)][index]
                let length = radius * .pi / 2
                lines.append(Line(start: travelled, length: length, x: centre.0, y: centre.1,
                                  degrees: rotation - 90, radius: radius))
                travelled += length
            }
        }
        self.tail = Piece(kind: .tail, x: width / 2, y: 0, rotation: 0, stretch: 1)
        self.body = body
        self.stops = stops
        self.lines = lines
    }

    /// The stop for a share of the way round, 0...1, spread evenly so each hit moves the head.
    public func stop(forProgress progress: Double) -> Int {
        Int((min(1, max(0, progress)) * Double(lastStop)).rounded())
    }

    /// How far along the centre line the neck is, for a stop or a point between two stops.
    public func distance(atStop position: Double) -> Double {
        let clamped = min(Double(lastStop), max(0, position))
        let below = Int(clamped)
        guard below < lastStop else { return stops[lastStop] }
        return stops[below] + (stops[below + 1] - stops[below]) * (clamped - Double(below))
    }

    /// The whole centre line's length, from the top centre back to it.
    public var pathLength: Double { lines.last.map { $0.start + $0.length } ?? 0 }

    /// The head with its neck `distance` along the centre line, pointing at its nose on the line.
    public func head(atDistance distance: Double) -> Piece {
        let neck = point(at: distance)
        let nose = point(at: distance + Self.headLength * scale)
        let radians = atan2(nose.y - neck.y, nose.x - neck.x)
        return Piece(kind: .head, x: neck.x + sin(radians) * edgeOffset, y: neck.y - cos(radians) * edgeOffset,
                     rotation: radians * 180 / .pi, stretch: 1)
    }

    private func point(at distance: Double) -> (x: Double, y: Double) {
        let line = lines.last { $0.start <= distance } ?? lines[0]
        let along = distance - line.start
        let radians = line.degrees * .pi / 180
        if let radius = line.radius {
            let angle = radians + along / radius
            return (line.x + cos(angle) * radius, line.y + sin(angle) * radius)
        }
        return (line.x + cos(radians) * along, line.y + sin(radians) * along)
    }
}
