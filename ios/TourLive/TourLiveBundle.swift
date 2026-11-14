import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TourLiveBundle: WidgetBundle {
  var body: some Widget {
    GatherLiveActivity()
  }
}

private extension Color {
  init(rgb: Int) {
    self.init(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
  }
}

private let ink = Color(red: 0.95, green: 0.94, blue: 1.0)
private let muted = Color(red: 0.73, green: 0.71, blue: 0.84)
private let night = Color(red: 0.03, green: 0.04, blue: 0.12)

/// 倒數：到點之前倒數，到點之後顯示「現在集合」
private struct Countdown: View {
  let at: Date
  let nowText: String
  var size: CGFloat = 34
  var body: some View {
    if at > Date() {
      Text(timerInterval: Date()...at, countsDown: true)
        .font(.system(size: size, weight: .semibold).monospacedDigit())
        .foregroundStyle(ink)
        .multilineTextAlignment(.trailing)
    } else {
      Text(nowText).font(.system(size: size * 0.6, weight: .semibold)).foregroundStyle(ink)
    }
  }
}

struct GatherLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: GatherAttributes.self) { ctx in
      // 鎖定畫面
      let tint = Color(rgb: ctx.attributes.color)
      HStack(alignment: .center, spacing: 12) {
        Image(systemName: "flag.fill").font(.system(size: 22)).foregroundStyle(tint)
        VStack(alignment: .leading, spacing: 2) {
          Text(ctx.attributes.group).font(.caption).foregroundStyle(muted).lineLimit(1)
          Text(ctx.state.title).font(.headline).foregroundStyle(ink).lineLimit(1)
          Text(ctx.state.place).font(.subheadline).foregroundStyle(ink.opacity(0.85)).lineLimit(1)
        }
        Spacer(minLength: 8)
        Countdown(at: ctx.state.at, nowText: ctx.attributes.nowText).frame(maxWidth: 120, alignment: .trailing)
      }
      .padding(16)
      .activityBackgroundTint(night.opacity(0.85))
      .activitySystemActionForegroundColor(ink)
    } dynamicIsland: { ctx in
      let tint = Color(rgb: ctx.attributes.color)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "flag.fill").font(.title2).foregroundStyle(tint).padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Countdown(at: ctx.state.at, nowText: ctx.attributes.nowText, size: 26).frame(maxWidth: 110, alignment: .trailing)
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 2) {
            Text(ctx.state.title).font(.headline).lineLimit(1)
            Text(ctx.state.place).font(.caption).foregroundStyle(muted).lineLimit(1)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(ctx.attributes.group).font(.caption2).foregroundStyle(muted).lineLimit(1)
        }
      } compactLeading: {
        Image(systemName: "flag.fill").foregroundStyle(tint)
      } compactTrailing: {
        Text(timerInterval: Date()...max(Date(), ctx.state.at), countsDown: true)
          .monospacedDigit().frame(maxWidth: 52).foregroundStyle(tint)
      } minimal: {
        Image(systemName: "flag.fill").foregroundStyle(tint)
      }
      .keylineTint(tint)
    }
  }
}
