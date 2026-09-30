import Foundation
@testable import RedactoConsentSDK

struct PCStubResponse {
    let status: Int
    let body: Data
    let error: URLError?

    static func json(_ status: Int, _ object: Any = [String: Any]()) -> PCStubResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
        return PCStubResponse(status: status, body: data, error: nil)
    }

    static func raw(_ status: Int, _ text: String) -> PCStubResponse {
        PCStubResponse(status: status, body: Data(text.utf8), error: nil)
    }

    static func failure(_ code: URLError.Code) -> PCStubResponse {
        PCStubResponse(status: 0, body: Data(), error: URLError(code))
    }
}

struct PCCapturedRequest {
    let url: URL
    let method: String
    let headers: [String: String]
    let body: Data

    var path: String { url.path }

    var json: [String: Any] {
        (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
    }

    var firstPurpose: [String: Any] {
        (json["purposes"] as? [[String: Any]])?.first ?? [:]
    }

    func query(_ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    var urlWithoutQuery: String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        return components?.string ?? url.absoluteString
    }
}

final class PCMockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var queue: [PCStubResponse] = []
    private static var routes: [(suffix: String, response: PCStubResponse)] = []
    private static var captured: [PCCapturedRequest] = []
    private static var heldSuffix: String?
    private static var heldGate: DispatchSemaphore?

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        queue = []
        routes = []
        captured = []
        heldSuffix = nil
        heldGate = nil
    }

    static func hold(pathSuffix: String) {
        lock.lock()
        defer { lock.unlock() }
        heldSuffix = pathSuffix
        heldGate = DispatchSemaphore(value: 0)
    }

    static func releaseHeld() {
        lock.lock()
        let gate = heldGate
        heldSuffix = nil
        heldGate = nil
        lock.unlock()
        gate?.signal()
    }

    static func enqueue(_ responses: PCStubResponse...) {
        lock.lock()
        defer { lock.unlock() }
        queue.append(contentsOf: responses)
    }

    static func route(pathSuffix: String, _ response: PCStubResponse) {
        lock.lock()
        defer { lock.unlock() }
        routes.append((suffix: pathSuffix, response: response))
    }

    static var requests: [PCCapturedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return captured
    }

    static func requests(pathSuffix: String) -> [PCCapturedRequest] {
        requests.filter { $0.path.hasSuffix(pathSuffix) }
    }

    private static func record(_ request: PCCapturedRequest) -> (response: PCStubResponse, gate: DispatchSemaphore?) {
        lock.lock()
        defer { lock.unlock() }
        captured.append(request)
        let gate = heldSuffix.map { request.path.hasSuffix($0) } == true ? heldGate : nil
        if let match = routes.first(where: { request.path.hasSuffix($0.suffix) }) {
            return (match.response, gate)
        }
        if !queue.isEmpty {
            return (queue.removeFirst(), gate)
        }
        return (.json(200), gate)
    }

    private static func readBody(_ request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let snapshot = PCCapturedRequest(
            url: url,
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields ?? [:],
            body: Self.readBody(request)
        )
        let recorded = Self.record(snapshot)
        if let gate = recorded.gate {
            DispatchQueue.global().async {
                gate.wait()
                self.deliver(recorded.response, url: url)
            }
            return
        }
        deliver(recorded.response, url: url)
    }

    private func deliver(_ stub: PCStubResponse, url: URL) {
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

enum PCFixtures {
    static let base = "https://api.example.test/consent"
    static let ledger = "https://ledger.example.test/consent-ledger"
    static let org = "org-1"
    static let ws = "ws-1"
    static let notice = "33333333-3333-3333-3333-333333333333"
    static let noticeB = "33333333-3333-3333-3333-3333333333bb"
    static let purpose = "44444444-4444-4444-4444-444444444444"
    static let productA = "55555555-5555-5555-5555-555555555555"
    static let productB = "66666666-6666-6666-6666-666666666666"
    static let receipt = "77777777-7777-7777-7777-777777777777"
    static let nominator = "88888888-8888-8888-8888-888888888888"
    static let contact = "user@example.test"

    static var consentPrefix: String { "\(base)/organisations/\(org)/workspaces/\(ws)/dsar/privacy-center" }
    static var ledgerPrefix: String { "\(ledger)/public/organisations/\(org)/workspaces/\(ws)" }

    static func jwt(_ payload: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
        let segment = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "eyJhbGciOiJub25lIn0.\(segment).sig"
    }

    static var liveToken: String {
        jwt(["organisation_uuid": org, "workspace_uuid": ws, "email": contact])
    }

    static var refreshedToken: String {
        jwt(["organisation_uuid": org, "workspace_uuid": ws, "email": contact, "iat": 2])
    }

    static let sandbox = SandboxConfig(
        token: "sandbox-token",
        ucic: "UCIC-9",
        email: "tester@example.test",
        mobile: "+919999999999",
        organisationUuid: org,
        workspaceUuid: ws
    )

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PCMockURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func api(ledger: String?, sandbox: SandboxConfig? = nil) -> PrivacyCenterAPI {
        let mockSession = session()
        let tokens = TokenStore(
            baseUrl: base,
            accessToken: sandbox == nil ? liveToken : "",
            refreshToken: "refresh-1",
            onError: { _ in false },
            sandbox: sandbox,
            urlSession: mockSession
        )
        return PrivacyCenterAPI(baseUrl: base, ledgerBaseUrl: ledger, tokenStore: tokens, urlSession: mockSession)
    }

    static func element(_ uuid: String, selected: Bool) -> ConsentDataElement {
        ConsentDataElement(uuid: uuid, name: uuid, enabled: true, required: false, selected: selected)
    }

    static func purposeJSON(notice: String, status: String = "ACTIVE") -> [String: Any] {
        [
            "purpose_uuid": purpose,
            "name": "Marketing",
            "description": "Offers",
            "status": status,
            "given_date": "2026-09-01T00:00:00Z",
            "valid_till": NSNull(),
            "method": "IOS",
            "data_elements": [
                ["uuid": "e-1", "name": "Email", "enabled": true, "required": false, "selected": true],
                ["uuid": "e-2", "name": "Phone", "enabled": true, "required": false, "selected": false],
            ] as [[String: Any]],
            "link_reason": NSNull(),
            "revoke_warning_message": NSNull(),
            "notice_uuid": notice,
        ]
    }

    static func groupJSON(product: String, name: String, notice: String, nominator: [String: Any]? = nil, hasMore: Bool = false) -> [String: Any] {
        let nominatorValue: Any = nominator.map { $0 as Any } ?? NSNull()
        return [
            "product_uuid": product,
            "product_name": name,
            "product_description": NSNull(),
            "nominator": nominatorValue,
            "total_purposes": hasMore ? 2 : 1,
            "active_purposes": 1,
            "purposes": [purposeJSON(notice: notice)],
            "has_more_purposes": hasMore,
        ]
    }

    static var nominatorJSON: [String: Any] {
        ["org_user_id": "NOM-1", "name": "Nominator", "uuid": nominator, "email": "nominator@example.test"]
    }

    static func detail(direct: [[String: Any]] = [], nominated: [[String: Any]] = []) throws -> UserConsentDetail {
        let object: [String: Any] = [
            "direct": direct,
            "nominated": nominated,
            "nominators": [] as [Any],
            "direct_pagination": ["total_count": direct.count, "offset": 0, "limit": 10] as [String: Any],
            "nominated_pagination": ["total_count": nominated.count, "offset": 0, "limit": 10] as [String: Any],
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(UserConsentDetail.self, from: data)
    }
}
