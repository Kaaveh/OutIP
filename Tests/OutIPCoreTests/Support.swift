import Foundation

/// Invented replies, the keys and their order as served (core-rules R10–R12).
enum Fixture {
    static let trace = """
        fl=29f123
        h=ipv4.icanhazip.com
        ip=203.0.113.7
        ts=1795219200.123
        visit_scheme=https
        uag=ExampleApp/1.0
        colo=ARN
        sliver=none
        http=http/2
        loc=SE
        tls=TLSv1.3
        sni=plaintext
        warp=off
        gateway=off
        rbi=off
        kex=X25519

        """

    static let identJSON = #"{"ip":"203.0.113.7","aso":"Example Hosting AB","asn":64500,"type":"hosting","continent":"EU","cc":"SE","country":"Sweden","city":"Stockholm","postal":"111 20","latitude":59.33,"longitude":18.07,"tz":"Europe/Stockholm","weather":"SEXX0001"}"#

    static let plainAddress = "203.0.113.7\n"
}

/// A Gregorian calendar in Asia/Kolkata: the half-hour offset catches UTC assumptions.
let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    return calendar
}()

/// That calendar's date on 2026-11-21 at the given time.
func at(_ hour: Int, _ minute: Int, _ second: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: hour, minute: minute, second: second))!
}
