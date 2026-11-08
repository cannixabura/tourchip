import Flutter
import NaturalLanguage
import SwiftUI
import Translation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // 訊息、公告、氣泡的「翻譯」：Dart 端 tourchip/translate（Android 用 ML Kit，見 Translator.kt）。
    // 完全在手機上進行，內容不會上傳。
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TourChipTranslate") {
      let channel = FlutterMethodChannel(name: "tourchip/translate", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "identify":
          result(identifyLanguage(args["text"] as? String ?? ""))
        case "status":
          AppleTranslator.status(source: args["source"] as? String ?? "", target: args["target"] as? String ?? "") { result($0) }
        case "translate":
          // 用了 SceneDelegate：從場景找目前的視窗
          let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }.first { $0.isKeyWindow }
          guard let window else { result(FlutterError(code: "translate", message: "no window", details: nil)); return }
          AppleTranslator.shared.translate(
            args["text"] as? String ?? "", source: args["source"] as? String ?? "", target: args["target"] as? String ?? "", in: window
          ) { text in
            if let text { result(text) } else { result(FlutterError(code: "translate", message: "failed", details: nil)) }
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}

/// 這段文字是什麼語言（例如 en、ja、zh-Hans、zh-Hant）；認不出來回傳 und
private func identifyLanguage(_ text: String) -> String {
  let recognizer = NLLanguageRecognizer()
  recognizer.processString(text)
  guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first, confidence >= 0.5 else { return "und" }
  return language.rawValue
}

/// Apple 翻譯（iOS 18）：完全在手機上進行；需要下載語言時，系統會自己問使用者。
/// 翻譯只能透過 SwiftUI 的 translationTask 取得，所以在畫面上放一個看不見的 1×1 視圖。
/// （與城市低語相同的做法）
final class AppleTranslator: ObservableObject {
  static let shared = AppleTranslator()

  struct Job {
    let text: String
    let source: Locale.Language
    let target: Locale.Language
    let completion: (String?) -> Void
  }

  @Published var configuration: TranslationSession.Configuration?
  private var queue: [Job] = []
  private var current: Job?
  private var host: UIHostingController<TranslationHost>?

  static func status(source: String, target: String, completion: @escaping (String) -> Void) {
    Task {
      let status = await LanguageAvailability().status(from: Locale.Language(identifier: source), to: Locale.Language(identifier: target))
      let text: String
      switch status {
      case .installed: text = "installed"
      case .supported: text = "supported"
      default: text = "unsupported"
      }
      await MainActor.run { completion(text) }
    }
  }

  func translate(_ text: String, source: String, target: String, in window: UIWindow, completion: @escaping (String?) -> Void) {
    attach(to: window)
    queue.append(Job(text: text, source: Locale.Language(identifier: source), target: Locale.Language(identifier: target), completion: completion))
    startNext()
  }

  private func attach(to window: UIWindow) {
    guard host == nil, let root = window.rootViewController else { return }
    let controller = UIHostingController(rootView: TranslationHost(translator: self))
    controller.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
    controller.view.backgroundColor = .clear
    controller.view.isUserInteractionEnabled = false
    root.addChild(controller)
    root.view.addSubview(controller.view)
    controller.didMove(toParent: root)
    host = controller
  }

  private func startNext() {
    guard current == nil, !queue.isEmpty else { return }
    let job = queue.removeFirst()
    current = job
    if let config = configuration, config.source == job.source, config.target == job.target {
      configuration?.invalidate()  // 同一組語言：重新觸發 translationTask
    } else {
      configuration = TranslationSession.Configuration(source: job.source, target: job.target)
    }
  }

  @MainActor
  func run(_ session: TranslationSession) async {
    guard let job = current else { return }
    var out: String?
    do { out = try await session.translate(job.text).targetText } catch { out = nil }
    current = nil
    job.completion(out)
    startNext()
  }
}

struct TranslationHost: View {
  @ObservedObject var translator: AppleTranslator

  var body: some View {
    Color.clear
      .frame(width: 1, height: 1)
      .translationTask(translator.configuration) { session in
        await translator.run(session)
      }
  }
}
