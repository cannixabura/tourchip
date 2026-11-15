import ActivityKit
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

    // 鎖定畫面的集合倒數（Live Activity，見 TourLive）：Dart 端 tourchip/live（lib/tour/live_countdown.dart）
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TourChipLive") {
      let channel = FlutterMethodChannel(name: "tourchip/live", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "start":
          GatherLive.start(args) { ok in result(ok) }
        case "end":
          GatherLive.end()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

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

/// 集合倒數的即時動態：同時只留一個；集合時間過 30 分鐘變成過期（App 下次同步時收起）
enum GatherLive {
  /// done(true)：已經顯示（新開或更新）；false：使用者關掉即時動態，或系統不讓開（例如 App 在背景）
  static func start(_ args: [String: Any], done: @escaping (Bool) -> Void) {
    let finish = { (ok: Bool) in DispatchQueue.main.async { done(ok) } }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { NSLog("GatherLive disabled"); finish(false); return }
    let at = Date(timeIntervalSince1970: (args["at"] as? Double ?? Double(args["at"] as? Int ?? 0)) / 1000)
    let state = GatherAttributes.ContentState(at: at, title: args["title"] as? String ?? "", place: args["place"] as? String ?? "")
    let attrs = GatherAttributes(group: args["group"] as? String ?? "", color: args["color"] as? Int ?? 0xB44CFF, nowText: args["now"] as? String ?? "")
    let stale = at.addingTimeInterval(30 * 60)
    Task {
      // 同一團、同樣的外觀：更新內容就好；否則結束舊的再開新的
      let current = Activity<GatherAttributes>.activities
      if let a = current.first, current.count == 1, a.attributes.group == attrs.group, a.attributes.color == attrs.color, a.attributes.nowText == attrs.nowText {
        await a.update(ActivityContent(state: state, staleDate: stale))
        finish(true)
        return
      }
      for a in current { await a.end(nil, dismissalPolicy: .immediate) }
      do {
        _ = try Activity.request(attributes: attrs, content: ActivityContent(state: state, staleDate: stale), pushType: nil)
        finish(true)
      } catch {
        NSLog("GatherLive request failed: \(error)")
        finish(false)
      }
    }
  }

  static func end() {
    Task {
      for a in Activity<GatherAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
    }
  }
}
