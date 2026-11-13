# Robot và lời nhắn theo thời gian

- `flutter analyze --no-pub`: không có vấn đề.
- Toàn bộ 60 test thông thường và 3 test chụp giao diện tạm thời đạt (63 tổng). Hai test mới kiểm tra kích thước, lời chào trễ, fade trung gian, tự ẩn, đổi gợi ý, mở chat, dispose, vòng đời app và giảm chuyển động.
- Build iOS Simulator thành công; đã cài và mở `dev.quyet.quizmind` trên iPhone 17 (iOS 27).
- Review thủ công bản render rộng 320, 393 và 1280 px cùng ảnh iPhone thật từ Simulator. Không thấy overflow ở launcher/menu. Bản render widget dùng Arial; ảnh Simulator dùng font hệ thống.
- `menu-*.png`: lời chào hiện. `hidden-*.png`: chỉ còn robot. `iphone.png`: giao diện trên Simulator. `iphone-startup.png`: ảnh chụp quá sớm khi app đang khởi động, không dùng làm bằng chứng lời chào; thời gian lời chào được kiểm tra bằng widget test.
- Test capture đã chuyển thành `capture_test.dart.example`, không nằm trong bộ test thường xuyên. File launcher gốc `build` đã khôi phục sau build.
- Chưa kiểm tra trên thiết bị vật lý. Relay hiện báo xác thực thất bại; không thay đổi relay hoặc gọi AI upstream trong phạm vi này.
