import Foundation
import TodoDomain

public struct SessionTokens: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresInSeconds: Int

    public init(accessToken: String, refreshToken: String, expiresInSeconds: Int = 900) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresInSeconds = expiresInSeconds
    }
}
