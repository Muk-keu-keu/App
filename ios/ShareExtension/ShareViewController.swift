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
        let shared = await extractShared()
        guard let link = shared.link else {
            label.text = "링크를 못 찾았어요 😢\n게시물 링크를 복사해서 앱에 붙여넣어 주세요"
            label.isHidden = false
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            extensionContext?.completeRequest(returningItems: nil)
            return
        }

        // 앱 전환이 실패하는 환경을 대비한 폴백 경로.
        UIPasteboard.general.string = link

        if await openMainApp(link, text: shared.text) {
            // openURL: 이 처리될 최소한의 틈만 주고 곧바로 시트를 닫는다.
            try? await Task.sleep(nanoseconds: 250_000_000)
        } else {
            label.text = "링크를 담았어요 🍜\n먹방요기 앱을 열어주세요"
            label.isHidden = false
            try? await Task.sleep(nanoseconds: 1_400_000_000)
        }
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// 공유로 들어온 링크와 원문.
    ///
    /// **원문을 버리지 않는다.** 인스타는 로그인 없이 캡션을 주지 않아서, 링크로
    /// 다시 요청해 봐야 og 태그가 `Instagram / null` 뿐이다. 그러면 추출이 0건이
    /// 되고 그 빈자리를 서버 추측이 채워, 영상에 없던 음식이 결과로 뜬다.
    /// 공유 시점의 텍스트가 그 캡션을 얻을 수 있는 유일한 창이다.
    private func extractShared() async -> (link: String?, text: String?) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return (nil, nil)
        }

        var link: String?
        var text: String?

        let urlTypes = [UTType.url.identifier, "public.file-url"]
        for item in items {
            for provider in item.attachments ?? [] {
                for type in urlTypes where provider.hasItemConformingToTypeIdentifier(type) {
                    if link == nil, let raw = try? await provider.loadItem(forTypeIdentifier: type) {
                        if let url = raw as? URL { link = url.absoluteString }
                        else if let s = raw as? String, let u = URL(string: s) { link = u.absoluteString }
                    }
                }
            }
        }

        // 텍스트 첨부는 링크가 이미 있어도 계속 본다 — 캡션이 여기 담겨 온다.
        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let raw = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
                   let s = raw as? String {
                    if text == nil { text = s }
                    if link == nil, let range = s.range(of: #"https?://\S+"#, options: .regularExpression) {
                        link = String(s[range])
                    }
                }
            }
        }

        for item in items {
            if let s = item.attributedContentText?.string {
                if text == nil { text = s }
                if link == nil, let range = s.range(of: #"https?://\S+"#, options: .regularExpression) {
                    link = String(s[range])
                }
            }
        }

        return (link, text)
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
    private func openMainApp(_ link: String, text: String?) async -> Bool {
        var comps = URLComponents(string: "mukbang://analyze")!
        var query = [URLQueryItem(name: "u", value: link)]
        // 캡션은 `t` 로 함께 넘긴다. URL 스킴 길이 제한이 있어 넉넉히 자른다 —
        // 앞부분만 있어도 어떤 음식인지 가려내기에는 충분하다.
        if let text, !text.isEmpty {
            query.append(URLQueryItem(name: "t", value: String(text.prefix(1200))))
        }
        comps.queryItems = query
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
