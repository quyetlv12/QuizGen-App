# Cập nhật nội dung tài liệu

Trong màn hình tạo bộ đề của tài liệu, chọn **Cập nhật tài liệu**, tải file mới hoặc quét lại, rồi chọn **Đọc và cập nhật tài liệu**. Tác vụ được xử lý nền và xuất hiện trong danh sách tác vụ.

Giao diện dùng lại màn hình nhập, màu xanh và các thành phần hiện có. Tên tài liệu được điền sẵn và có thể sửa. Hủy hoặc gửi lỗi không làm mất bản đang có; lỗi gửi giữ file đã chọn để thử lại.

Backend chỉ thay nội dung sau khi đọc và kiểm tra thành công, giữ nguyên ID, ngày tạo, bộ đề và kết quả cũ. Bộ đề tạo tiếp theo dùng nội dung mới. Tác vụ cập nhật và tạo đề trên cùng tài liệu không chạy đồng thời. Request ID chống gửi trùng; lỗi lưu khôi phục nội dung cũ.

## Kiểm tra

- 40 kiểm thử backend, gồm 7 kiểm thử cập nhật: thay nguồn, giữ lịch sử, lỗi đọc/lưu, chống trùng, chặn tác vụ xung đột, xác thực HTTP và truyền nguồn mới vào hàm tạo đề.
- 18 kiểm thử widget liên quan: tải file, hủy, lỗi gửi, điều hướng và thao tác tài liệu, tại viewport 393×852 và 1280×900.
- Flutter analyze và git diff --check.
- Review thủ công ảnh widget ở hai kích thước. Ảnh có giới hạn của font/asset trong harness; không dùng chúng để xác nhận font thực tế trên thiết bị.
- Chưa gọi AI thật hoặc thử camera/thiết bị thật trong thay đổi này.

Flutter test chạy trong bản sao tạm vì file launcher `build` ở gốc dự án trùng tên thư mục đầu ra mặc định của Flutter. Không thay launcher để chạy kiểm thử.
