# Chat tạo bộ đề — 2026-11-13

## Luồng và quyết định giao diện

- Điểm vào: nút robot nổi cố định góc phải, phía trên thanh điều hướng ở cả bốn tab chính → Chat với AI.
- Tái sử dụng PageBody, PageTitle, panel, ChoicePill, BottomActions và màu của app. Màn hình con dùng nút quay lại, không có logo header.
- Gửi chủ đề cùng số câu đã chọn (5/10/15) đến POST /api/chat. Tác vụ chạy nền qua hàng đợi hiện có; khóa gửi trong khi chờ, hiện kết quả/lỗi và nút mở bộ đề.
- Backend lưu bộ đề và yêu cầu gốc thành tài liệu để tương thích thư viện/làm bài hiện tại. Nội dung AI tạo có sourceType=ai, không được trình bày như trích dẫn tài liệu.
- Phiên bản này tạo một bộ đề cho mỗi tin nhắn, chưa gửi lịch sử hội thoại cho AI và chưa lưu hội thoại qua lần mở app.

## Kiểm tra

- `python3 -m unittest discover -s server -p 'test*.py'`: 32 tests pass. Bao phủ xác thực route chat, dữ liệu đầu vào, requestId lặp lại, lưu kết quả sau restart và từ chối lựa chọn trùng.
- `flutter analyze`: không có issue.
- `flutter test test/remote_api_test.dart`: 9 tests pass. Chat widget kiểm tra prompt ngắn, khóa input lúc đang tạo và mở QuizScreen sau khi ready.
- Render widget ở 393×852 và 1280×900: không có layout exception. Đã xem ảnh chat-393.png và chat-1280.png; bố cục và ngắt dòng dễ đọc. Ảnh dùng Arial trong test thay cho font mặc định nền tảng, MaterialIcons thật đã được nạp.
- Chạy Flutter test bằng cách tạm chuyển launcher executable `build` ra thư mục tạm rồi khôi phục bằng trap; không thay đổi launcher.

## Giới hạn xác minh

- Chưa gọi AI upstream thật, chưa cài bản mới lên thiết bị hoặc khởi động lại relay đang chạy.
- Ảnh là widget render cho bố cục; bàn phím được mô phỏng bằng viewInsets, chưa xác minh bàn phím trên thiết bị thực.

## Sửa bàn phím và nút bot nổi — 2026-11-13

- Hướng thiết kế: giữ nguyên màu xanh, font, RobotArt và các thành phần sẵn có; thay card chat bằng FloatingActionButton tròn 56 px với ảnh robot 48 px, tooltip “Chat với AI”. Neo phải, cách cạnh 16 px và nằm trên thanh điều hướng. Chừa thêm 72 px cuối nội dung để cuộn các mục cuối ra khỏi nút.
- Composer trong ChatScreen bù viewInsets.bottom ngay tại thanh đáy, không thay BottomActions dùng chung; nội dung vẫn cuộn độc lập, ô nhập tối đa ba dòng.
- Regression: ô nhập/nút gửi nằm trên bàn phím khi mở, gõ nhiều dòng và khi đóng bàn phím ở 393×852, 1280×900, 852×393; nút bot cố định khi cuộn, hiện trên cả bốn tab và mở đúng ChatScreen.
- Rà soát ảnh ở 393×852 và 1280×852: bot-393.png, bot-1280.png, keyboard-393.png, keyboard-1280.png. Ảnh bàn phím dành 320 px trắng mô phỏng vùng bàn phím hệ thống; không vẽ các phím. Dùng Arial trong widget test và MaterialIcons thật; không phải ảnh thiết bị iOS.
- Design review: giữ bố cục tham chiếu và thương hiệu hiện tại; nút bot có vùng chạm chuẩn, không che thanh điều hướng, composer không bị che và không có overflow ở các kích thước kiểm tra. Không cần mockup mới cho sửa hành vi và thay lối vào này.
- Test tải tài liệu trong app_test.dart được cập nhật nhãn mẫu hiện hành và dùng UploadZone để xác minh đã mở màn import.
- Kết quả xác minh sau sửa: `flutter analyze --no-pub` không có issue; toàn bộ `flutter test --no-pub` đạt 54/54. Launcher `build` đã được khôi phục.


## Chat theo mẫu mới — 2026-11-13

- Đã đối chiếu bản render widget 393×852 và 1280×900 với mẫu `docs/design/references/chat-ai.png`. Ảnh được cập nhật tại `chat-393.png`, `chat-1280.png`; script capture dành cho macOS là `capture_test.dart.example` (chép tạm vào `test/` khi cần; Arial tại đường dẫn hệ thống, MaterialIcons và robot asset thật). Emoji trong bản capture thiếu glyph; artwork gốc không có nên dùng robot/icon hiện hành. Đây là review thủ công theo skill design-review dạng catalog, không tuyên bố chạy bộ audit upstream.
- Test mới xác minh ba kích thước 393×852, 1280×900, 320×740 (cỡ chữ 1,25 trên màn nhỏ): chọn 15 câu, điền gợi ý Sinh học, nội dung đúng số câu và không gửi API trước khi nhấn gửi.
- Regression giữ vị trí ô nhập/nút gửi trên bàn phím ở điện thoại, desktop và landscape; prompt ngắn bị từ chối, input khóa lúc tạo, không gửi trùng và mở đề khi ready. Phần hướng dẫn ẩn khi đã bắt đầu hội thoại để trạng thái không nằm ngoài vùng nhìn.
- Analyzer sạch. Bộ test Flutter thường quy đạt 56 test; thêm 2 lần render capture đạt riêng. Launcher executable `build` được khôi phục sau kiểm tra.
- Chưa cài bản này lên iPhone thật, chưa kiểm tra bàn phím phần cứng/iOS hoặc AI upstream. Không sửa relay và không chạy launcher triển khai.
