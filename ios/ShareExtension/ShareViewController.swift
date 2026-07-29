import UIKit
import UniformTypeIdentifiers

// 공유 시트 상단 앱 줄에 뜨는 Share Extension.
// 링크를 뽑는 즉시 mukbang:// 스킴으로 본체 앱을 열고 시트를 닫는다.
// 앱 전환이 막힌 환경을 대비해 클립보드에도 링크를 남겨둔다.
final class ShareViewController: UIViewController {
    private var didProcess = false
    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .headline)
        // 성공 경로에선 아무것도 보여주지 않는다. 실패했을 때만 노출.
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didProcess else { return }
        didProcess = true
        Task { await process() }
    }

    private func process() async {
        guard let link = await extractLink() else {
            label.text = "링크를 못 찾았어요 😢\n게시물 링크를 복사해서 앱에 붙여넣어 주세요"
            label.isHidden = false
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            extensionContext?.completeRequest(returningItems: nil)
            return
        }

        // 앱 전환이 실패하는 환경을 대비한 폴백 경로.
        UIPasteboard.general.string = link

        if await openMainApp(link) {
            // openURL: 이 처리될 최소한의 틈만 주고 곧바로 시트를 닫는다.
            try? await Task.sleep(nanoseconds: 250_000_000)
        } else {
            label.text = "링크를 담았어요 🍜\n먹방 따라담기 앱을 열어주세요"
            label.isHidden = false
            try? await Task.sleep(nanoseconds: 1_400_000_000)
        }
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func extractLink() async -> String? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        let urlTypes = [UTType.url.identifier, "public.file-url"]
        for item in items {
            for provider in item.attachments ?? [] {
                for type in urlTypes where provider.hasItemConformingToTypeIdentifier(type) {
                    if let raw = try? await provider.loadItem(forTypeIdentifier: type) {
                        if let url = raw as? URL { return url.absoluteString }
                        if let s = raw as? String, let u = URL(string: s) { return u.absoluteString }
                    }
                }
            }
        }
        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let raw = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
                   let text = raw as? String,
                   let range = text.range(of: #"https?://\S+"#, options: .regularExpression) {
                    return String(text[range])
                }
            }
        }
        for item in items {
            if let text = item.attributedContentText?.string,
               let range = text.range(of: #"https?://\S+"#, options: .regularExpression) {
                return String(text[range])
            }
        }
        return nil
    }

    /// 익스텐션에는 UIApplication.shared 가 없다.
    ///
    /// 응답자 체인을 거슬러 올라가 `openURL:options:completionHandler:` 에 응답하는
    /// 객체를 찾아 호출한다. Chromium 의 ExtensionOpenURL 과 같은 방식이다.
    /// 구형 `openURL:` 은 iOS 10 에서 폐기돼 respondsToSelector 는 true 를 주지만
    /// 실제로는 아무 동작도 하지 않으므로 쓰면 안 된다.
    ///
    /// extensionContext.open 은 Share Extension 에서 true 를 반환하고도 전환되지
    /// 않는 것이 실기기에서 확인돼, 응답자 체인이 모두 실패했을 때만 시도한다.
    private func openMainApp(_ link: String) async -> Bool {
        var comps = URLComponents(string: "mukbang://analyze")!
        comps.queryItems = [URLQueryItem(name: "u", value: link)]
        guard let url = comps.url else { return false }

        if openViaResponderChain(url) { return true }

        guard let ctx = extensionContext else { return false }
        return await withCheckedContinuation { cont in
            ctx.open(url) { cont.resume(returning: $0) }
        }
    }

    private func openViaResponderChain(_ url: URL) -> Bool {
        typealias OpenURLMethod = @convention(c)
            (NSObject, Selector, NSURL, NSDictionary?, Any?) -> Void
        let selector = NSSelectorFromString("openURL:options:completionHandler:")

        var responder: UIResponder? = self.next
        while let current = responder {
            if current.responds(to: selector),
               let method = class_getInstanceMethod(type(of: current), selector) {
                let fn = unsafeBitCast(method_getImplementation(method), to: OpenURLMethod.self)
                fn(current, selector, url as NSURL, nil, nil)
                return true
            }
            responder = current.next
        }
        return false
    }
}
