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
