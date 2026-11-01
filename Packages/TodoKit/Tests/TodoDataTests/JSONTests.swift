import Foundation
import Testing
@testable import TodoData

struct JSONTests {
    @Test(arguments: ["2026-10-29T13:00:00Z", "2026-10-29T13:00:00.123Z", "2026-10-29T13:00:00.123456Z", "2026-10-29T13:00:00.123456789Z"])
    func decodesKotlinInstants(_ value: String) throws {
        let data = Data("{\"date\":\"\(value)\"}".utf8)
        struct Envelope: Decodable { let date: Date }
        let result = try APIJSON.decoder().decode(Envelope.self, from: data)
        #expect(abs(result.date.timeIntervalSince(instant("2026-10-29T13:00:00Z"))) < 1)
    }
    @Test func invalidInstantIsRejected() {
        struct Envelope: Decodable { let date: Date }
        #expect(throws: (any Error).self) { try APIJSON.decoder().decode(Envelope.self, from: Data(#"{"date":"tomorrow"}"#.utf8)) }
    }
}
