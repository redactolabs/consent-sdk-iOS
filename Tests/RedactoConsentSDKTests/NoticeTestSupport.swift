import Foundation
import XCTest
@testable import RedactoConsentSDK

enum NoticeFixtures {
    static let baseUrl = "https://notice.test/consent"
    static let orders = "purpose-orders"
    static let marketing = "purpose-marketing"
    static let email = "element-email"
    static let phone = "element-phone"

    static let agentToken = makeToken(sub: "agent")
    static let customerToken = makeToken(sub: "customer")

    static func makeToken(sub: String) -> String {
        let header = base64Url(Data(#"{"alg":"HS256","typ":"JWT"}"#.utf8))
        let payload = base64Url(Data(#"{"organisation_uuid":"org-1","workspace_uuid":"ws-1","sub":"\#(sub)"}"#.utf8))
        return "\(header).\(payload).signature"
    }

    private static func base64Url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func element(_ uuid: String, name: String, required: Bool = false, enabled: Bool = true) -> [String: Any] {
        ["uuid": uuid, "name": name, "enabled": enabled, "required": required]
    }

    static func purpose(_ uuid: String, name: String, elements: [[String: Any]]) -> [String: Any] {
        ["uuid": uuid, "name": name, "description": "\(name) description", "data_elements": elements]
    }

    static var defaultPurposes: [[String: Any]] {
        [
            purpose(orders, name: "Order Fulfilment", elements: [
                element(email, name: "Email Address", required: true),
                element(phone, name: "Phone Number"),
            ]),
            purpose(marketing, name: "Marketing", elements: [
                element(email, name: "Email Address"),
            ]),
        ]
    }

    static func content(
        purposes: [[String: Any]]? = nil,
        config: [String: Any] = [:],
        purposeSelections: [String: Any]? = nil
    ) -> ConsentContent {
        let data = contentData(purposes: purposes, config: config, purposeSelections: purposeSelections)
        return try! JSONDecoder().decode(ConsentContent.self, from: data)
    }

    static func contentData(
        purposes: [[String: Any]]? = nil,
        config: [String: Any] = [:],
        purposeSelections: [String: Any]? = nil
    ) -> Data {
        var activeConfig: [String: Any] = [
            "uuid": "config-1",
            "notice_uuid": "notice-1",
            "organisation_uuid": "org-1",
            "workspace_uuid": "ws-1",
            "version": 1,
            "status": "active",
            "notice_text": "Notice",
            "additional_text": "",
            "confirm_button_text": "Accept Selected",
            "decline_button_text": "Decline",
            "logo_url": "",
            "privacy_policy_url": "https://group.example.test/privacy",
            "privacy_center_url": "",
            "primary_color": "#4f87ff",
            "secondary_color": "#ffffff",
            "font_preference": "",
            "purposes": purposes ?? defaultPurposes,
            "default_language": "en",
            "supported_languages_and_translations": [String: Any](),
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z",
            "deployed_at": "2026-01-01T00:00:00Z",
            "privacy_policy_prefix_text": "Read our",
            "privacy_policy_anchor_text": "Privacy Policy",
            "purpose_section_heading": "Purposes",
            "notice_banner_heading": "Privacy Notice",
        ]
        for (key, value) in config {
            activeConfig[key] = value
        }
        var detail: [String: Any] = [
            "uuid": "notice-1",
            "name": "Notice",
            "organisation_uuid": "org-1",
            "workspace_uuid": "ws-1",
            "collection_point_uuids": [String](),
            "collection_points": [[String: Any]](),
            "active_config": activeConfig,
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z",
        ]
        if let purposeSelections {
            detail["purpose_selections"] = purposeSelections
        }
        let root: [String: Any] = ["code": 200, "status": "success", "detail": detail]
        return try! JSONSerialization.data(withJSONObject: root)
    }
}

final class CallCounter {
    var count = 0
}

struct NoticeUnderTest {
    let vm: ConsentNoticeViewModel
    let accepts: CallCounter
    let declines: CallCounter
    let errors: CallCounter
}

@MainActor
func makeNotice(
    accessToken: String = NoticeFixtures.agentToken,
    otpGate: OtpGate? = nil,
    settings: ConsentSettings? = nil,
    content: ConsentContent = NoticeFixtures.content()
) -> NoticeUnderTest {
    let accepts = CallCounter()
    let declines = CallCounter()
    let errors = CallCounter()
    let vm = ConsentNoticeViewModel(
        noticeId: "notice-1",
        accessToken: accessToken,
        refreshToken: "",
        baseUrl: NoticeFixtures.baseUrl,
        settings: settings,
        onAccept: { accepts.count += 1 },
        onDecline: { declines.count += 1 },
        onError: { _ in errors.count += 1 },
        otpGate: otpGate
    )
    vm.content = content
    return NoticeUnderTest(vm: vm, accepts: accepts, declines: declines, errors: errors)
}

struct CapturedSubmit {
    let authorization: String?
    let body: [String: Any]

    var purposes: [[String: Any]] {
        body["purposes"] as? [[String: Any]] ?? []
    }

    var selectedByPurpose: [String: Bool] {
        var result: [String: Bool] = [:]
        for purpose in purposes {
            if let uuid = purpose["purpose_uuid"] as? String {
                result[uuid] = purpose["selected"] as? Bool
            }
        }
        return result
    }

    func dataElements(of purposeUuid: String) -> [String: Bool] {
        let purpose = purposes.first { $0["purpose_uuid"] as? String == purposeUuid }
        var result: [String: Bool] = [:]
        for element in purpose?["data_elements"] as? [[String: Any]] ?? [] {
            if let uuid = element["uuid"] as? String {
                result[uuid] = element["selected"] as? Bool
            }
        }
        return result
    }
}

final class SubmitRecorder: URLProtocol {
    private static let lock = NSLock()
    private static var captured: [CapturedSubmit] = []
    private static var served: Data?

    static func serveNotice(_ data: Data) {
        lock.lock()
        served = data
        lock.unlock()
    }

    static var submits: [CapturedSubmit] {
        lock.lock()
        defer { lock.unlock() }
        return captured
    }

    static func start() {
        lock.lock()
        captured = []
        served = nil
        lock.unlock()
        URLProtocol.registerClass(SubmitRecorder.self)
    }

    static func stop() {
        URLProtocol.unregisterClass(SubmitRecorder.self)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "notice.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let body = request.httpBody ?? Self.read(request.httpBodyStream)
        if request.url?.path.hasSuffix("/submit-consent") == true {
            let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
            Self.lock.lock()
            Self.captured.append(CapturedSubmit(
                authorization: request.value(forHTTPHeaderField: "Authorization"),
                body: json
            ))
            Self.lock.unlock()
        }
        Self.lock.lock()
        let notice = request.url?.path.contains("/notices/") == true ? Self.served : nil
        Self.lock.unlock()
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: NoticeFixtures.baseUrl)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: notice ?? Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream?) -> Data {
        guard let stream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

@MainActor
func settle() async {
    try? await Task.sleep(nanoseconds: 150_000_000)
}

final class VerifierSpy {
    private let lock = NSLock()
    private var recorded: [String] = []
    private var results: [Result<OtpVerifyResult, Error>]
    private let fallback: Result<OtpVerifyResult, Error>

    init(_ fallback: Result<OtpVerifyResult, Error> = .success(OtpVerifyResult(ok: true)), queued: [Result<OtpVerifyResult, Error>] = []) {
        self.fallback = fallback
        self.results = queued
    }

    var calls: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func verify(_ code: String) throws -> OtpVerifyResult {
        lock.lock()
        recorded.append(code)
        let result = results.isEmpty ? fallback : results.removeFirst()
        lock.unlock()
        return try result.get()
    }

    func gate(
        required: Bool = true,
        title: String? = nil,
        description: String? = nil,
        submitLabel: String? = nil
    ) -> OtpGate {
        OtpGate(
            required: required,
            onVerify: { code in try self.verify(code) },
            title: title,
            description: description,
            submitLabel: submitLabel
        )
    }
}

final class PendingVerifier {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<OtpVerifyResult, Error>?

    var started: Bool {
        lock.lock()
        defer { lock.unlock() }
        return continuation != nil
    }

    func verify(_ code: String) async throws -> OtpVerifyResult {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
        }
    }

    func fail(_ error: Error) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(throwing: error)
    }

    func succeed(_ result: OtpVerifyResult = OtpVerifyResult(ok: true)) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: result)
    }
}

struct VerifyFailure: Error, LocalizedError {
    let text: String
    var errorDescription: String? { text }
}

func digitsOf(_ code: String, length: Int = OtpGateCopy.length) -> [String] {
    let characters = Array(code)
    return (0..<length).map { $0 < characters.count ? String(characters[$0]) : "" }
}
