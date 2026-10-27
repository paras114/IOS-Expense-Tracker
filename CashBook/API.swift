import Foundation

/// Talks to the Google Apps Script web app (Code.gs).
struct API {
    let endpoint: URL
    let secret: String

    enum APIError: LocalizedError {
        case rejected(String)      // server refused this one entry (bad data) – safe to skip
        case server(String)        // anything else – keep the entry and retry later
        case unauthorized
        case notJSON
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .rejected(let m): return m
            case .server(let m): return m
            case .unauthorized: return "Secret key doesn't match SECRET in your Apps Script."
            case .notJSON: return "The web app didn't return data. Check the URL ends in /exec and the deployment access is “Anyone”."
            case .http(let c): return "Server error (HTTP \(c))."
            }
        }
    }

    private static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 30
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: c)
    }()

    private static let isoOut: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: Writing

    func send(_ op: PendingOp) async throws {
        var body: [String: Any] = ["key": secret]
        switch op {
        case .add(let e):
            body.merge(fields(e)) { $1 }
            body["action"] = "add"
        case .update(let e):
            body.merge(fields(e)) { $1 }
            body["action"] = "update"
        case .delete(let id):
            body["action"] = "delete"
            body["id"] = id
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await call(req)
    }

    private func fields(_ e: Expense) -> [String: Any] {
        var f: [String: Any] = [
            "id": e.id,
            "amount": e.amount,
            "category": e.category,
            "remarks": e.remarks,
            "timestamp": Self.isoOut.string(from: e.date)
        ]
        if let lat = e.lat, let lng = e.lng {
            f["lat"] = lat
            f["lng"] = lng
        }
        if !e.address.isEmpty { f["address"] = e.address }
        return f
    }

    // MARK: Reading

    func fetchAll() async throws -> [Expense] {
        guard var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw APIError.notJSON
        }
        comps.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "key", value: secret)
        ]
        guard let url = comps.url else { throw APIError.notJSON }
        let obj = try await call(URLRequest(url: url))
        let rows = obj["rows"] as? [[String: Any]] ?? []
        return rows.compactMap(Self.parse)
    }

    private static func parse(_ r: [String: Any]) -> Expense? {
        guard let id = r["id"] as? String, !id.isEmpty,
              let ts = r["ts"] as? String,
              let date = isoFrac.date(from: ts) ?? isoOut.date(from: ts) else { return nil }
        return Expense(
            id: id,
            date: date,
            amount: (r["amount"] as? NSNumber)?.doubleValue ?? 0,
            category: (r["category"] as? String) ?? "Other",
            remarks: (r["remarks"] as? String) ?? "",
            address: (r["address"] as? String) ?? "",
            lat: (r["lat"] as? NSNumber)?.doubleValue,
            lng: (r["lng"] as? NSNumber)?.doubleValue
        )
    }

    // MARK: Plumbing

    private func call(_ req: URLRequest) async throws -> [String: Any] {
        let (data, resp) = try await Self.session.data(for: req)
        if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) {
            throw APIError.http(h.statusCode)
        }
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw APIError.notJSON
        }
        if (obj["ok"] as? Bool) == true { return obj }
        let message = (obj["error"] as? String) ?? "Unknown error"
        if message == "Unauthorized" || message.hasPrefix("Invalid or missing key") {
            throw APIError.unauthorized
        }
        if message.hasPrefix("Invalid amount") { throw APIError.rejected(message) }
        throw APIError.server(message)
    }
}
