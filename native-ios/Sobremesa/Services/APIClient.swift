//
//  APIClient.swift
//  Sobremesa
//
//  Il client delle API di Sobremesa (Vercel /api). La sessione vive nel
//  Keychain; ogni chiamata è async e tipizzata. Il client non decide nulla:
//  le regole stanno sul server, qui si trasporta.
//

import Foundation
import Security

// MARK: - DTO del server

struct AuthResponse: Codable {
    let token: String
    let user: RemoteUser
}

struct RemoteUser: Codable {
    let id: String
    let name: String
    let score: Int
}

struct RemotePendingInvite: Codable {
    let code: String
    let user_id: String
    let name: String
    let score: Int
}

struct RemoteCircle: Codable {
    let id: String
    let name: String
    let theme: String
    let category: String
    let is_open: Bool
    let animator: String
    let member_count: Int
    let last_activity: String?
    let joined_at: String?
}

struct RemoteRequest: Codable {
    let id: String
    let circle_id: String
    let user_id: String
    let name: String
    let score: Int
}

struct RemotePost: Codable {
    let id: String
    let author: String
    let circle_id: String?
    let category: String
    let text: String
    let created_at: String
    let author_name: String
    let author_score: Int
    let nutre_count: Int
    let nutrito_da_me: Bool
}

struct RemoteComment: Codable {
    let id: String
    let post_id: String
    let text: String
    let created_at: String
    let author_id: String
    let author_name: String
}

struct SyncPayload: Codable {
    let me: RemoteUser
    let friends: [RemoteUser]
    let pendingInvites: [RemotePendingInvite]
    let myCircles: [RemoteCircle]
    let catalog: [RemoteCircle]
    let requests: [RemoteRequest]
    let posts: [RemotePost]
    let comments: [RemoteComment]
}

struct InviteCodeResponse: Codable { let code: String }
struct InviteAcceptResponse: Codable {
    let seated: Bool?
    let pending: Bool?
}

enum APIError: Error {
    case notAuthenticated
    case http(Int, String)
}

// MARK: - Client

struct APIClient {

    static let baseURL = URL(string: "https://sobremesa-psi.vercel.app/api")!

    // MARK: Endpoints

    func authApple(identityToken: String, name: String?) async throws -> AuthResponse {
        try await send("auth/apple", method: "POST",
                       body: ["identityToken": identityToken, "name": name ?? ""],
                       authenticated: false)
    }

    func sync(catalogQuery: String = "") async throws -> SyncPayload {
        var path = "sync"
        if !catalogQuery.isEmpty {
            let encoded = catalogQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            path += "?q=\(encoded)"
        }
        return try await send(path)
    }

    func updateName(_ name: String) async throws {
        let _: OKResponse = try await send("me", method: "PATCH", body: ["name": name])
    }

    /// Cancella l'account sul server (GDPR / Apple 5.1.1(v)). Il token viene
    /// passato esplicitamente: chi chiama può aver già svuotato il Keychain.
    func deleteAccount(token: String) async throws {
        var request = URLRequest(url: URL(string: "\(Self.baseURL.absoluteString)/me")!)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await URLSession.shared.data(for: request)
    }

    func createInvite() async throws -> String {
        let response: InviteCodeResponse = try await send("invites", method: "POST", body: [String: String]())
        return response.code
    }

    func redeemInvite(code: String) async throws -> InviteAcceptResponse {
        try await send("invites?accept=1", method: "POST", body: ["code": code])
    }

    func removeFriend(serverID: String) async throws {
        let _: OKResponse = try await send("friends/remove", method: "POST", body: ["friendId": serverID])
    }

    func createCircle(name: String, theme: String, category: String, isOpen: Bool) async throws {
        struct Body: Encodable { let name, theme, category: String; let isOpen: Bool }
        let _: IDResponse = try await send("circles", method: "POST",
                                           body: Body(name: name, theme: theme, category: category, isOpen: isOpen))
    }

    func circleAction(_ action: String, circleID: String) async throws {
        let _: OKResponse = try await send("circles/membership", method: "POST",
                                           body: ["circleId": circleID, "action": action])
    }

    func decideRequest(id: String, accept: Bool) async throws {
        struct Body: Encodable { let requestId: String; let accept: Bool }
        let _: OKResponse = try await send("requests/decide", method: "POST",
                                           body: Body(requestId: id, accept: accept))
    }

    func publish(text: String, category: String, circleID: String?) async throws {
        struct Body: Encodable { let text, category: String; let circleId: String? }
        let _: IDResponse = try await send("posts", method: "POST",
                                           body: Body(text: text, category: category, circleId: circleID))
    }

    func react(postID: String, action: String, text: String? = nil) async throws {
        struct Body: Encodable { let postId, action: String; let text: String? }
        let _: FlexResponse = try await send("posts/react", method: "POST",
                                             body: Body(postId: postID, action: action, text: text))
    }

    // MARK: Trasporto

    private struct OKResponse: Codable { let ok: Bool?; let closed: Bool?; let left: Bool?; let joined: Bool?; let requested: Bool?; let accepted: Bool? }
    private struct IDResponse: Codable { let id: String }
    private struct FlexResponse: Codable { let nutrito: Bool?; let id: String? }

    private func send<T: Decodable>(_ path: String,
                                    method: String = "GET",
                                    body: (any Encodable)? = nil,
                                    authenticated: Bool = true) async throws -> T {
        // Nota bene: appending(path:) percent-encoderebbe il "?" della query
        // (invites?accept=1, sync?q=...): l'URL si compone come stringa.
        guard let url = URL(string: "\(Self.baseURL.absoluteString)/\(path)") else {
            throw APIError.http(0, "URL non valido")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        if authenticated {
            guard let token = SessionStore.token else { throw APIError.notAuthenticated }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw APIError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Sessione nel Keychain (mai in UserDefaults: è una credenziale)

enum SessionStore {

    private static let service = "app.sobremesa.session"

    static var token: String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ token: String) {
        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = Data(token.utf8)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "session"]
    }
}

// MARK: - Date ISO del server

extension String {
    /// Le date del server sono ISO8601 (con frazioni di secondo).
    var serverDate: Date {
        let withFractions = ISO8601DateFormatter()
        withFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractions.date(from: self) { return date }
        let plain = ISO8601DateFormatter()
        return plain.date(from: self) ?? .now
    }
}
