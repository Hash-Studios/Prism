import UIKit
import UniformTypeIdentifiers

/// Takes one image or one link from another app, leaves it for Prism, and opens Prism.
final class ShareViewController: UIViewController {
  private var started = false

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
    provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, _ in
      // The temporary file exists only until this handler returns, so copy it here.
      if let url, let id = try? ShareInbox.store(fileAt: url, ext: ext, container: container) {
        self?.finish(opening: ShareInbox.openURL(id: id))
        return
      }
      self?.loadImageItem(provider, type: type, ext: ext, container: container)
    }
  }

  /// Some apps give only an in-memory image. This path can use more memory, so it is the fallback.
  private func loadImageItem(_ provider: NSItemProvider, type: String, ext: String, container: URL) {
    provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, _ in
      var id: String?
      if let url = item as? URL, url.isFileURL {
        id = try? ShareInbox.store(fileAt: url, ext: ext, container: container)
      } else if let data = item as? Data {
        id = try? ShareInbox.store(data: data, ext: ext, container: container)
      } else if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.92) {
        id = try? ShareInbox.store(data: data, ext: "jpg", container: container)
      }
      self?.finish(opening: id.flatMap(ShareInbox.openURL(id:)))
    }
  }

  private func loadText(_ provider: NSItemProvider, type: String) {
    provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, _ in
      let text = (item as? URL)?.absoluteString ?? (item as? String) ?? (item as? NSAttributedString)?.string
      self?.finish(opening: text.flatMap(ShareInbox.openURL(text:)))
    }
  }

  private func finish(opening url: URL?) {
    DispatchQueue.main.async {
      if let url { self.open(url) }
      self.extensionContext?.completeRequest(returningItems: nil)
    }
  }

  /// Extensions cannot call UIApplication.open directly. Find the app object in the responder chain and send it
  /// the same message.
  private func open(_ url: URL) {
    let selector = sel_registerName("openURL:options:completionHandler:")
    var responder: UIResponder? = self
    while let current = responder {
      if current.responds(to: selector), current !== self {
        typealias OpenURL = @convention(c) (AnyObject, Selector, URL, NSDictionary, Any?) -> Void
        let method = unsafeBitCast(current.method(for: selector), to: OpenURL.self)
        method(current, selector, url, NSDictionary(), nil)
        return
      }
      responder = current.next
    }
  }
}
