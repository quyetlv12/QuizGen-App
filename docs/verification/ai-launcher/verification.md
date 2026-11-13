# Icon Hỏi AI — 13/11/2026

- Analyzer không có vấn đề. 58 test ứng dụng và 3 test chụp bố cục đạt (61 tổng).
- Test hiện có xác nhận nút cố định khi cuộn và đổi tab, nằm trên menu, bấm mở ChatScreen.
- Review thủ công theo design-review: bản render 320/393/1280 px và ảnh iPhone 17 Simulator. Bong bóng, vòng xanh/quầng sáng, anten vàng, robot phóng lớn hiển thị đầy đủ; không tràn menu. Icon sao dùng Material Icons để tránh thiếu glyph.
- Build debug iOS simulator thành công; đã cài/mở app. Ảnh thực: [iphone.png](iphone.png). Capture widget dùng Arial thay font hệ thống; ảnh iPhone thể hiện font thật.
- Khác biệt với tham chiếu: tái sử dụng robot đọc sách của app, không có mô hình robot gốc trong mẫu; không đo phần trăm độ giống.
- Chưa kiểm tra máy thật. Relay đang báo xác thực thất bại nên chưa kiểm chứng gửi AI trực tiếp; không thay cấu hình relay trong tác vụ này.
- Skill design-review cài sẵn là mục giới thiệu; review được thực hiện thủ công, không chạy audit upstream.
