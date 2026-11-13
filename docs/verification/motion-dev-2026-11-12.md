# QuizMind — bằng chứng triển khai motion 12/11/2026

Đường dẫn dự án: `/Users/quyetdev/Documents/QuizMind AI`. Người thực hiện: Kai (dev). Đối chiếu [brief QM-MOTION](../product/motion-upgrade-2026-11-12.md) và [thiết kế hiện có](../design/DESIGN.md). Đây là bằng chứng tự kiểm tra của người triển khai, chưa phải nghiệm thu/QA độc lập.

## Đầu vào, giả định và phạm vi

Yêu cầu: nâng cấp animation khi bấm chuyển màn hình. Chọn chuyển động ngắn, tinh tế, giữ giao diện xanh/mint. Tham số cuối ở [motion spec](../design/motion-2026-11-12.md).

Không có Git trong dự án; dùng SHA-256 trước/sau và [patch](motion-2026-11-12/implementation.patch) để nhận diện phiên bản. Chỉ sửa `lib/theme.dart`, `lib/ui.dart`, `lib/main.dart`; thêm `test/motion_test.dart` và tài liệu/bằng chứng mới. `test/app_test.dart`, `lib/api.dart` và toàn bộ nguồn server trong baseline giữ hash cũ. Không sửa brief PM, backend, cấu hình ECC; không chạy hook/script ECC. Không ghi đè file thuộc teammate.

Thiếu bằng chứng: chưa quan sát animation bản mới trên simulator/thiết bị thật, chưa quay video hoặc đo FPS/frame timing. Không giả định build thành công đồng nghĩa UX được nghiệm thu.

## Mã và hành vi đã triển khai

- `lib/theme.dart`: `AppPageTransitionsBuilder` đặt push 260 ms, pop 220 ms; vẫn dùng Cupertino để giữ back gesture. `AppPageRoute` tôn trọng giảm chuyển động trước điều hướng và snap controller đang chạy sau frame hiện tại; không giành controller khi người dùng đang giữ back gesture. Cấu trúc transition không đổi khi bật/tắt giảm chuyển động.
- `lib/ui.dart`: tab fade tuần tự 60/160 ms, offset dọc tối đa 6 px, giữ IndexedStack/RepaintBoundary. Thay vòng async chờ animation bằng retarget theo status: cập nhật tab cuối ở opacity 0, đảo hướng từ giá trị hiện tại khi có chọn mới. Chặn pointer/focus/semantics của tab body đang mờ; thanh điều hướng vẫn nhận bấm. Lắng nghe giảm chuyển động qua didChangeDependencies kể cả khi index không đổi.
- `lib/main.dart`: đổi cả bốn callsite route (openScreen, nộp bài → kết quả, làm lại đề, quay về Home) sang AppPageRoute. Thêm TextEditingController có dispose cho ô tìm tài liệu để giữ chữ khi ListView tái tạo ô nhập sau cuộn xa. Đây là chỉnh sửa cần cho AC3; không thay bộ lọc hoặc API.
- `test/motion_test.dart`: 10 test mới cho chuyển tab/route, thao tác nhanh, accessibility, gesture và dữ liệu. Giữ nguyên 8 test hiện có.

## Lỗi tái hiện và bằng chứng trước/sau

1. Chọn tab mới, pump 30 ms trong fade-out, chỉ bật `disableAnimations` mà không đổi index, rồi bấm nút của tab mới. Trước sửa: không tìm thấy `Latest tab`; [regression-before.log](motion-2026-11-12/regression-before.log), exit 1. Cơ chế cũ chỉ xử lý giảm chuyển động khi index thay đổi. Test cùng tên trong suite cuối đã qua.
2. Nhập `Sinh` ở thư viện có 20 tài liệu fixture, bỏ focus, cuộn xuống, đổi Cá nhân rồi quay lại Tài liệu và trở về đầu danh sách. Test AC3 thấy nội dung ô tìm kiếm trống; [form-investigation.log](motion-2026-11-12/form-investigation.log), exit 1. Ô nhập trước đó không có controller sở hữu lâu dài. Sau thêm controller, test thư viện/form/scroll qua, gồm 24 lần bấm tab cách nhau 10 ms.
3. Kiểm tra nghi ngờ mất State khi đổi nhánh transition của route cũ **không tái hiện lỗi**: test form baseline vẫn qua. Việc giữ cấu trúc Cupertino là lựa chọn triển khai, không được ghi là lỗi dữ liệu đã xác nhận.

Các lần dựng test ban đầu có lỗi import/await và locator, đã sửa. Chỉ các gate cuối dưới đây là kết quả nghiệm chứng bản bàn giao; log trước sửa giữ nguyên để thể hiện lỗi tái hiện.

## Đối chiếu từng AC

| AC | Bằng chứng dev mới | Trạng thái / giới hạn |
| --- | --- | --- |
| AC1 — Push/pop/replacement ngắn, quay lại đúng, giữ iOS back | Test iOS xác nhận route animation đang ở giữa tại 100 ms; duration 260/220 ms; back swipe hủy giữ route, swipe hoàn tất về root đúng State/scroll/form. Test replacement cả bình thường và giảm chuyển động. | Đạt kiểm tra widget; cảm nhận chuyển động trên màn hình thật và gesture thiết bị chờ QA. |
| AC2 — Tab không chồng chữ/trượt xa, tap nhanh lấy tab cuối | Test xác nhận chỉ tab cũ trước fade-out, chỉ tab mới sau đổi; hoàn tất và nhận bấm ở 222 ms (220 ms danh nghĩa, cho phép một frame). Test retarget fade-out/fade-in, quay lại tab đang hiện, dispose giữa chuyển; 24 bấm thật qua StudyNavigation cách nhau 10 ms về đúng tab cuối. Offset giới hạn 6 px qua đọc mã. | Đạt kiểm tra widget; chưa kiểm tra video/pixel overlap hoặc đo độ mượt. |
| AC3 — Giữ scroll/form/đáp án nháp | Test thật HomeScreen giữ vị trí cuộn và chữ tìm kiếm sau đổi tab; địa chỉ chưa lưu giữ qua tab và route push/pop. QuizScreen giữ State, đáp án và chuỗi SharedPreferences nháp sau mở/đóng route phủ. Các test nộp bài/draft cũ cũng qua. | Đạt phạm vi test; chưa chạy lại E2E AI/OCR. Replacement/remove vẫn dispose route theo chức năng gốc. |
| AC4 — Giảm chuyển động giữa animation, nội dung đúng/nhận bấm | Test bật giữa fade-out/fade-in, push, pop và replacement; kiểm tra tương tác ngay, controller completed, bật lại rồi điều hướng tiếp. Test bật trong back gesture xác nhận không cướp gesture, hủy rồi bấm được. | Đạt widget qua MediaQuery; chưa bật cài đặt Reduce Motion của iOS thật giữa gesture. |
| AC5 — Format/analyze/test/build simulator mới | Các lệnh bên dưới đều có exit code 0 từ lần chạy mới, build Runner.app thành công. | Đạt gate dev. |
| AC6 — Linh kiểm chứng độc lập, PM đọc hiện vật | Chưa có kết quả QA từ Linh trong lượt này. | **Chưa kiểm chứng / chưa nghiệm thu.** PM cần đọc hiện vật và chuyển Linh. |

## Lệnh đã chạy và kết quả mới

Chạy trong `/Users/quyetdev/Documents/QuizMind AI` với Flutter 3.47.5, Dart 3.13.4, macOS. Thời điểm hoàn thiện báo cáo: 2026-11-12T13:04:28+07:00.

| Lệnh | Kết quả cuối | Log |
| --- | --- | --- |
| `dart format --output=none --set-exit-if-changed lib/theme.dart lib/ui.dart lib/main.dart test/motion_test.dart` | 0 thay đổi, exit 0 | [format.log](motion-2026-11-12/format.log) |
| `flutter analyze --no-pub` | No issues found, exit 0 | [analyze.log](motion-2026-11-12/analyze.log) |
| `flutter test --no-pub test/motion_test.dart --reporter expanded` | 10/10 qua, exit 0 | [focused-test.log](motion-2026-11-12/focused-test.log) |
| `flutter test --no-pub --reporter expanded` | 18/18 qua, exit 0 | [test.log](motion-2026-11-12/test.log) |
| `flutter build ios --simulator --debug --no-pub` | Built build/ios/iphonesimulator/Runner.app, Xcode build 11,5 s, exit 0 | [ios-build.log](motion-2026-11-12/ios-build.log) |

Không chạy Python/backend test, Android build, macOS build, device test hoặc UI automation simulator trong lượt này. Phạm vi nguồn backend không thay đổi. Không có automation tạm của bot cần dừng (đã kiểm tra trước bàn giao).

## Nhận diện phiên bản không dùng commit

Baseline trước sửa: [baseline-hashes.json](motion-2026-11-12/baseline-hashes.json). Manifest bản cuối gồm hash nguồn, tài liệu, log và các phần quan trọng của build: [version-hashes.json](motion-2026-11-12/version-hashes.json). Diff bản cuối: [implementation.patch](motion-2026-11-12/implementation.patch).

| File | SHA-256 bản bàn giao |
| --- | --- |
| `lib/theme.dart` | `3e65d9479c2858e82329128fb93e5aeb5c14b89c75c3649fc678d7b69de625e6` |
| `lib/ui.dart` | `cf6b834db19b6e2ed9252a2d97e11086162ea214e2cccc179e0aabc6246d7b89` |
| `lib/main.dart` | `ffda6e1bb9979cf593991d102fadd0eabdad98894c49311da7f78c432a6cda5d` |
| `test/motion_test.dart` | `1e6aaf63e8d058ecfffcd2721c3cf842a474432d915a5aad8a5e678e7f47ab50` |
| `test/app_test.dart` | `67c9030e62ccf9b5b54bbe65c0eb50b63d15fd00d44c0d5e4a7543611504ea6f` |

Nguồn thay đổi so với baseline: `lib/ui.dart`, `lib/main.dart`, `lib/theme.dart`. Tệp test mới: `test/motion_test.dart`. Không có commit để báo.

## Cách chạy và phần cần bàn giao

```sh
cd '/Users/quyetdev/Documents/QuizMind AI'
flutter test --no-pub --reporter expanded
flutter devices
flutter run --no-pub -d <simulator-id>
```

Để xem dữ liệu thật, chạy relay theo README. Test mới dùng fixture, không cần relay và không gửi yêu cầu AI.

Linh cần QA độc lập AC1–AC6, ưu tiên: bấm tab nhanh trong cả hai pha, cuộn/nhập rồi đi-về route, gesture back hủy/hoàn tất, bật Reduce Motion của hệ điều hành giữa animation và giữa gesture, kiểm tra nội dung/khả năng bấm sau đó. Chụp/quay bằng chứng bản có hash trên, ghi simulator/device/OS và hạn chế; không lấy lời báo xong hoặc build log làm bằng chứng UI.
