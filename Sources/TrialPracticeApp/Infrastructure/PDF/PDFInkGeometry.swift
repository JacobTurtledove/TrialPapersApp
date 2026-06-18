import AppKit
import PDFKit

func smoothedPath(from points: [NSPoint]) -> NSBezierPath {
    let path = NSBezierPath()
    guard let first = points.first else { return path }
    path.move(to: first)

    guard points.count > 2 else {
        for point in points.dropFirst() {
            path.line(to: point)
        }
        return path
    }

    for index in 1..<(points.count - 1) {
        let current = points[index]
        let next = points[index + 1]
        let mid = NSPoint(
            x: (current.x + next.x) / 2,
            y: (current.y + next.y) / 2
        )
        path.curve(to: mid, controlPoint1: current, controlPoint2: current)
    }

    if let last = points.last {
        path.line(to: last)
    }
    return path
}

func decimatedPoints(_ points: [NSPoint], minimumDistance: CGFloat) -> [NSPoint] {
    guard points.count > 2 else { return points }

    var result: [NSPoint] = []
    var previous: NSPoint?

    for point in points {
        if let previous {
            let distance = hypot(point.x - previous.x, point.y - previous.y)
            if distance < minimumDistance { continue }
        }
        result.append(point)
        previous = point
    }

    if result.last != points.last, let last = points.last {
        result.append(last)
    }
    return result
}

func inkAnnotation(_ annotation: PDFAnnotation, isNear point: NSPoint, radius: CGFloat) -> Bool {
    let effectiveRadius = max(radius, CGFloat(annotation.border?.lineWidth ?? 0) + 4)
    guard annotation.bounds.insetBy(dx: -effectiveRadius, dy: -effectiveRadius).contains(point) else {
        return false
    }

    guard let paths = annotation.paths, !paths.isEmpty else {
        return true
    }

    for path in paths {
        let pathPoints = approximatePoints(from: path)
        if pathPointsAreNear(pathPoints, point: point, radius: effectiveRadius) {
            return true
        }

        let pagePoints = pathPoints.map {
            NSPoint(
                x: $0.x + annotation.bounds.minX,
                y: $0.y + annotation.bounds.minY
            )
        }
        if pathPointsAreNear(pagePoints, point: point, radius: effectiveRadius) {
            return true
        }
    }

    return false
}

private func pathPointsAreNear(_ pathPoints: [NSPoint], point: NSPoint, radius: CGFloat) -> Bool {
    if pathPoints.count == 1, let pathPoint = pathPoints.first {
        return hypot(pathPoint.x - point.x, pathPoint.y - point.y) <= radius
    }

    guard pathPoints.count > 1 else { return false }

    for index in 0..<(pathPoints.count - 1) {
        if distanceFromPointToSegment(
            point: point,
            start: pathPoints[index],
            end: pathPoints[index + 1]
        ) <= radius {
            return true
        }
    }

    return false
}

private func approximatePoints(from path: NSBezierPath) -> [NSPoint] {
    var result: [NSPoint] = []
    var current = NSPoint.zero
    var points = [NSPoint](repeating: .zero, count: 3)

    for index in 0..<path.elementCount {
        let element = path.element(at: index, associatedPoints: &points)
        switch element {
        case .moveTo:
            current = points[0]
            result.append(current)
        case .lineTo:
            current = points[0]
            result.append(current)
        case .curveTo, .cubicCurveTo:
            let start = current
            let control1 = points[0]
            let control2 = points[1]
            let end = points[2]
            for step in 1...8 {
                result.append(
                    cubicBezierPoint(
                        start: start,
                        control1: control1,
                        control2: control2,
                        end: end,
                        t: CGFloat(step) / 8
                    )
                )
            }
            current = end
        case .quadraticCurveTo:
            let start = current
            let control = points[0]
            let end = points[1]
            for step in 1...8 {
                let t = CGFloat(step) / 8
                let oneMinusT = 1 - t
                result.append(
                    NSPoint(
                        x: pow(oneMinusT, 2) * start.x +
                            2 * oneMinusT * t * control.x +
                            pow(t, 2) * end.x,
                        y: pow(oneMinusT, 2) * start.y +
                            2 * oneMinusT * t * control.y +
                            pow(t, 2) * end.y
                    )
                )
            }
            current = end
        case .closePath:
            break
        @unknown default:
            break
        }
    }

    return result
}

private func cubicBezierPoint(
    start: NSPoint,
    control1: NSPoint,
    control2: NSPoint,
    end: NSPoint,
    t: CGFloat
) -> NSPoint {
    let oneMinusT = 1 - t
    let x = pow(oneMinusT, 3) * start.x +
        3 * pow(oneMinusT, 2) * t * control1.x +
        3 * oneMinusT * pow(t, 2) * control2.x +
        pow(t, 3) * end.x
    let y = pow(oneMinusT, 3) * start.y +
        3 * pow(oneMinusT, 2) * t * control1.y +
        3 * oneMinusT * pow(t, 2) * control2.y +
        pow(t, 3) * end.y
    return NSPoint(x: x, y: y)
}

private func distanceFromPointToSegment(point p: NSPoint, start a: NSPoint, end b: NSPoint) -> CGFloat {
    let dx = b.x - a.x
    let dy = b.y - a.y

    if dx == 0 && dy == 0 {
        return hypot(p.x - a.x, p.y - a.y)
    }

    let t = max(
        0,
        min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy))
    )
    let projection = NSPoint(x: a.x + t * dx, y: a.y + t * dy)
    return hypot(p.x - projection.x, p.y - projection.y)
}
