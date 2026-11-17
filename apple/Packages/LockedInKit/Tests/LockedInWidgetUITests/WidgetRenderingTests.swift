import AppKit
import SwiftUI
import WidgetKit
import XCTest
@testable import LockedInWidgetUI

final class WidgetRenderingTests: XCTestCase {
  @MainActor func testAllWidgetSizesRenderInLightAndDarkAppearance() throws {
    let directory = URL(fileURLWithPath: "/private/tmp/trackit-widget-previews", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for scheme in [ColorScheme.light, .dark] {
      for family in [WidgetFamily.systemMedium, .systemLarge] {
        let width: CGFloat = 360
        let height: CGFloat = family == .systemLarge ? 380 : 170
        try render(TodayWidgetView(entry: .sample, family: family), name: "today", family: family, scheme: scheme, width: width, height: height, directory: directory)
        try render(CalendarWidgetView(entry: .sample, family: family), name: "calendar", family: family, scheme: scheme, width: width, height: height, directory: directory)
      }
    }
  }
  @MainActor private func render<V: View>(_ view: V, name: String, family: WidgetFamily,
    scheme: ColorScheme, width: CGFloat, height: CGFloat, directory: URL) throws {
    let content = view.padding(16).frame(width: width, height: height)
      .background(WidgetBackdrop()).clipShape(RoundedRectangle(cornerRadius: 22))
      .environment(\.colorScheme, scheme).environment(\.widgetPreviewRendering, true)
    let renderer = ImageRenderer(content: content)
    renderer.scale = 2
    let image = try XCTUnwrap(renderer.cgImage)
    XCTAssertEqual(image.width, Int(width * 2))
    XCTAssertEqual(image.height, Int(height * 2))
    let bitmap = NSBitmapImageRep(cgImage: image)
    let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    try data.write(to: directory.appendingPathComponent("\(name)-\(family)-\(scheme).png"))
  }
}
