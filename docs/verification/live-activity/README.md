# iOS Live Activity verification

- ActivityKit / WidgetKit extension builds successfully for iOS simulator and signed iOS device release.
- Simulator: iPhone 17, iOS 27. A synthetic extracting task (no AI request) was started through the real Flutter method channel, then the app was backgrounded by opening Settings. `compact.png` captures its native Dynamic Island outside QuizMind.
- Reviewed compact layout: document symbol and progress indicator fit the island, with the existing green accent. Expanded and Lock Screen layouts are implemented but not visually verified.
- Focused Flutter suite: **17 passed** (`task_progress_test.dart`, `remote_api_test.dart`); targeted analyzer: **No issues found**. Tests use an isolated source copy under `.local/progress-test-workspace` because the repository has an executable `./build` launcher where Flutter test expects a directory.
- Coverage includes historical/orphan activity cleanup, stages, no document content in payload, overlapping actions/failures, offline/reset, channel failure, and a fresh backend snapshot after overlapping refresh.
- Signed release installed and launched successfully on the connected iPhone 14 Pro Max (iOS 17.7.1). The app and embedded extension passed `codesign --verify --deep --strict`. A real document task on that phone has not been exercised.
- No backend AI job or document mutation was used for the native preview.

## Runtime limits

The app requests a short UIKit background execution interval. It does not promise continuous Dart polling while suspended. After 30 seconds without a state update, the activity displays a refresh prompt. APNs is not configured; remote completion updates after suspension remain unavailable. Native activity UI never claims a fabricated percentage.

Apple reference: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
