import ActivityKit
import SwiftUI
import WidgetKit

struct ReviewQueueLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PrismReviewAttributes.self) { context in
      ReviewLockScreen(state: context.state)
        .activityBackgroundTint(Color.prismInk.opacity(0.92))
        .activitySystemActionForegroundColor(.white)
        .widgetURL(Self.url)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          ReviewCount(pending: context.state.pending, size: 34, label: false)
            .padding(.leading, 6)
        }
        DynamicIslandExpandedRegion(.trailing) {
          ReviewButton()
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 2) {
            Text(ReviewCount.label(context.state.pending))
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white.opacity(0.8))
            ReviewDetail(state: context.state)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 6)
        }
      } compactLeading: {
        PrismMark(size: 20)
      } compactTrailing: {
        Text(context.state.pending, format: .number)
          .font(.system(.subheadline, design: .rounded).weight(.bold))
          .monospacedDigit()
          .contentTransition(.numericText())
          .foregroundStyle(.white)
      } minimal: {
        ZStack {
          PrismMark(size: 22, ringOpacity: 0.9, crystal: false)
          Text(context.state.pending > 99 ? "99+" : "\(context.state.pending)")
            .font(.system(size: context.state.pending > 9 ? 9 : 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
        }
      }
      .keylineTint(Color(argb: 0xFFB65CF0))
      .widgetURL(Self.url)
    }
  }

  static let url = URL(string: "prism://admin-review/swipe")
}

private struct ReviewLockScreen: View {
  let state: PrismReviewAttributes.ContentState

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          PrismMark(size: 14)
          Text("REVIEW QUEUE")
            .font(.caption2.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.white.opacity(0.6))
        }
        ReviewCount(pending: state.pending, size: 40)
        ReviewDetail(state: state)
      }
      Spacer(minLength: 8)
      VStack(spacing: 10) {
        QueueStack()
        ReviewButton()
      }
    }
    .padding(16)
  }
}

private struct ReviewCount: View {
  let pending: Int
  let size: CGFloat
  var label = true

  static func label(_ pending: Int) -> String { pending == 1 ? "wall waiting" : "walls waiting" }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(pending, format: .number)
        .font(.system(size: size, weight: .bold, design: .rounded))
        .monospacedDigit()
        .contentTransition(.numericText())
        .foregroundStyle(.white)
      if label {
        Text(Self.label(pending))
          .font(.headline)
          .foregroundStyle(.white.opacity(0.75))
          .lineLimit(1)
      }
    }
  }
}

private struct ReviewDetail: View {
  let state: PrismReviewAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      if let by = state.newestBy {
        Text("Newest from \(by)")
      }
      if let oldestAt = state.oldestAt {
        Text("Oldest waiting \(Date(timeIntervalSince1970: oldestAt), style: .relative)")
      }
    }
    .lineLimit(1)
    .font(.caption)
    .foregroundStyle(.white.opacity(0.6))
  }
}

private struct ReviewButton: View {
  var body: some View {
    HStack(spacing: 4) {
      Text("Review")
      Image(systemName: "chevron.right")
    }
    .font(.caption.weight(.bold))
    .foregroundStyle(Color.prismInk)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(.white, in: Capsule())
  }
}

/// Three fanned wallpaper cards in the logo's colours: the queue as a pile to swipe through.
private struct QueueStack: View {
  private static let cards: [(Color, Color, Double)] = [
    (Color(argb: 0xFF4FE3EE), Color(argb: 0xFF7CF0C0), -12),
    (Color(argb: 0xFFF9A24E), Color(argb: 0xFFF77E7E), 10),
    (Color(argb: 0xFFB65CF0), Color(argb: 0xFFE45BD6), 0),
  ]

  var body: some View {
    ZStack {
      ForEach(Self.cards.indices, id: \.self) { index in
        let card = Self.cards[index]
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .fill(LinearGradient(colors: [card.0, card.1], startPoint: .topLeading, endPoint: .bottomTrailing))
          .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
          .frame(width: 30, height: 52)
          .rotationEffect(.degrees(card.2), anchor: .bottom)
          .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
      }
    }
    .frame(width: 60, height: 58)
  }
}
