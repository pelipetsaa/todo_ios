import Foundation
import TodoDomain

public struct HTTPResponse: Sendable {
    public let data: Data
    public let status: Int
    public init(data: Data = Data(), status: Int) { self.data = data; self.status = status }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 75 // Render cold starts can take a minute.
        configuration.timeoutIntervalForResource = 90
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        self.session = URLSession(configuration: configuration)
    }
    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw AppError.invalidResponse }
            return HTTPResponse(data: data, status: response.statusCode)
        } catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch let error as AppError { throw error }
        catch { throw AppError.network }
    }
}

public enum APIJSON {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.ISO8601Format(.init(includingFractionalSeconds: true)))
        }
        return encoder
    }

    // ISO8601DateFormatter is thread-safe; creating one per decoded date is the expensive part.
    nonisolated(unsafe) private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    nonisolated(unsafe) private static let wholeSecondsFormatter = ISO8601DateFormatter()

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            // Kotlin instants may have zero, three, six or nine fractional digits.
            if let date = fractionalFormatter.date(from: string) ?? wholeSecondsFormatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 instant")
        }
        return decoder
    }

    static func validate(_ response: HTTPResponse) throws {
        switch response.status {
        case 200..<300: return
        case 400: throw AppError.validation
        case 401: throw AppError.sessionExpired
        case 404: throw AppError.notFound
        case 409: throw AppError.emailTaken
        case 429: throw AppError.rateLimited
        default: throw AppError.server
        }
    }

    static func decode<T: Decodable>(_ response: HTTPResponse) throws -> T {
        do { return try decoder().decode(T.self, from: response.data) }
        catch { throw AppError.invalidResponse }
    }
}
