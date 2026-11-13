# QM-DOC-QA — kiểm thử tài liệu → bộ câu hỏi

Ngày: 12/11/2026. Dự án: /Users/quyetdev/Documents/QuizMind AI.
Đầu vào: yêu cầu quyet qua Rio; Rio đã giao trực tiếp Linh, không tạo nhiệm vụ QA trùng.
PM: MausBot. QA: Linh. Trạng thái: đang thực hiện, chưa có kết quả được PM kiểm chứng.

## Phạm vi và tiêu chí
- DOC-QA-01: đọc TXT/MD, PDF và OCR theo khả năng môi trường; ghi rõ loại đã chạy/chưa chạy.
- DOC-QA-02: sinh câu hỏi thật; phân biệt fixture/mock với lời gọi thật; đối chiếu câu hỏi, đáp án, giải thích và nguồn tài liệu.
- DOC-QA-03: làm bài, chấm điểm, lưu và chống nộp trùng bằng bằng chứng mới.
- DOC-QA-04: đầu vào rỗng/sai định dạng và lỗi dịch vụ có kết quả tái hiện.
- DOC-QA-05: PM đọc báo cáo, đối chiếu hiện vật rồi kết luận; lời báo xong không là nghiệm thu.

## Quyền sở hữu và môi trường
PM chỉ sửa nguồn trạng thái này và brief motion. Linh sở hữu báo cáo docs/verification/document-to-quiz-qa-2026-11-12.md và thư mục bằng chứng riêng. Không sửa mã sản phẩm, không ghi đè log motion/dev. Chỉ Linh dùng simulator/relay trong các phiên QA, tự xếp tuần tự hai phạm vi; không reset dữ liệu cá nhân, dùng fixture và dữ liệu kiểm thử tách biệt. Không phát hành.

## Giả định, bằng chứng và giới hạn
Chọn fixture tổng hợp không chứa dữ liệu cá nhân theo brief Rio. Chưa có bằng chứng QA mới tại thời điểm tạo; không coi test cũ hoặc báo cáo motion là bằng chứng chức năng. Báo cáo cần ghi phiên bản/hash, fixture, bước/lệnh, đầu ra thực tế, lỗi tái hiện và phần bị chặn.
