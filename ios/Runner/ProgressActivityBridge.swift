import ActivityKit
import Flutter
import UIKit

final class ProgressActivityBridge {
  private var channel: FlutterMethodChannel
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "quizmind/progress", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "sync" else { result(FlutterMethodNotImplemented); return }
      guard #available(iOS 16.2, *),
            let args = call.arguments as? [String: Any] else { result(nil); return }
      Task { @MainActor in
        await self?.sync(args)
        result(nil)
      }
    }
    NotificationCenter.default.addObserver(self, selector: #selector(enteredBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(enteredForeground),
      name: UIApplication.willEnterForegroundNotification, object: nil)
  }

  @objc private func enteredBackground() {
    guard #available(iOS 16.2, *), !Activity<ProgressAttributes>.activities.isEmpty,
          backgroundTask == .invalid else { return }
    // shortcut: iOS grants only a short runtime; use APNs for updates after suspension.
    backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "QuizMind progress") { [weak self] in
      self?.finishBackgroundTask()
    }
  }

  @objc private func enteredForeground() { finishBackgroundTask() }

  private func finishBackgroundTask() {
    if backgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTask)
      backgroundTask = .invalid
    }
  }

  @available(iOS 16.2, *)
  @MainActor private func sync(_ args: [String: Any]) async {
    let count = args["count"] as? Int ?? 0
    let reset = args["reset"] as? Bool ?? false
    let state = ProgressAttributes.ContentState(
      status: args["status"] as? String ?? "Đang xử lý",
      count: count, finished: count == 0, failed: args["failed"] as? Bool ?? false)
    let content = ActivityContent(state: state, staleDate: count > 0 ? Date().addingTimeInterval(30) : nil)
    let activities = Activity<ProgressAttributes>.activities
    if count == 0 || reset {
      for activity in activities {
        await activity.end(content, dismissalPolicy: reset ? .immediate : .after(Date().addingTimeInterval(20)))
      }
      finishBackgroundTask()
      return
    }
    if let activity = activities.first {
      await activity.update(content)
    } else if ActivityAuthorizationInfo().areActivitiesEnabled,
              UIApplication.shared.applicationState != .background {
      _ = try? Activity.request(attributes: ProgressAttributes(title: "QuizMind AI"), content: content, pushType: nil)
    }
  }
}
