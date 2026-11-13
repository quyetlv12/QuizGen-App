import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ProgressActivityWidget: Widget {
  private let accent = Color(red: 0, green: 0.56, blue: 0.13)

  var body: some WidgetConfiguration {
    ActivityConfiguration(for: ProgressAttributes.self) { context in
      HStack(spacing: 14) {
        Image(systemName: symbol(context.state)).font(.title2).foregroundStyle(accent)
        VStack(alignment: .leading, spacing: 5) {
          Text(context.attributes.title).font(.headline)
          Text(status(context)).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
        }
        Spacer(minLength: 4)
        indicator(context)
      }
      .padding(20)
      .activityBackgroundTint(Color(.systemBackground))
      .activitySystemActionForegroundColor(accent)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(context.attributes.title, systemImage: symbol(context.state))
            .font(.headline).foregroundStyle(accent)
        }
        DynamicIslandExpandedRegion(.trailing) { indicator(context) }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            Text(status(context)).font(.subheadline).lineLimit(2)
            Spacer()
            if context.state.count > 1 {
              Text("\(context.state.count) tác vụ").font(.caption).foregroundStyle(.secondary)
            }
          }.padding(.top, 6)
        }
      } compactLeading: {
        Image(systemName: symbol(context.state)).foregroundStyle(accent)
      } compactTrailing: {
        indicator(context).frame(width: 22)
      } minimal: {
        Image(systemName: symbol(context.state)).foregroundStyle(accent)
      }
      .keylineTint(accent)
    }
  }

  private func symbol(_ state: ProgressAttributes.ContentState) -> String {
    state.finished ? (state.failed ? "exclamationmark.circle" : "checkmark.circle.fill") : "doc.text.magnifyingglass"
  }

  private func status(_ context: ActivityViewContext<ProgressAttributes>) -> String {
    context.isStale && !context.state.finished ? "Mở app để cập nhật tiến trình" : context.state.status
  }

  @ViewBuilder private func indicator(_ context: ActivityViewContext<ProgressAttributes>) -> some View {
    if context.state.finished {
      Image(systemName: symbol(context.state)).foregroundStyle(context.state.failed ? .red : accent)
    } else if context.isStale {
      Image(systemName: "arrow.clockwise").foregroundStyle(.secondary)
    } else {
      ProgressView().tint(accent).accessibilityLabel("Đang xử lý")
    }
  }
}
