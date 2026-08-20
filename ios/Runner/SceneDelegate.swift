import Flutter
import UIKit

/// 씬 생명주기에서 **앱이 꺼져 있을 때 들어온 URL 을 살려낸다.**
///
/// 공유 익스텐션이 `mukbang://analyze?u=…` 로 앱을 여는데, 앱이 이미 떠 있으면
/// `scene(_:openURLContexts:)` 로 와서 플러그인이 받는다. 그런데 꺼져 있다가
/// 이 URL 로 켜지는 경우에는 `scene(_:willConnectTo:)` 의 `connectionOptions`
/// 안에 담겨 오고, 그 경로는 `application(_:open:options:)` 를 거치지 않는다.
/// 플러그인(app_links)은 그 앱 델리게이트 쪽만 보고 있어서 아무것도 못 받고,
/// Dart 의 `getInitialLink()` 가 null 을 돌려준다.
///
/// 실제로 그랬다 — 앱이 켜져 있을 때만 분석 화면으로 넘어가고, 꺼진 상태에서
/// 공유하면 앱만 열리고 링크가 사라졌다. 로그에 `[공유] 초기 링크: null`.
///
/// 그래서 여기서 앱 델리게이트로 한 번 흘려 준다.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    let contexts = connectionOptions.urlContexts
    guard !contexts.isEmpty else { return }

    // 다음 런루프로 미룬다. super 가 도는 시점에는 플러그인 등록이 아직
    // 안 끝나 있을 수 있어, 지금 보내면 받을 사람이 없다.
    DispatchQueue.main.async { Self.forwardToAppDelegate(contexts) }
  }

  /// 씬으로 온 URL 을 `application(_:open:options:)` 에 그대로 전달한다.
  ///
  /// Dart 가 이미 `getInitialLink()` 를 부른 뒤에 도착해도 괜찮다 — 그때는
  /// 플러그인이 스트림으로 흘려보내고, 앱이 그 스트림도 함께 듣고 있다.
  private static func forwardToAppDelegate(_ contexts: Set<UIOpenURLContext>) {
    guard let delegate = UIApplication.shared.delegate else { return }

    for context in contexts {
      var options: [UIApplication.OpenURLOptionsKey: Any] = [:]
      if let source = context.options.sourceApplication {
        options[.sourceApplication] = source
      }
      if let annotation = context.options.annotation {
        options[.annotation] = annotation
      }
      _ = delegate.application?(UIApplication.shared, open: context.url, options: options)
    }
  }
}
