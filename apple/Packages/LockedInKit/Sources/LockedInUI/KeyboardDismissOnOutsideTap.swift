import SwiftUI

#if os(iOS)
import UIKit

struct KeyboardDismissOnOutsideTap: UIViewRepresentable {
  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeUIView(context: Context) -> AnchorView {
    let view = AnchorView()
    view.isUserInteractionEnabled = false
    view.windowChanged = { [weak coordinator = context.coordinator] window in coordinator?.attach(to: window) }
    return view
  }
  func updateUIView(_ view: AnchorView, context: Context) { context.coordinator.attach(to: view.window) }
  static func dismantleUIView(_ view: AnchorView, coordinator: Coordinator) { coordinator.attach(to: nil) }

  final class AnchorView: UIView {
    var windowChanged: ((UIWindow?) -> Void)?
    override func didMoveToWindow() { super.didMoveToWindow(); windowChanged?(window) }
  }
  @MainActor final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    private weak var window: UIWindow?
    private weak var editingView: UIView?
    private var recognizer: UITapGestureRecognizer?
    private var observers: [NSObjectProtocol] = []
    private var keyboardFrame: CGRect = .zero

    func attach(to target: UIWindow?) {
      guard window !== target else { return }
      if let recognizer { window?.removeGestureRecognizer(recognizer) }
      observers.forEach(NotificationCenter.default.removeObserver)
      observers = []
      recognizer = nil
      editingView = nil
      keyboardFrame = .zero
      window = target
      guard let target else { return }
      let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
      tap.cancelsTouchesInView = false
      tap.delaysTouchesBegan = false
      tap.delaysTouchesEnded = false
      tap.delegate = self
      target.addGestureRecognizer(tap)
      recognizer = tap
      observers.append(NotificationCenter.default.addObserver(
        forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main
      ) { [weak self] notification in
        MainActor.assumeIsolated {
          self?.keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        }
      })
      observers.append(NotificationCenter.default.addObserver(
        forName: UIResponder.keyboardDidHideNotification, object: nil, queue: .main
      ) { [weak self] _ in MainActor.assumeIsolated { self?.keyboardFrame = .zero } })
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
      editingView = nil
      guard let window else { return false }
      if !keyboardFrame.isEmpty,
        window.convert(keyboardFrame, from: window.screen.coordinateSpace).contains(touch.location(in: window)) {
        return false
      }
      if containsInputArea(in: window, point: touch.location(in: window)) { return false }
      // Keep editing when tapping any input, including a different field or the search bar.
      var view = touch.view
      while let current = view {
        if current is UITextField || current is UITextView || current is UISearchBar || current is UIInputView { return false }
        view = current.superview
      }
      guard let responder = firstResponder(in: window), responder is UIKeyInput else { return false }
      editingView = responder
      return true
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    @objc private func dismissKeyboard() {
      // A tapped button may focus a new field; don't dismiss that new editing session.
      if editingView?.isFirstResponder == true {
        NotificationCenter.default.post(name: .keyboardDismissedOutside, object: nil)
        editingView?.resignFirstResponder()
      }
      editingView = nil
    }
    private func containsInputArea(in view: UIView, point: CGPoint) -> Bool {
      guard !view.isHidden, view.alpha > 0.01 else { return false }
      if view is KeyboardInputArea.AnchorView,
        view.bounds.contains(view.convert(point, from: window)) { return true }
      return view.subviews.contains { containsInputArea(in: $0, point: point) }
    }
    private func firstResponder(in view: UIView) -> UIView? {
      if view.isFirstResponder { return view }
      for child in view.subviews { if let responder = firstResponder(in: child) { return responder } }
      return nil
    }
  }
}

private struct KeyboardInputArea: UIViewRepresentable {
  final class AnchorView: UIView {}
  func makeUIView(context: Context) -> AnchorView {
    let view = AnchorView()
    view.isUserInteractionEnabled = false
    return view
  }
  func updateUIView(_ view: AnchorView, context: Context) {}
}
#endif

extension Notification.Name {
  static let keyboardDismissedOutside = Notification.Name("TrackIt.keyboardDismissedOutside")
}

extension View {
  @ViewBuilder func keyboardInputArea() -> some View {
    #if os(iOS)
    background { KeyboardInputArea().allowsHitTesting(false) }
    #else
    self
    #endif
  }
}
