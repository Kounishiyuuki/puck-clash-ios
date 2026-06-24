import Foundation

struct Vector2: Equatable {
    let x: Double
    let y: Double

    static let zero = Vector2(x: 0, y: 0)

    var length: Double {
        (x * x + y * y).squareRoot()
    }

    var normalized: Vector2 {
        let currentLength = length
        guard currentLength > 0 else {
            return .zero
        }

        return self * (1 / currentLength)
    }

    static func + (lhs: Vector2, rhs: Vector2) -> Vector2 {
        Vector2(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: Vector2, rhs: Vector2) -> Vector2 {
        Vector2(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: Vector2, rhs: Double) -> Vector2 {
        Vector2(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func * (lhs: Double, rhs: Vector2) -> Vector2 {
        rhs * lhs
    }
}
