import SwiftUI

/// İnce çizgili analog saat (StandBy ikili görünümü). Kare alana sığar; hareket azaltmada
/// çağıran `showsSecondHand: false` verir.
public struct StandByAnalogClock: View {
    private let date: Date
    private let showsSecondHand: Bool

    public init(date: Date, showsSecondHand: Bool = true) {
        self.date = date
        self.showsSecondHand = showsSecondHand
    }

    /// Kol açıları (derece, 12'den saat yönünde). Saf; testlerde doğrulanabilir.
    public struct Angles: Equatable, Sendable {
        public let hour: Double
        public let minute: Double
        public let second: Double
    }

    nonisolated public static func angles(for date: Date, calendar: Calendar = .current) -> Angles {
        let parts = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let second = Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1_000_000_000
        let minute = Double(parts.minute ?? 0) + second / 60
        let hour = Double((parts.hour ?? 0) % 12) + minute / 60
        return Angles(hour: hour * 30, minute: minute * 6, second: second * 6)
    }

    public var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            Self.drawTicks(&context, center: center, radius: side / 2)
            let angles = Self.angles(for: date)
            let radius = side / 2
            Self.drawHand(&context, center: center, degrees: angles.hour, length: radius * 0.5,
                width: radius * 0.045, shading: .style(.fkLabel))
            Self.drawHand(&context, center: center, degrees: angles.minute, length: radius * 0.76,
                width: radius * 0.03, shading: .style(.fkLabel))
            if showsSecondHand {
                Self.drawHand(&context, center: center, degrees: angles.second, length: radius * 0.82,
                    width: radius * 0.012, shading: .style(.fkAccent))
            }
            let dot = radius * 0.035
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2)),
                with: showsSecondHand ? .style(.fkAccent) : .style(.fkLabel))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Saat")
        .accessibilityValue(date.formatted(.dateTime.hour().minute().locale(Locale(identifier: "tr_TR"))))
    }

    private static func drawTicks(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        for tick in 0..<60 {
            let isHour = tick % 5 == 0
            let length = radius * (isHour ? 0.09 : 0.045)
            let width = radius * (isHour ? 0.018 : 0.006)
            let direction = unitVector(degrees: Double(tick) * 6)
            var path = Path()
            path.move(to: point(center, direction, radius - length))
            path.addLine(to: point(center, direction, radius))
            context.stroke(
                path, with: .style(isHour ? .fkLabel : .fkSeparatorStrong),
                style: StrokeStyle(lineWidth: max(width, 0.5), lineCap: .butt))
        }
    }

    private static func drawHand(
        _ context: inout GraphicsContext, center: CGPoint, degrees: Double, length: CGFloat,
        width: CGFloat, shading: GraphicsContext.Shading
    ) {
        var path = Path()
        path.move(to: center)
        path.addLine(to: point(center, unitVector(degrees: degrees), length))
        context.stroke(path, with: shading, style: StrokeStyle(lineWidth: max(width, 1), lineCap: .round))
    }

    private static func unitVector(degrees: Double) -> CGVector {
        let radians = (degrees - 90) * .pi / 180
        return CGVector(dx: cos(radians), dy: sin(radians))
    }

    private static func point(_ center: CGPoint, _ direction: CGVector, _ distance: CGFloat) -> CGPoint {
        CGPoint(x: center.x + direction.dx * distance, y: center.y + direction.dy * distance)
    }
}
