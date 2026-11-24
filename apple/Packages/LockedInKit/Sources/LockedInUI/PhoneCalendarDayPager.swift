#if os(iOS)
import SwiftUI
import UIKit

// UIKit's page controller supplies interactive paging, cancellation and deceleration.
struct PhoneCalendarAccentHost<Content: View>: View {
  var content: Content
  var body: some View { content.trackItAccent() }
}

struct PhoneCalendarDayPager<Content: View>: UIViewControllerRepresentable {
  @Binding var day: Date
  var content: (Date) -> Content

  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIViewController(context: Context) -> UIPageViewController {
    let controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
    controller.dataSource = context.coordinator
    controller.delegate = context.coordinator
    controller.view.backgroundColor = .clear
    controller.setViewControllers([context.coordinator.page(day)], direction: .forward, animated: false)
    return controller
  }
  func updateUIViewController(_ controller: UIPageViewController, context: Context) {
    let coordinator = context.coordinator
    coordinator.parent = self
    for (date, page) in coordinator.pages { page.rootView = PhoneCalendarAccentHost(content: content(date)) }
    guard !coordinator.transitioning, let visible = controller.viewControllers?.first,
      let current = coordinator.date(of: visible), !Calendar.current.isDate(current, inSameDayAs: day) else { return }
    let animated = !UIAccessibility.isReduceMotionEnabled
    coordinator.transitioning = true
    controller.setViewControllers([coordinator.page(day)], direction: day > current ? .forward : .reverse,
      animated: animated) { _ in coordinator.transitioning = false }
  }
  final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    var parent: PhoneCalendarDayPager
    var pages: [Date: UIHostingController<PhoneCalendarAccentHost<Content>>] = [:]
    var transitioning = false
    private let calendar = Calendar.current
    init(_ parent: PhoneCalendarDayPager) { self.parent = parent }
    func page(_ date: Date) -> UIHostingController<PhoneCalendarAccentHost<Content>> {
      let day = calendar.startOfDay(for: date)
      if let page = pages[day] { return page }
      let page = UIHostingController(rootView: PhoneCalendarAccentHost(content: parent.content(day)))
      page.view.backgroundColor = .clear
      pages[day] = page
      return page
    }
    func date(of controller: UIViewController) -> Date? {
      pages.first(where: { $0.value === controller })?.key
    }
    func pageViewController(_ controller: UIPageViewController,
      viewControllerBefore page: UIViewController) -> UIViewController? {
      guard let date = date(of: page), let previous = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
      return self.page(previous)
    }
    func pageViewController(_ controller: UIPageViewController,
      viewControllerAfter page: UIViewController) -> UIViewController? {
      guard let date = date(of: page), let next = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
      return self.page(next)
    }
    func pageViewController(_ controller: UIPageViewController, willTransitionTo pending: [UIViewController]) {
      transitioning = true
    }
    func pageViewController(_ controller: UIPageViewController, didFinishAnimating finished: Bool,
      previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
      transitioning = false
      guard completed, let visible = controller.viewControllers?.first, let date = date(of: visible) else { return }
      parent.day = date
      // Keep neighbours alive, without accumulating every day visited in a long session.
      pages = pages.filter { abs(calendar.dateComponents([.day], from: date, to: $0.key).day ?? 0) <= 2 }
    }
  }
}
#endif
