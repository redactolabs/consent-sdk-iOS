import Foundation

struct MultipartFormBuilder {
    let boundary: String

    init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    /// The upload endpoints require a JSON `payload` part next to `file`; without
    /// it they answer 422.
    func body(filename: String, mimeType: String, fileData: Data, payload: Data) -> Data {
        var body = Data()
        appendString("--\(boundary)\r\n", to: &body)
        appendString("Content-Disposition: form-data; name=\"payload\"\r\n", to: &body)
        appendString("Content-Type: application/json\r\n\r\n", to: &body)
        body.append(payload)
        appendString("\r\n--\(boundary)\r\n", to: &body)
        appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(Self.safeFilename(filename))\"\r\n", to: &body)
        appendString("Content-Type: \(mimeType)\r\n\r\n", to: &body)
        body.append(fileData)
        appendString("\r\n--\(boundary)--\r\n", to: &body)
        return body
    }

    /// `raw` as a name a Content-Disposition header can carry: its last path
    /// component without quotes, backslashes or control characters, so a picked
    /// file cannot end the header or start another part.
    static func safeFilename(_ raw: String) -> String {
        let component = raw.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init) ?? ""
        let kept = component.unicodeScalars.filter { scalar in
            scalar.value >= 0x20 && scalar.value != 0x7F && scalar != "\"" && scalar != "\\"
        }
        let name = String(String.UnicodeScalarView(kept)).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "upload" : String(name.prefix(255))
    }

    private func appendString(_ string: String, to data: inout Data) {
        if let chunk = string.data(using: .utf8) {
            data.append(chunk)
        }
    }
}
