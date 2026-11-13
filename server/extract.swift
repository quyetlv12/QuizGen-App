import Foundation
import PDFKit
import Vision
import AppKit

func recognize(_ image: CGImage) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["vi-VN", "en-US"]
    request.usesLanguageCorrection = true
    try VNImageRequestHandler(cgImage: image).perform([request])
    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
}

do {
    let url = URL(fileURLWithPath: CommandLine.arguments[1])
    var pages: [String] = []
    if url.pathExtension.lowercased() == "pdf" {
        guard let doc = PDFDocument(url: url), !doc.isLocked else { throw NSError(domain: "PDF bị khóa hoặc hỏng", code: 1) }
        guard doc.pageCount > 0 && doc.pageCount <= 20 else { throw NSError(domain: "PDF cần có từ 1 đến 20 trang", code: 1) }
        for n in 0..<doc.pageCount {
            guard let page = doc.page(at: n) else { continue }
            var text = page.string ?? ""
            if text.trimmingCharacters(in: .whitespacesAndNewlines).count < 30 {
                let thumb = page.thumbnail(of: NSSize(width: 1800, height: 2400), for: .mediaBox)
                var rect = CGRect(origin: .zero, size: thumb.size)
                if let image = thumb.cgImage(forProposedRect: &rect, context: nil, hints: nil) { text = try recognize(image) }
            }
            pages.append(text)
        }
    } else {
        guard let image = NSImage(contentsOf: url) else { throw NSError(domain: "Ảnh không đọc được", code: 1) }
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil), cg.width * cg.height <= 40000000 else { throw NSError(domain: "Ảnh quá lớn hoặc hỏng", code: 1) }
        pages = [try recognize(cg)]
    }
    let data = try JSONSerialization.data(withJSONObject: pages)
    FileHandle.standardOutput.write(data)
} catch {
    FileHandle.standardError.write(Data("Không đọc được tài liệu. Kiểm tra mật khẩu, số trang và chất lượng ảnh.".utf8))
    exit(1)
}
