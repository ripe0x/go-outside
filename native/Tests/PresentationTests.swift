import Foundation

func runPresentationTests() {
    precondition(RatioState.make(computer: 4 * 3600, daylight: 2 * 3600) == .share(2.0 / 3))
    precondition(RatioState.make(computer: 0, daylight: 3600) == .share(0))
    precondition(RatioState.make(computer: 3600, daylight: 0) == .share(1))
    precondition(RatioState.make(computer: 0, daylight: 0) == .empty)
    precondition(RatioState.make(computer: 0, daylight: nil) == .unknown)
    precondition(RatioState.make(computer: -.infinity, daylight: 0) == .unknown)
    precondition(RatioState.make(computer: .greatestFiniteMagnitude, daylight: .greatestFiniteMagnitude) == .unknown)
    precondition(OutsideFormat.duration(59) == "0m")
    precondition(OutsideFormat.duration(0.1, remaining: true) == "1m")
    precondition(OutsideFormat.duration(0, remaining: true) == "0m")
    precondition(OutsideFormat.duration(4 * 3600 + 12 * 60 + 59) == "4h12")
    precondition(OutsideFormat.duration(59 * 60 + 1, remaining: true) == "1h00")
    precondition(OutsideFormat.duration(.nan) == "—")
    precondition(OutsideFormat.duration(.greatestFiniteMagnitude) == "168h00")
    precondition(OutsideFormat.accessibleDuration(3660) == "1 hour 1 minute")
    print("PASS: ratio shares, unknown/zero states, safe duration formatting and rounding")
}
