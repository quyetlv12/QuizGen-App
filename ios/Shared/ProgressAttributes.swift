import ActivityKit

@available(iOS 16.2, *)
struct ProgressAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var status: String
    var count: Int
    var finished: Bool
    var failed: Bool
  }
  var title: String
}
