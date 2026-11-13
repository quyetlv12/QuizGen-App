# Kiểm tra chỉ báo AI đang xử lý

- Hai kiểm tra `ai_thinking_test.dart` đạt: chấm chuyển động, giải phóng ticker, bật/tắt Giảm chuyển động.
- Hai kiểm tra robot launcher hiện có đạt; analyzer cho các file thay đổi không có lỗi.
- Render màn ChatScreen với API giả đang chờ, không tạo tác vụ AI thật: `chat-393.png` và `chat-1280.png`. Đã xem cả hai ảnh: robot và bong bóng chấm thẳng hàng, đúng token mint/xanh, không tràn bố cục.
- Script chụp: `capture_test.dart.example`. Chạy trong workspace test riêng vì file lệnh `./build` trùng thư mục output mặc định của Flutter test. Font Arial chỉ dùng cho ảnh kiểm tra; app giữ font hiện có.
- Build iOS simulator thành công; cài và mở `dev.quyet.quizmind` trên iPhone 17 simulator. Chưa cài bản thay đổi này lên iPhone thật.
