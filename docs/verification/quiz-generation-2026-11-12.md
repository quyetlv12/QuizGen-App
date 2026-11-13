# Kiểm thử đọc tài liệu và tạo câu hỏi — 12/11/2026

Phạm vi: kiểm thử thật qua relay đang chạy tại `http://127.0.0.1:8787`, upstream AI đã cấu hình trên máy. Dữ liệu là ba tài liệu tiếng Việt tổng hợp trong [fixtures](fixtures/), không chứa thông tin riêng tư.

## Kết quả

| Tài liệu | Định dạng | Đọc được | Bộ đề | Trích dẫn | Chấm điểm |
| --- | --- | ---: | ---: | ---: | ---: |
| Vòng tuần hoàn nước | TXT | 1 trang, 810 ký tự | 5/5 câu | 5/5 khớp | 5/5 |
| Những mốc chính của Internet | MD | 1 trang, 1.076 ký tự | 5/5 câu | 5/5 khớp | 4/5 với cố ý sai 1 câu |
| Năng lượng tái tạo và lưu trữ | TXT | 1 trang, 1.207 ký tự | 5/5 câu | 5/5 khớp | 5/5 |

Mỗi câu có đúng bốn lựa chọn khác nhau, chỉ số đáp án hợp lệ và giải thích. Relay đã xác nhận từng `quote` xuất hiện trong đúng trang nguồn trước khi lưu bộ đề. Trường `model` trong response của cả ba bộ đề là `gpt-6.1-sol`; đây là metadata phản hồi, không phải phép đo độc lập về model nội bộ của upstream.

## Kiểm tra lưu và gửi bài

- Mỗi bộ đề được lưu vào state của relay và hiển thị trong thư viện.
- Gửi một lần làm với mã ổn định cho từng bộ đề; gửi lại cùng mã trả về đúng bản ghi cũ (`repeat_same=True`), không tạo lần làm trùng.
- Bộ đề Internet dùng một đáp án cố ý sai để kiểm tra điểm 4/5; hai bộ còn lại dùng toàn bộ đáp án đúng để kiểm tra điểm tối đa.
- Mã lần làm đã đối chiếu trong state: `qa-20261112-water-attempt` = 5/5, `qa-20261112-internet-attempt` = 4/5, `qa-20261112-energy-attempt` = 5/5.

## Sự cố upstream

Lần tạo đầu tiên cho tài liệu năng lượng nhận HTTP 503 từ upstream. Relay đánh dấu tác vụ `failed`, không lưu bộ đề và không tự gửi lại. Sau khi `/api/health` và `/api/connection` đều trả thành công, tôi gửi một request kiểm thử mới với mã khác; lần đó tạo được bộ đề 5 câu và chấm 5/5. Đây là lần chạy độc lập có chủ đích, không phải retry tự động.

## Mã kiểm thử và giới hạn

- Import: `qa-20261112-water-import`, `qa-20261112-internet-import`, `qa-20261112-energy-import`.
- Generate thành công: `qa-20261112-water-generate`, `qa-20261112-internet-generate`, `qa-20261112-energy-generate-retry`.
- Generate lỗi 503: `qa-20261112-energy-generate`.
- Không in khóa API hoặc nội dung cấu hình bí mật. Các bộ đề kiểm thử hiện còn trong state local để mở lại trên app.
- Đây là kiểm thử nội dung tổng hợp bằng AI thật; kết quả chứng minh luồng đọc, kiểm tra trích dẫn và chấm điểm với các fixture này, chưa chứng minh độ chính xác cho mọi tài liệu thực tế, PDF phức tạp, chữ viết tay hoặc DOCX/PPTX.
