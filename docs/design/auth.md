# Tài khoản

## Phạm vi và tiêu chí

- Đăng ký bằng họ tên, email, mật khẩu và xác nhận mật khẩu; bỏ chọn “Bạn là ai?”, tài khoản mới dùng vai trò mặc định `user`.
- Đăng nhập, khôi phục phiên đã xác minh, đăng xuất và xử lý phiên hết hạn.
- Ba vai trò là thông tin hồ sơ, hiện dùng cùng chức năng cá nhân; chưa có quyền quản trị hay quản lý lớp học.
- Tài liệu, quiz, lịch sử và bản nháp tách theo tài khoản. Không tự gán thư viện cũ cho người đăng ký đầu tiên.
- Form cuộn được ở chiều rộng 320, 393, 1280 và khi bàn phím mở; có trạng thái đang xử lý, lỗi và thử lại.

## Thiết kế

Tham chiếu hiện hành: `references/auth-user-reference.png`, ảnh người dùng cung cấp, thay thế mockup cũ. Brief và khác biệt được ghi tại `auth-reference.md`.

Nền trắng với góc mint, logo sách và QuizGen AI, robot đọc sách ở màn đăng nhập; tiêu đề xanh đậm, ô nhập trắng viền xám xanh bo 12px. Tái sử dụng GradientAction và robot của dự án. Không có chọn vai trò hoặc Google OAuth. Cấu hình kết nối mở bằng nút bánh răng; giữ nguyên luồng API.

Form desktop tối đa 480px, mobile lề 24px, cuộn khi mở bàn phím. Đã kiểm tra ảnh render thực tại 320/393/1280px: không tràn, trường và CTA rõ; robot/font/logo không khớp hoàn toàn asset trong ảnh mẫu. Không tuyên bố phần trăm tương đồng. Ảnh widget test nạp Arial, thiết bị dùng font hệ thống. `design-review` cài đặt là catalogue, đã thực hiện kiểm tra trực quan thủ công.

## Phiên và API

Backend lưu mật khẩu PBKDF2 SHA256 với salt riêng, 600.000 vòng; chỉ lưu digest SHA256 của session, hạn 30 ngày. API đăng ký/đăng nhập có giới hạn 12 lượt/phút trên dịch vụ. Client lưu session bằng flutter_secure_storage theo origin, xác minh `/api/auth/me` trước khi hiển thị dữ liệu.

- `POST /api/auth/register`: email, password, name, role.
- `POST /api/auth/login`: email, password.
- `GET /api/auth/me`; `POST /api/auth/logout`.
- Dùng cả bearer của relay và `X-QuizMind-Session`; dữ liệu nằm tại `DATA/users/<id>`.
- Response cũ không được khôi phục dữ liệu sau đổi tài khoản/kết nối; logout xóa dữ liệu trong bộ nhớ và reset navigation.

Nếu xóa Keychain hoặc thu hồi phiên thất bại, ứng dụng báo rõ chưa xác nhận việc xóa/thu hồi. Relay token nhập tay hiện chỉ giữ trong bộ nhớ, phải nhập lại khi khởi động; token tích hợp sẵn không bị ảnh hưởng. Cần triển khai backend tương ứng trước khi sử dụng client mới với relay thật.
