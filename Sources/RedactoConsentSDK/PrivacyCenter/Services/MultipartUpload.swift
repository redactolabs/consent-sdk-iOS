import Foundation

struct MultipartFormBuilder {
    let boundary: String

    init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    func body(filename: String, mimeType: String, fileData: Data) -> Data {
        var body = Data()
        appendString("--\(boundary)\r\n", to: &body)
        appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n", to: &body)
        appendString("Content-Type: \(mimeType)\r\n\r\n", to: &body)
        body.append(fileData)
        appendString("\r\n--\(boundary)--\r\n", to: &body)
        return body
    }

    private func appendString(_ string: String, to data: inout Data) {
        if let chunk = string.data(using: .utf8) {
            data.append(chunk)
        }
    }
}
