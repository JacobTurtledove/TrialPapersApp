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
    inkAnnotation(annotation, intersectsSegmentFrom: point, to: point, radius: radius)
}

func inkAnnotation(
    _ annotation: PDFAnnotation,
    intersectsSegmentFrom startPoint: NSPoint,
    to endPoint: NSPoint,
    radius: CGFloat
) -> Bool {
    let effectiveRadius = max(radius, CGFloat(annotation.border?.lineWidth ?? 0) + 4)
    let annotationBounds = annotation.bounds.insetBy(dx: -effectiveRadius, dy: -effectiveRadius)
    let segmentBounds = NSRect.containing(startPoint, endPoint)
        .insetBy(dx: -effectiveRadius, dy: -effectiveRadius)
    guard annotationBounds.intersects(segmentBounds) else {
        return false
    }

    guard let paths = annotation.paths, !paths.isEmpty else {
        return true
    }

    for path in paths {
        let pathPoints = approximatePoints(from: path)
        if pathPointsAreNear(
            pathPoints,
            segmentStart: startPoint,
            segmentEnd: endPoint,
            radius: effectiveRadius
        ) {
            return true
        }

        let pagePoints = pathPoints.map {
            NSPoint(
                x: $0.x + annotation.bounds.minX,
                y: $0.y + annotation.bounds.minY
            )
        }
        if pathPointsAreNear(
            pagePoints,
            segmentStart: startPoint,
            segmentEnd: endPoint,
            radius: effectiveRadius
        ) {
            return true
        }
    }

    return false
}

private func pathPointsAreNear(
    _ pathPoints: [NSPoint],
    segmentStart: NSPoint,
    segmentEnd: NSPoint,
    radius: CGFloat
) -> Bool {
    if pathPoints.count == 1, let pathPoint = pathPoints.first {
        return distanceFromPointToSegment(point: pathPoint, start: segmentStart, end: segmentEnd) <= radius
    }

    guard pathPoints.count > 1 else { return false }

    for index in 0..<(pathPoints.count - 1) {
        if distanceFromSegmentToSegment(
            start: pathPoints[index],
            end: pathPoints[index + 1],
            otherStart: segmentStart,
            otherEnd: segmentEnd
        ) <= radius {
            return true
        }
    }

    return false
}

private extension NSRect {
    static func containing(_ startPoint: NSPoint, _ endPoint: NSPoint) -> NSRect {
        NSRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
    }
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

private func distanceFromSegmentToSegment(
    start a: NSPoint,
    end b: NSPoint,
    otherStart c: NSPoint,
    otherEnd d: NSPoint
) -> CGFloat {
    if segmentsIntersect(start: a, end: b, otherStart: c, otherEnd: d) {
        return 0
    }

    return min(
        distanceFromPointToSegment(point: a, start: c, end: d),
        distanceFromPointToSegment(point: b, start: c, end: d),
        distanceFromPointToSegment(point: c, start: a, end: b),
        distanceFromPointToSegment(point: d, start: a, end: b)
    )
}

private func segmentsIntersect(start a: NSPoint, end b: NSPoint, otherStart c: NSPoint, otherEnd d: NSPoint) -> Bool {
    let firstOrientation = orientation(a, b, c)
    let secondOrientation = orientation(a, b, d)
    let thirdOrientation = orientation(c, d, a)
    let fourthOrientation = orientation(c, d, b)

    if isApproximatelyZero(firstOrientation), point(c, isOnSegmentFrom: a, to: b) {
        return true
    }
    if isApproximatelyZero(secondOrientation), point(d, isOnSegmentFrom: a, to: b) {
        return true
    }
    if isApproximatelyZero(thirdOrientation), point(a, isOnSegmentFrom: c, to: d) {
        return true
    }
    if isApproximatelyZero(fourthOrientation), point(b, isOnSegmentFrom: c, to: d) {
        return true
    }

    return (firstOrientation > 0) != (secondOrientation > 0) &&
        (thirdOrientation > 0) != (fourthOrientation > 0)
}

private func orientation(_ a: NSPoint, _ b: NSPoint, _ c: NSPoint) -> CGFloat {
    (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
}

private func point(_ point: NSPoint, isOnSegmentFrom start: NSPoint, to end: NSPoint) -> Bool {
    let epsilon: CGFloat = 0.0001
    return point.x >= min(start.x, end.x) - epsilon &&
        point.x <= max(start.x, end.x) + epsilon &&
        point.y >= min(start.y, end.y) - epsilon &&
        point.y <= max(start.y, end.y) + epsilon
}

private func isApproximatelyZero(_ value: CGFloat) -> Bool {
    abs(value) <= 0.0001
}
