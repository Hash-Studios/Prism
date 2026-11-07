import UIKit
import UniformTypeIdentifiers

/// Takes one image or one link from another app, leaves it for Prism, and opens Prism.
final class ShareViewController: UIViewController {
  private var started = false
  private var completed = false
  private let request = ShareInboxRequest()
  private var loading: Progress?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    let spinner = UIActivityIndicatorView(style: .medium)
    spinner.startAnimating()
    let label = UILabel()
    label.text = String(localized: "Opening Prism")
    label.font = .preferredFont(forTextStyle: .headline)
    label.adjustsFontForContentSizeCategory = true
    label.numberOfLines = 0
    label.textAlignment = .center
    let stack = UIStackView(arrangedSubviews: [spinner, label])
    stack.axis = .vertical
    stack.spacing = 12
    stack.alignment = .center
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
    ])
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !started else { return }
    started = true
    request.startTimeout { [weak self] in self?.finish(opening: nil) }
    if let container = ShareInbox.containerURL() { ShareInbox.sweep(container: container) }
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
    if let image = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
      loadImage(image)
    } else if let link = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
      loadText(link, type: UTType.url.identifier)
    } else if let text = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
      loadText(text, type: UTType.plainText.identifier)
    } else {
      finish(opening: nil)
    }
  }

  private func loadImage(_ provider: NSItemProvider) {
    guard let container = ShareInbox.containerURL() else { return finish(opening: nil) }
    let type = provider.registeredTypeIdentifiers.first { UTType($0)?.conforms(to: .image) == true }
      ?? UTType.image.identifier
    let ext = ShareInbox.fileExtension(forTypeIdentifier: type)
    loading = provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, _ in
      guard let self, !self.request.isFinished else { return }
      // The temporary file exists only until this handler returns, so copy it here.
      // Do not ask for UIImage/Data if the provider has no file representation.
      let id = url.flatMap { try? ShareInbox.store(
        fileAt: $0, ext: ext, container: container, isCanceled: { self.request.isFinished }
      ) }
      let file = id.map { ShareInbox.folder(in: container).appendingPathComponent("\($0).\(ext)") }
      self.finish(opening: id.flatMap(ShareInbox.openURL(id:)), storedFile: file)
    }
  }

  private func loadText(_ provider: NSItemProvider, type: String) {
    provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, _ in
      let text = (item as? URL)?.absoluteString ?? (item as? String) ?? (item as? NSAttributedString)?.string
      self?.finish(opening: text.flatMap(ShareInbox.openURL(text:)))
    }
  }

  private func finish(opening url: URL?, storedFile: URL? = nil) {
    DispatchQueue.main.async {
      guard self.request.finish(discardingIfLate: storedFile) else { return }
      self.loading?.cancel()
      guard let url else { return self.complete() }
      if let container = ShareInbox.containerURL() { ShareInbox.storePendingLink(url, container: container) }
      // Completing the request before the open finishes keeps Prism in the background.
      self.open(url)
      DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.complete() }
    }
  }

  private func complete() {
    guard !completed else { return }
    completed = true
    extensionContext?.completeRequest(returningItems: nil)
  }

  /// Extensions cannot call UIApplication.open directly. Find the app object in the responder chain and send it
  /// the same message, then complete the request. The window scene comes first and has a method with the same
  /// selector, but it takes a different options type, so only UIApplication may receive it.
  private func open(_ url: URL) {
    let selector = sel_registerName("openURL:options:completionHandler:")
    typealias Completion = @convention(block) (Bool) -> Void
    typealias OpenURL = @convention(c) (AnyObject, Selector, URL, NSDictionary, Completion?) -> Void
    var responder: UIResponder? = self
    while let current = responder {
      if current is UIApplication, current.responds(to: selector) {
        let method = unsafeBitCast(current.method(for: selector), to: OpenURL.self)
        method(current, selector, url, NSDictionary()) { _ in DispatchQueue.main.async { self.complete() } }
        return
      }
      responder = current.next
    }
    complete()
  }
}
