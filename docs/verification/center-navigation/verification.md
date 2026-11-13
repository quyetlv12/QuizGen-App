# Kiểm chứng menu có nút quét — 13/11/2026

- `flutter analyze --no-pub`: không có vấn đề.
- `flutter test --no-pub`: 58 test đạt. Bao gồm mở màn quét bằng nút +, hủy và giữ tab đang chọn, nhận ảnh rồi hiển thị bước xem lại/nhập tên.
- Build iOS simulator debug thành công; đã cài và mở trên iPhone 17 (iOS 27).
- Review thủ công ảnh render ở chiều rộng 320, 393 và 1280 px: bốn nhãn một dòng, nút + có vùng chạm đầy đủ, bot nằm trên menu, không thấy overflow.
- Review ảnh simulator [iphone.png](iphone.png): menu nằm trong vùng an toàn và nút + hiển thị đầy đủ. App đang báo xác thực relay thất bại; chưa kiểm chứng tạo đề qua relay.
- Camera máy thật chưa được kiểm tra. Luồng nhận tệp ảnh được kiểm chứng bằng callback giả lập; simulator không có camera.
- Tái sử dụng font ứng dụng và Material Icons vì không có tài sản gốc. Không đo phần trăm độ giống.

Đã áp dụng design-review thủ công; skill cài sẵn không có script audit upstream.
