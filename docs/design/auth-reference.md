# Auth theo ảnh tham chiếu người dùng

Tham chiếu: `references/auth-user-reference.png`. Yêu cầu mới thay phần chọn “Bạn là ai?” bằng đăng ký thông thường; chỉ đăng nhập/đăng ký email, không thêm Google OAuth. Tài khoản mới gửi role mặc định `user` theo contract sẵn có; không sửa dữ liệu vai trò của tài khoản cũ.

Brief: giao diện học tập thân thiện, một cột, nền trắng với góc xanh mint nhạt, thương hiệu QuizGen AI trên cùng; robot đọc sách ở màn đăng nhập, tiêu đề đậm xanh đen, ô nhập viền xám xanh bo 12px, nút xanh sáng sang xanh đậm. Giữ token và font hệ thống của app; tiêu đề 30/32px, nội dung 16px, lề mobile 24px, form desktop tối đa 480px. Không thêm chuyển động. Màn hẹp và bàn phím dùng cuộn; lỗi hiển thị tại form, thao tác bị khóa khi gửi. Cấu hình relay chuyển vào nút cài đặt góc trên để giữ bố cục chính.

Phân tích ảnh: logo và chữ nằm ngang; đăng nhập có minh họa giữa logo và tiêu đề, hai trường và một CTA; đăng ký có tiêu đề, bốn trường và CTA. Nền trang trí ở các góc không cản thao tác. Bỏ hẳn các hàng vai trò, phần “Hoặc” và Google. Dùng asset `assets/robot.png` có sẵn (robot thân trên), khác minh họa toàn thân với sách/cây trong mẫu; không có asset gốc/font gốc nên không tuyên bố khớp tuyệt đối. Ảnh tham chiếu có sẵn nên không cần tạo mockup mới.
