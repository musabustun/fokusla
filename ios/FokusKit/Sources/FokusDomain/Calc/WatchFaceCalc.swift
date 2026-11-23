import Foundation

/// Saat kadranlarının (dijital, analog, halka) saf hesapları. Değerler her zaman zaman damgasından
/// (`FocusActivityCalc.State`) ve verilen `now`'dan türer; sayaç değeri saklanmaz.
public enum WatchFaceCalc {
    /// Kadran türü. Raw value'lar `@AppStorage("fokus.watch.face")` değeridir (kalıcı; değiştirme).
    public enum Face: String, CaseIterable, Sendable, Codable {
        case digital, analog, ring
    }

    /// Kayıtlı değer → kadran; bilinmeyen/boş değer dijitale düşer.
    public static func face(from raw: String?) -> Face {
        raw.flatMap(Face.init(rawValue:)) ?? .digital
    }

    /// Ana sayacın geçen süresi (saniye): odakta son devamdan, molada mola başlangıcından beri.
    public static func elapsed(_ state: FocusActivityCalc.State, now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(state.timerStart))
    }

    /// Analog kadranın dakika ibresi (derece, saat yönünde, 12 = 0°): 60 dakikada bir tur.
    public static func minuteHandDegrees(elapsed: TimeInterval) -> Double {
        let seconds = max(0, elapsed).truncatingRemainder(dividingBy: 3600)
        return seconds / 3600 * 360
    }

    /// Analog kadranın saniye ibresi: 60 saniyede bir tur.
    public static func secondHandDegrees(elapsed: TimeInterval) -> Double {
        let seconds = max(0, elapsed).truncatingRemainder(dividingBy: 60)
        return seconds / 60 * 360
    }

    /// Tamamlanan tam saat sayısı (analog kadranda "+1 sa" rozeti).
    public static func completedHours(elapsed: TimeInterval) -> Int {
        Int(max(0, elapsed) / 3600)
    }

    /// Bugünkü toplam odak (saniye); hedef kapalıysa (`dayFocusStart == nil`) `nil`. Molada sayaç durur.
    public static func dayFocusSeconds(_ state: FocusActivityCalc.State, now: Date) -> TimeInterval? {
        guard let start = state.dayFocusStart else { return nil }
        let end = state.phase == .focus ? now : state.timerStart
        return max(0, end.timeIntervalSince(start))
    }

    /// Halka kadranın doluluğu (0...1). Hedef varsa bugünkü toplam / hedef; yoksa geçerli saatin
    /// dolan kısmı (dakika ibresiyle aynı tur).
    public static func ringProgress(_ state: FocusActivityCalc.State, now: Date) -> Double {
        if let goal = state.goalMinutes, goal > 0, let day = dayFocusSeconds(state, now: now) {
            return min(1, day / Double(goal * 60))
        }
        return minuteHandDegrees(elapsed: elapsed(state, now: now)) / 360
    }
}
