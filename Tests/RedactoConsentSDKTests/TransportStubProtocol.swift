import Foundation
import XCTest
@testable import RedactoConsentSDK

struct TransportStubResponse {
    let status: Int
    let body: Data
    let failure: URLError?

    static func json(_ status: Int, _ object: Any) -> TransportStubResponse {
        let body = (try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed])) ?? Data()
        return TransportStubResponse(status: status, body: body, failure: nil)
    }

    static func text(_ status: Int, _ text: String) -> TransportStubResponse {
        TransportStubResponse(status: status, body: Data(text.utf8), failure: nil)
    }

    static func empty(_ status: Int) -> TransportStubResponse {
        TransportStubResponse(status: status, body: Data(), failure: nil)
    }

    static let offline = TransportStubResponse(status: 0, body: Data(), failure: URLError(.notConnectedToInternet))
}

struct TransportStubRequest {
    let url: URL
    let method: String
    let headers: [String: String]
    let body: Data?

    var path: String { url.path }

    var bodyString: String? {
        body.map { String(decoding: $0, as: UTF8.self) }
    }

    var jsonBody: [String: Any]? {
        body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    var queryItems: [URLQueryItem] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    func query(_ name: String) -> String? {
        queryItems.first { $0.name == name }?.value
    }
}

final class TransportStubProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var handler: ((TransportStubRequest) -> TransportStubResponse)?
    private static var recorded: [TransportStubRequest] = []

    static func install(_ handler: @escaping (TransportStubRequest) -> TransportStubResponse) {
        lock.lock()
        self.handler = handler
        recorded = []
        lock.unlock()
        URLProtocol.registerClass(TransportStubProtocol.self)
    }

    static func uninstall() {
        URLProtocol.unregisterClass(TransportStubProtocol.self)
        lock.lock()
        handler = nil
        recorded = []
        lock.unlock()
    }

    static var requests: [TransportStubRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    static func requests(pathSuffix: String) -> [TransportStubRequest] {
        requests.filter { $0.path.hasSuffix(pathSuffix) }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return handler != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let captured = TransportStubRequest(
            url: request.url!,
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody ?? Self.drain(request.httpBodyStream)
        )
        Self.lock.lock()
        Self.recorded.append(captured)
        let handler = Self.handler
        Self.lock.unlock()

        let response = handler?(captured) ?? .empty(404)
        if let failure = response.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        let http = HTTPURLResponse(
            url: captured.url,
            statusCode: response.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func drain(_ stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

enum TransportFixtures {
    static let org = "org-1"
    static let workspace = "ws-1"
    static let notice = "ntc-1"
    static let ledger = "https://ledger.example.test/consent-ledger"
    static let python = "https://api.example.test/consent"

    static func token(org: String = TransportFixtures.org, workspace: String = TransportFixtures.workspace) -> String {
        let payload = try! JSONSerialization.data(withJSONObject: [
            "organisation_uuid": org,
            "workspace_uuid": workspace,
        ], options: [.sortedKeys])
        let encoded = payload.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "eyJhbGciOiJIUzI1NiJ9.\(encoded).sig"
    }

    static func scope(_ host: String) -> String {
        "\(host)/public/organisations/\(org)/workspaces/\(workspace)"
    }

    static let sandbox = SandboxConfig(
        token: "sandbox-token",
        ucic: "ucic-1",
        email: "tester@example.test",
        mobile: "+919999999999",
        organisationUuid: org,
        workspaceUuid: workspace
    )

    static func purpose(
        uuid: String = "p-1",
        selected: Bool = true,
        productUuid: String? = nil
    ) -> Purpose {
        Purpose(
            uuid: uuid,
            name: "Marketing",
            description: "",
            selected: selected,
            dataElements: [
                DataElement(uuid: "de-1", name: "Email", enabled: true, required: true, selected: true),
                DataElement(uuid: "de-2", name: "Phone", enabled: true, required: false, selected: false),
                DataElement(uuid: "de-3", name: "Hidden", enabled: false, required: false, selected: true),
            ],
            productUuid: productUuid
        )
    }

    static func noticeJSON(requiredElement: Bool = true) -> [String: Any] {
        let dataElement: [String: Any] = [
            "uuid": "de-1",
            "name": "Email",
            "enabled": true,
            "required": requiredElement,
        ]
        let purpose: [String: Any] = [
            "uuid": "p-1",
            "name": "Marketing",
            "description": "Marketing",
            "data_elements": [dataElement],
        ]
        let activeConfig: [String: Any] = [
            "uuid": "cfg-1",
            "notice_uuid": notice,
            "organisation_uuid": org,
            "workspace_uuid": workspace,
            "version": 1,
            "status": "active",
            "notice_text": "Notice",
            "additional_text": "",
            "confirm_button_text": "Accept",
            "decline_button_text": "Decline",
            "logo_url": "",
            "privacy_policy_url": "",
            "privacy_center_url": "",
            "primary_color": "#000000",
            "secondary_color": "#ffffff",
            "font_preference": "default",
            "default_language": "",
            "supported_languages_and_translations": [String: Any](),
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z",
            "deployed_at": "2024-01-01T00:00:00Z",
            "privacy_policy_prefix_text": "Read",
            "privacy_policy_anchor_text": "Policy",
            "purpose_section_heading": "Purposes",
            "notice_banner_heading": "Privacy Notice",
            "purposes": [purpose],
        ]
        let detail: [String: Any] = [
            "uuid": notice,
            "name": "Notice",
            "organisation_uuid": org,
            "workspace_uuid": workspace,
            "collection_point_uuids": [String](),
            "collection_points": [Any](),
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z",
            "active_config": activeConfig,
        ]
        return ["code": 200, "status": "success", "detail": detail]
    }

    static func consentStatusJSON(consented: Bool, allMandatoryActive: Bool) -> [String: Any] {
        let dataElement: [String: Any] = ["uuid": "de-1", "name": "Email", "selected": consented]
        let purpose: [String: Any] = [
            "uuid": "p-1",
            "name": "Marketing",
            "selected": consented,
            "status": consented ? "ACTIVE" : "INACTIVE",
            "data_elements": [dataElement],
        ]
        return [
            "consented": consented,
            "all_mandatory_active": allMandatoryActive,
            "purposes": [purpose],
        ]
    }
}

@MainActor
func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}
