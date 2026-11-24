#if os(iOS)
import SwiftUI
import UIKit

// Keep the sheet until its draft has been saved, then dismiss through SwiftUI.
struct TaskSwipeDismiss: UIViewControllerRepresentable {
  var enabled: Bool
  var attempt: () -> Void
  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeUIViewController(context: Context) -> AnchorController {
    let controller = AnchorController()
    controller.attach = { [weak coordinator = context.coordinator, weak controller] in
      if let controller { coordinator?.watch(controller) }
    }
    return controller
  }
  func updateUIViewController(_ controller: AnchorController, context: Context) {
    context.coordinator.enabled = enabled
    context.coordinator.attempt = attempt
    DispatchQueue.main.async { [weak controller] in controller?.attach?() }
  }
  static func dismantleUIViewController(_ controller: AnchorController, coordinator: Coordinator) { coordinator.stop() }
  final class AnchorController: UIViewController {
    var attach: (() -> Void)?
    override func loadView() { view = UIView(); view.isUserInteractionEnabled = false }
    override func didMove(toParent parent: UIViewController?) { super.didMove(toParent: parent); attach?() }
  }
  @MainActor final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
    var enabled = false
    var attempt: (() -> Void)?
    private weak var presentation: UIPresentationController?
    private weak var previousDelegate: UIAdaptivePresentationControllerDelegate?
    func watch(_ anchor: UIViewController) {
      var current: UIViewController? = anchor
      while let controller = current {
        if controller.presentingViewController != nil, let target = controller.presentationController {
          if presentation !== target { stop(); presentation = target }
          if target.delegate !== self { previousDelegate = target.delegate; target.delegate = self }
          return
        }
        current = controller.parent
      }
    }
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool { false }
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
      if enabled { attempt?() }
    }
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
      previousDelegate?.presentationControllerWillDismiss?(presentationController)
    }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
      previousDelegate?.presentationControllerDidDismiss?(presentationController)
    }
    func stop() {
      if presentation?.delegate === self { presentation?.delegate = previousDelegate }
      presentation = nil
      previousDelegate = nil
    }
  }
}
#endif
