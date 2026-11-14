import ActivityKit
import Foundation

/// 鎖定畫面的集合倒數（Runner 與 TourLive 擴充共用）。文字都由 App 端翻譯好再傳進來。
struct GatherAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// 集合時間
    var at: Date
    /// 「14:30 集合」
    var title: String
    /// 集合點
    var place: String
  }

  /// 團名
  var group: String
  /// 團色（0xRRGGBB）
  var color: Int
  /// 「現在集合」（倒數到 0 之後顯示）
  var nowText: String
}
