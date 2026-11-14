# Thẻ tag cho bộ đề

## Mục tiêu và tham chiếu

Tổ chức bộ đề bằng nhiều tag và lọc nhanh theo một tag. Tham chiếu là ảnh người dùng gửi: hàng bộ lọc dạng pill, tag xanh nhạt bên dưới thông tin bộ đề, bottom sheet quản lý tag với danh sách chọn và ô tạo tag.

Giữ hệ màu xanh, font, StudyRow, StatusPill và AppSheetBody hiện có. Sheet giới hạn chiều rộng theo thành phần chung, cuộn theo bàn phím. Menu ba chấm ở từng tag cung cấp đổi tên và xoá; không thay đổi thao tác mở bộ đề.

## Hành vi

- Biểu tượng tag cạnh “Bộ đề của tôi” mở quản lý danh mục; “Gắn tag” trên từng bộ đề mở chọn nhiều tag.
- Tạo, đổi tên và xoá danh mục lưu ngay. Chọn hoặc gỡ tag trên một bộ đề được lưu khi bấm “Hoàn tất”. Đóng sheet bỏ các lựa chọn chưa lưu.
- Tên được bỏ khoảng trắng dư, dài 1–40 ký tự, không trùng tên theo so sánh không phân biệt hoa thường.
- Xoá có xác nhận, gỡ tag khỏi mọi bộ đề và giữ nguyên bộ đề. Bộ lọc đã bị xoá trở về “Tất cả”.
- Có trạng thái chưa có tag, chưa có bộ đề, lọc rỗng, đang lưu và lỗi cho phép thử lại. Chặn thao tác lặp khi lưu.
- Dữ liệu cũ không có tags được đọc như danh mục rỗng. Backend lưu bền vững với cơ chế rollback hiện có.

## Kiểm tra

- Backend: CRUD, nhiều tag, lưu/đọc lại, dữ liệu cũ, dữ liệu không hợp lệ, rollback, kiểm tra xác thực các route.
- Widget: CRUD, xác nhận xoá, lọc/gắn nhiều tag, lỗi lưu và thử lại, bố cục ở 320/393/1280 px với bàn phím.
- Ảnh kiểm tra tại docs/verification/quiz-tags/: dùng dữ liệu kiểm thử và font Arial riêng trong test. Font ứng dụng không thay đổi; ảnh widget không phải ảnh chụp trực tiếp máy ảo.
- Review ảnh: bộ lọc, nhãn xanh nhạt, danh sách chọn và form tương ứng tham chiếu; bổ sung menu sửa/xoá theo yêu cầu. Desktop dùng bố cục giới hạn chiều rộng hiện có. Không đo tỷ lệ khớp thị giác.

## Chọn màu tag

Bổ sung bảng 6 màu (xanh lá, xanh dương, vàng, đỏ, xanh ngọc, xám) ngay trong form tạo/sửa hiện có; không đổi bố cục, font hoặc điều hướng. Mỗi ô màu có vùng bấm 44 px, tên qua tooltip/semantics, dấu tích và viền cho trạng thái chọn. Màu chữ đậm trên nền nhạt áp dụng cho nhãn bộ đề và chip đã chọn; bộ lọc đang chọn dùng nền đậm, chữ trắng.

Màu lưu bằng khóa `color` trong danh mục tag, được kiểm tra ở relay; cập nhật tên không kèm màu giữ nguyên màu cũ. Tag thiếu màu hoặc khóa không nhận diện hiển thị xanh lá. Menu “Đổi màu” mở cùng form sửa; “Lưu tag” lưu cả tên và màu. Bộ đề giữ liên kết theo ID nên đổi màu áp dụng cho tất cả bộ đề đã gắn tag.

Tiêu chí kiểm tra: tạo/sửa lưu màu qua lần đọc lại; giá trị không hợp lệ bị từ chối mà không thay đổi dữ liệu; tag cũ vẫn hiển thị; CRUD/gắn/lọc hoạt động; palette không tràn ở 320/393/1280 px và khi mở bàn phím. Ảnh widget tại docs/verification/tag-colors/ (font Arial trong test, dữ liệu giả). Review trực quan theo giao diện hiện có; đây là bổ sung điều khiển nhỏ, không cần concept mockup mới.
