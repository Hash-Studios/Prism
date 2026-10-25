import ActivityKit
import SwiftUI
import WidgetKit

struct AiGenerationLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PrismAiGenerationAttributes.self) { context in
      AiGenerationLockScreen(context: context)
        .activityBackgroundTint(Color.prismInk.opacity(0.92))
        .activitySystemActionForegroundColor(.white)
        .widgetURL(Self.url)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          AiCanvas(context: context, size: CGSize(width: 46, height: 82), cornerRadius: 12)
            .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          AiTrailing(context: context, size: 22, expanded: true)
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.center) {
          AiDetails(context: context, compact: true)
        }
      } compactLeading: {
        PrismMark(size: 20)
      } compactTrailing: {
        AiTrailing(context: context, size: 20, expanded: false)
      } minimal: {
        AiStatusBadge(context: context, size: 20)
      }
      .keylineTint(Color(argb: context.attributes.accentARGB))
      .widgetURL(Self.url)
    }
  }

  static let url = URL(string: "prism://ai")
}

private typealias AiContext = ActivityViewContext<PrismAiGenerationAttributes>

private extension AiContext {
  var accent: Color { Color(argb: attributes.accentARGB) }

  var isWaiting: Bool { state.phase == .generating && !isStale }

  var title: String {
    switch state.phase {
    case .generating: isStale ? attributes.copy.stale : attributes.copy.generating
    case .ready: attributes.copy.ready
    case .failed: attributes.copy.failed
    }
  }

  var expectedEnd: Date { state.startedAt.addingTimeInterval(PrismAiGenerationAttributes.expectedSeconds) }

  var thumbnail: UIImage? {
    guard let name = state.thumbnail, let url = PrismLiveActivityFiles.url(named: name) else { return nil }
    return UIImage(contentsOfFile: url.path)
  }
}

private struct AiGenerationLockScreen: View {
  let context: AiContext

  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      AiCanvas(context: context, size: CGSize(width: 60, height: 108), cornerRadius: 14)
      AiDetails(context: context, compact: false)
    }
    .padding(16)
  }
}

private struct AiDetails: View {
  let context: AiContext
  let compact: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 4 : 6) {
      if !compact {
        HStack(spacing: 6) {
          PrismMark(size: 14)
          Text(context.attributes.style.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.white.opacity(0.6))
            .lineLimit(1)
          Spacer(minLength: 8)
          if context.isWaiting {
            Text(timerInterval: context.state.startedAt...Date.distantFuture, countsDown: false)
              .font(.caption.monospacedDigit().weight(.medium))
              .foregroundStyle(.white.opacity(0.6))
              .multilineTextAlignment(.trailing)
              .frame(maxWidth: 48, alignment: .trailing)
          }
        }
      }
      Text(context.title)
        .font(compact ? .subheadline.weight(.semibold) : .headline)
        .foregroundStyle(.white)
        .lineLimit(1)
      Text("“\(context.attributes.prompt)”")
        .font(compact ? .caption : .subheadline)
        .foregroundStyle(.white.opacity(0.66))
        .lineLimit(compact ? 1 : 2)
      footer
        .padding(.top, compact ? 2 : 4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder private var footer: some View {
    switch context.state.phase {
    case .generating where context.isWaiting:
      ProgressView(timerInterval: context.state.startedAt...context.expectedEnd, countsDown: false) {
        EmptyView()
      } currentValueLabel: {
        EmptyView()
      }
      .progressViewStyle(.linear)
      .tint(context.accent)
    case .generating, .ready:
      HStack(spacing: 4) {
        Text(context.attributes.copy.open)
        Image(systemName: "arrow.up.forward")
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(Color.prismInk)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(context.accent, in: Capsule())
    case .failed:
      if let detail = context.state.detail {
        Text(detail)
          .font(.caption)
          .foregroundStyle(.white.opacity(0.6))
          .lineLimit(2)
      }
    }
  }
}

/// A portrait frame in the shape of the phone screen: the style's colours while it works, the wallpaper when it is ready.
private struct AiCanvas: View {
  let context: AiContext
  let size: CGSize
  let cornerRadius: CGFloat

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    ZStack {
      if context.state.phase == .ready, let image = context.thumbnail {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: size.width, height: size.height)
      } else {
        LinearGradient(colors: swatch, startPoint: .topLeading, endPoint: .bottomTrailing)
          .saturation(context.state.phase == .failed ? 0.2 : 1)
        if context.state.phase == .failed {
          Image(systemName: "exclamationmark")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white.opacity(0.9))
        } else {
          PrismCrystal()
            .frame(width: 20, height: 21)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
      }
    }
    .frame(width: size.width, height: size.height)
    .clipShape(shape)
    .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 1))
  }

  private var swatch: [Color] {
    let colors = context.attributes.swatchARGB.map(Color.init(argb:))
    return colors.count >= 2 ? colors : PrismMark.ringColors
  }
}

private struct AiTrailing: View {
  let context: AiContext
  let size: CGFloat
  let expanded: Bool

  var body: some View {
    if expanded, context.state.phase == .ready {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: size * 0.9))
        .foregroundStyle(context.accent)
    } else if context.isWaiting {
      Text(timerInterval: context.state.startedAt...Date.distantFuture, countsDown: false)
        .font(.caption.monospacedDigit().weight(.semibold))
        .foregroundStyle(context.accent)
        .multilineTextAlignment(.trailing)
        .frame(width: 38, alignment: .trailing)
    } else {
      AiStatusBadge(context: context, size: size)
    }
  }
}

private struct AiStatusBadge: View {
  let context: AiContext
  let size: CGFloat

  var body: some View {
    switch context.state.phase {
    case .generating where context.isWaiting:
      ProgressView(timerInterval: context.state.startedAt...context.expectedEnd, countsDown: false) {
        EmptyView()
      } currentValueLabel: {
        EmptyView()
      }
      .progressViewStyle(.circular)
      .tint(context.accent)
      .frame(width: size, height: size)
    case .generating:
      Image(systemName: "ellipsis.circle.fill")
        .font(.system(size: size * 0.9))
        .foregroundStyle(.white.opacity(0.7))
    case .ready:
      if let image = context.thumbnail {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: size * 0.72, height: size)
          .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
      } else {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: size * 0.9))
          .foregroundStyle(context.accent)
      }
    case .failed:
      Image(systemName: "exclamationmark.circle.fill")
        .font(.system(size: size * 0.9))
        .foregroundStyle(Color(argb: 0xFFF77E7E))
    }
  }
}
