//
//  APIClient.swift
//  Sobremesa
//
//  Il client delle API di Sobremesa (Vercel /api), modello v2 "solo tavoli".
//  La sessione vive nel Keychain; ogni chiamata è async e tipizzata.
//  Il client non decide nulla: le regole stanno sul server, qui si trasporta.
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

struct RemoteTable: Codable {
    let id: String
    let name: String
    let theme: String
    let category: String
    let is_open: Bool
    let animator: String
    let member_count: Int
    let last_activity: String?
    let joined_at: String?
    let penalty_applied: Bool?
}

struct RemoteSeat: Codable {
    let circle_id: String
    let user_id: String
    let name: String
    let score: Int
    /// Ordine d'arrivo al tavolo (v3: i posti si occupano in ordine d'arrivo).
    let joined_at: String?
}

struct RemoteRequest: Codable {
    let id: String
    let circle_id: String
    let user_id: String
    let name: String
    let score: Int
}

struct RemoteMessage: Codable {
    let id: String
    let author: String
    let circle_id: String
    let text: String
    let created_at: String
    let author_name: String
    let author_score: Int
    let nutre_count: Int
    let nutrito_da_me: Bool
}

/// Una persona che ho bloccato (Tu → Persone bloccate).
struct RemoteBlocked: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct SyncPayload: Codable {
    let me: RemoteUser
    let myTables: [RemoteTable]
    let seats: [RemoteSeat]
    let catalog: [RemoteTable]
    let requests: [RemoteRequest]
    let messages: [RemoteMessage]
    /// v3 (sicurezza): interventi da togliere anche dalla memoria locale
    /// (nascosti dalla moderazione, segnalati da me, di persone bloccate).
    /// Opzionali: un server più vecchio non li manda.
    let hidden: [String]?
    let blocked: [RemoteBlocked]?
}

/// I motivi di una segnalazione (gli stessi del server).
enum ReportReason: String, CaseIterable, Identifiable {
    case offensivo, molesto, spam, altro
    var id: String { rawValue }
    var labelKey: String { "segnala.motivo.\(rawValue)" }
}

struct InviteCodeResponse: Codable { let code: String }

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
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw APIError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
    }

    /// Un invito nasce sempre A un tavolo.
    func createInvite(tableID: String) async throws -> String {
        let response: InviteCodeResponse = try await send("invites", method: "POST",
                                                          body: ["tableId": tableID])
        return response.code
    }

    /// Riscatta un codice: restituisce l'id del tavolo a cui ci si è seduti.
    func redeemInvite(code: String) async throws -> String? {
        struct Seated: Codable { let seated: Bool?; let tableId: String? }
        let response: Seated = try await send("invites?accept=1", method: "POST", body: ["code": code])
        return response.tableId
    }

    func createTable(name: String, theme: String, category: String, isOpen: Bool) async throws {
        struct Body: Encodable { let name, theme, category: String; let isOpen: Bool }
        let _: IDResponse = try await send("circles", method: "POST",
                                           body: Body(name: name, theme: theme, category: category, isOpen: isOpen))
    }

    func tableAction(_ action: String, tableID: String) async throws {
        let _: OKResponse = try await send("circles/membership", method: "POST",
                                           body: ["circleId": tableID, "action": action])
    }

    func decideRequest(id: String, accept: Bool) async throws {
        struct Body: Encodable { let requestId: String; let accept: Bool }
        let _: OKResponse = try await send("requests/decide", method: "POST",
                                           body: Body(requestId: id, accept: accept))
    }

    func sendMessage(_ text: String, tableID: String) async throws {
        let _: IDResponse = try await send("posts", method: "POST",
                                           body: ["tableId": tableID, "text": text])
    }

    func toggleNutre(messageID: String) async throws {
        let _: NutreResponse = try await send("posts/react", method: "POST",
                                              body: ["postId": messageID, "action": "nutre"])
    }

    // MARK: Sicurezza (Apple Guideline 1.2)

    /// Segnala un intervento: sparisce subito per me, per tutti se lo
    /// segnalano più persone, e finisce nella coda di moderazione.
    func report(messageID: String, reason: ReportReason) async throws {
        let _: OKResponse = try await send("safety", method: "POST",
                                           body: ["action": "report", "postId": messageID,
                                                  "reason": reason.rawValue])
    }

    /// Blocca (o sblocca) una persona.
    func setBlocked(_ blocked: Bool, userID: String) async throws {
        let _: OKResponse = try await send("safety", method: "POST",
                                           body: ["action": blocked ? "block" : "unblock",
                                                  "userId": userID])
    }

    // MARK: Trasporto

    private struct OKResponse: Codable { let ok: Bool?; let closed: Bool?; let left: Bool?; let joined: Bool?; let requested: Bool?; let accepted: Bool?; let seated: Bool? }
    private struct IDResponse: Codable { let id: String }
    private struct NutreResponse: Codable { let nutrito: Bool }

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

// MARK: - I link pubblici di Sobremesa

/// Le pagine del sito vetrina che l'app apre (Apple 1.2 e 5.1.1: privacy,
/// condizioni d'uso con tolleranza zero, contatto per le segnalazioni).
enum SobremesaLinks {
    static let site = URL(string: "https://sobremesa-psi.vercel.app")!
    static let privacy = URL(string: "https://sobremesa-psi.vercel.app/privacy")!
    static let terms = URL(string: "https://sobremesa-psi.vercel.app/termini")!
    static let support = URL(string: "mailto:grecolatinovivo@gmail.com?subject=Sobremesa%20-%20assistenza%20e%20segnalazioni")!
}
