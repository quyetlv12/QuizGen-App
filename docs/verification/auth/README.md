# Kiểm chứng tài khoản — 2026-11-14

## Kiểm tra trước khi push

- Đăng nhập/đăng ký chọn tab Trang chủ: 2 test điều hướng đạt.
- Chạy lại toàn bộ `test/auth_test.dart`: 7 đạt, 3 lỗi kiểm tra bàn phím ở 320/393/1280px (tap Đăng ký không trúng, sau đó không tìm thấy form). Bộ auth hiện tại chưa sạch.
- `flutter analyze --no-pub`: không có issue. Backend: 68 test đạt.
- Đã build/cài/mở bản iOS release trên iPhone qua Wi-Fi; chưa kiểm tra đăng nhập thực trên máy. APK release đã tạo và kiểm tra chữ ký v2; chưa chạy trên Android.

## UI theo ảnh người dùng (kết quả mới nhất)

- 10/10 auth tests passed, including login/register to Home, logout, validation, default user role, and keyboard layouts at 320/393/1280px.
- Flutter analyze: no issues. git diff --check: passed.
- Updated login/register PNGs are actual widget-test renders. Compared login 320/393 and register 393/1280 with docs/design/references/auth-user-reference.png.
- No backend changes in this UI pass. Backend tests and iOS build listed below belong to the earlier auth implementation; iOS was not rebuilt after this redesign. No live service or physical-device verification.

## Kết quả vòng triển khai auth trước

- `flutter analyze --no-pub`: đạt, không có issue.
- `python3 -m unittest discover -s server -p 'test_*.py'`: 65 test đạt, gồm 7 test tài khoản (vai trò, validation, hash, hết hạn/thu hồi, HTTP guard và cách ly dữ liệu).
- `CAPTURE_AUTH=1 flutter test --no-pub test/auth_test.dart`: 8 test đạt; kiểm tra header, lưu/khôi phục/xóa phiên, response cũ, lỗi mạng/login, form/role và responsive/bàn phím.
- `flutter build ios --simulator --debug --no-codesign --no-pub`: build thành công. Plugin secure storage dùng CocoaPods fallback; có cảnh báo chưa hỗ trợ SPM.
- `git diff --check`: đạt.

Flutter test/build chạy trong bản sao `/tmp/quizmind-auth-qa` vì repository có launcher dạng file tên `build`, xung đột thư mục asset test mà Flutter tạo. Không đổi/xóa launcher. Đồng bộ lib/test hiện tại vào bản sao trước lần test cuối. iOS build hoàn thành trước thay đổi cuối chỉ thêm thông báo trạng thái khôi phục phiên và sửa font của ảnh test.

Ảnh `login-{320,393,1280}.png` và `register-{320,393,1280}.png` là render Flutter widget test thực, Arial được nạp riêng để chụp chữ tiếng Việt; không phải ảnh simulator. Đã kiểm tra trực quan register 320/393 và login 1280, đối chiếu mockup trong docs/design/references. Test cả ba kích thước không ghi nhận overflow khi mở bàn phím.

Bộ Flutter đầy đủ: **98 đạt, 6 lỗi**:

- document_actions: vertical scrolling and tap navigation survive, home shares swipe.
- remote_api: chat validates prompt, blocks duplicate sends and opens generated quiz (vẫn tìm text “AI đang xử lý…” đã đổi).
- document_options: import requires a typed name; upload mandatory name ở 320 và 800; scan callback reveals name (pumpAndSettle timeout).

Bản sao đối chiếu gỡ phần auth khỏi controller/main, giữ UI hiện hành, tái hiện cả 6 lỗi và thêm 2 lỗi timing extraction. Đây là baseline dựng lại, không phải checkout gốc sạch; bằng chứng gợi ý lỗi ngoài auth, không chứng minh bộ test hiện hành đã sạch. Không sửa các luồng ngoài phạm vi.

Chưa triển khai relay thật, cài điện thoại hay kiểm chứng Keychain trên thiết bị thật. Không commit/push. Thư viện trước tài khoản được giữ nguyên, chưa có migration tự động.
