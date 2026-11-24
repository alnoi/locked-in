import Foundation
import ImageIO
import LockedInDomain
import UniformTypeIdentifiers

struct BugReportAttachment {
  static func image(_ original: Data) throws -> Data {
    guard original.count <= 30 * 1024 * 1024,
      let source = CGImageSourceCreateWithData(original as CFData, nil) else {
      throw TrackerError.validation("Не удалось прочитать картинку. Выбери другой скриншот.")
    }
    for dimension in [2000, 1600, 1200] {
      let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: dimension]
      guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { continue }
      for quality in [0.82, 0.65, 0.5] {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { continue }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        if CGImageDestinationFinalize(destination), output.length <= 524288 { return output as Data }
      }
    }
    throw TrackerError.validation("Скриншот слишком большой. Выбери картинку поменьше.")
  }
  static func file(_ url: URL) throws -> Data {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 30 * 1024 * 1024 {
      throw TrackerError.validation("Картинка слишком большая. Выбери скриншот поменьше.")
    }
    return try image(Data(contentsOf: url, options: .mappedIfSafe))
  }
  static func provider(_ provider: NSItemProvider) async throws -> Data {
    if let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) {
      return try image(await representation(provider, type: type))
    }
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
      let data = try await representation(provider, type: UTType.fileURL.identifier)
      guard let url = URL(dataRepresentation: data, relativeTo: nil) else { throw RequestFailure.invalidAttachment }
      return try file(url)
    }
    throw TrackerError.validation("В буфере нет картинки. Скопируй скриншот и попробуй ещё раз.")
  }
  private static func representation(_ provider: NSItemProvider, type: String) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
        if let data { continuation.resume(returning: data) }
        else { continuation.resume(throwing: error ?? RequestFailure.invalidAttachment) }
      }
    }
  }
}
