# Phân tích sản phẩm QuizMind AI

Ngày phân tích: 12/11/2026.

**Cập nhật triển khai:** Bản Flutter + relay local đã có mã nguồn và đã chạy luồng tạo đề bằng API thật trên iPhone Simulator. Xem [README](../../README.md) và [kiểm tra bản đầu](../verification/2026-11-12.md). Phần dưới giữ nguyên phân tích trước triển khai; các đề xuất chưa mặc nhiên là tính năng hiện có.

Nguồn chính: [Hội thoại và các bản mẫu giao diện được cung cấp](https://chatgpt.com/share/6af51a9b-c214-83ec-a4bf-4a7ec845a3c0).

Đây là phân tích ý tưởng và yêu cầu, chưa phải đặc tả đã được duyệt. Thư mục dự án chưa có mã nguồn tại thời điểm kiểm tra; chưa có bằng chứng về app chạy thực tế, chất lượng OCR/AI, chi phí hoặc thời gian xử lý. Đã áp dụng `ecc:product-capability`, Ponytail `full` và rà soát độc lập bằng một subagent chỉ đọc.

## 1. Nhận định chính

QuizMind hướng đến một công việc rõ ràng: biến tài liệu người học đang có thành bài trắc nghiệm để tự ôn tập. Giá trị cần chứng minh là giảm công soạn câu hỏi mà vẫn giúp người học hiểu đúng tài liệu.

Luồng cốt lõi khả thi về mặt thiết kế hệ thống. Phần khó nhất là đọc đúng nguồn và tạo câu hỏi có căn cứ, không phải riêng việc gọi mô hình AI. Một giao diện đẹp và kết quả JSON đúng cấu trúc chưa chứng minh câu hỏi chính xác hoặc có ích cho học tập.

Nên làm một luồng xuyên suốt có thể đo chất lượng trước khi mở rộng định dạng, AI gia sư hoặc cá nhân hóa. Chưa có dữ liệu người dùng hay nghiên cứu thị trường để kết luận mức nhu cầu, lợi thế cạnh tranh hoặc khả năng thu phí.

## 2. Yêu cầu đã có và phần còn là đề xuất

| Nội dung | Mức xác nhận | Hệ quả |
| --- | --- | --- |
| Tải tài liệu, AI đọc và chuyển thành câu hỏi trắc nghiệm để làm bài | Người dùng yêu cầu trực tiếp | Là năng lực trung tâm |
| Ứng dụng mobile | Người dùng yêu cầu trực tiếp | Ưu tiên thao tác camera và trình chọn tệp của hệ điều hành |
| Giao diện xanh lá | Người dùng yêu cầu trực tiếp | Giữ hướng màu này khi thống nhất thiết kế |
| Quét tài liệu và chọn tài liệu từ máy | Người dùng yêu cầu trực tiếp, xuất hiện sau | MVP phải có cả hai đường nhập; không mặc định dời OCR sang giai đoạn sau |
| Android và iOS | AI đề xuất trong hội thoại | Cần chốt nền tảng phát hành đầu tiên |
| Bốn đáp án, một đáp án đúng, lời giải, dẫn nguồn | AI đề xuất; phân tích này khuyến nghị | Cần chuyển thành hợp đồng dữ liệu và tiêu chí đánh giá |
| Chọn số câu, độ khó, chương; luyện tập/thi thử; lịch sử | AI đề xuất | Chọn mức tối thiểu để tránh phình phạm vi |
| PDF, DOCX, PPTX, ảnh; tối đa 50 MB | Xuất hiện trong đề xuất hoặc chữ trên mockup | Chưa phải cam kết kỹ thuật; phải kiểm chứng và chốt giới hạn |
| Flutter, FastAPI, PostgreSQL, Supabase/S3, Celery/Redis | Phương án của AI | Chưa có codebase hoặc quyết định kiến trúc ràng buộc |

Các bản mẫu dùng tên “QuizGen AI”, còn workspace mang tên “QuizMind AI”. Cần thống nhất tên trước khi tạo tài sản thương hiệu hoặc phát hành.

## 3. Phạm vi MVP đề xuất

Tác nhân chính là người tự học. Backend và nhà cung cấp OCR/AI là thành phần xử lý; chưa có nhu cầu xác nhận cho vai trò giáo viên, lớp học hoặc quản trị nội dung phức tạp.

Luồng người dùng:

1. Chọn tệp hoặc quét/chụp nhiều trang.
2. Xem lại, xoay, xóa hoặc sắp xếp trang; xác nhận tài liệu trước khi tải lên.
3. Hệ thống trích xuất chữ hoặc OCR, báo trang không đọc được.
4. Chọn phạm vi trang và số câu trong giới hạn nội dung đọc được.
5. AI tạo câu hỏi; hệ thống kiểm tra, lưu bộ đề và hiển thị kết quả xử lý.
6. Người dùng làm bài, nộp bài, xem điểm, lời giải và vị trí nguồn.
7. Mở lại bộ đề và lịch sử làm bài.

Ranh giới đầu vào khuyến nghị: PDF có chữ, PDF scan và JPG/PNG từ camera/thư viện, tập trung tài liệu in rõ. DOCX/PPTX là phần mở rộng sau khi xác nhận nhu cầu. Chữ viết tay, công thức và bảng phức tạp chưa nên được hứa hỗ trợ tốt trước khi đánh giá trên mẫu thực tế. Đây là đề xuất thu hẹp, cần được chốt trước triển khai.

Giữ một tài liệu cho mỗi lần tạo đề ở bản đầu. Chưa đưa vào MVP: AI gia sư, chia sẻ công khai, lớp học, bảng xếp hạng, thanh toán thuê bao, sinh đề từ nhiều tài liệu và thuật toán học thích ứng.

Tạo đề cần mạng trong phương án này. Làm bài offline là quyết định riêng: nếu đưa vào phạm vi, phải có lưu đáp án cục bộ, khôi phục lần làm và đồng bộ chống trùng. Không mặc định hứa offline toàn bộ.

## 4. Giao diện và trạng thái còn thiếu

Các hình đã xem có màu xanh lá, nền trắng/mint, nút tạo đề nổi bật và danh sách tài liệu/bộ đề gần đây. Màn quét có khung căn tài liệu, chụp, thư viện, flash và lựa chọn nhiều trang. Đây là nền tảng trực quan phù hợp để tiếp tục phân tích luồng mobile.

Các điểm cần chỉnh hoặc xác minh:

- Thống nhất thanh điều hướng. Bản trang chủ dùng “Trang chủ / Tài liệu / Bộ đề / Cá nhân”, trong khi bản tải tệp dùng “Trang chủ / Tạo đề / Đề của tôi / Cá nhân”. Khuyến nghị giữ bộ điều hướng đầu tiên, đặt “Tạo đề” thành hành động nổi bật.
- Trên điện thoại, dùng hai hành động rõ: “Quét tài liệu” và “Chọn tệp”. Câu “kéo thả vào đây” và một trình duyệt thư mục tự xây chưa giúp hoàn thành tác vụ chính tốt hơn trình chọn tệp sẵn có.
- Hai chỉ số 82% trên trang chủ cần tên và cách tính rõ. Khi chưa có dữ liệu, dùng trạng thái trống thay vì số minh họa dễ bị hiểu là dữ liệu thật.
- Sau camera cần màn xem lại nhiều trang. Khung camera đẹp chưa chứng minh có phát hiện mép giấy, sửa phối cảnh hay OCR.
- Khi tạo đề, hiển thị từng giai đoạn thay vì một phần trăm giả: tải lên, đọc tài liệu, tạo câu hỏi, kiểm tra. Cho phép rời màn hình rồi quay lại.
- Màn kết quả nên mở được trang/đoạn nguồn của từng câu và có hành động báo câu sai. Cần phân biệt đáp án người học chọn với đáp án hệ thống xác định.

Các màn chức năng tối thiểu: trang chủ; tài liệu và chi tiết tài liệu; nhập tệp/quét; xem lại trang; cấu hình/tác vụ tạo đề; danh sách/chi tiết bộ đề; làm bài; kết quả/lời giải/nguồn; tài khoản và quản lý dữ liệu. Một số chức năng có thể dùng chung màn hoặc sheet.

Các trạng thái cần thiết: chưa có tài liệu; từ chối quyền camera; ảnh mờ/thiếu trang; tệp sai loại, có mật khẩu hoặc hỏng; mất mạng; hết hạn mức; AI lỗi hoặc timeout; chỉ tạo được một phần câu hỏi; không đủ nội dung; tải lại app khi đang xử lý; nộp bài lặp. Các trạng thái này chưa được xác nhận qua runtime.

## 5. Xử lý AI và chất lượng học tập

Pipeline đề xuất:

```mermaid
flowchart LR
  A[Quét hoặc chọn tệp] --> B[Kiểm tra tệp và lưu riêng tư]
  B --> C[Trích xuất chữ hoặc OCR theo trang]
  C --> D[Chia đoạn và giữ vị trí nguồn]
  D --> E[Tạo câu hỏi có cấu trúc]
  E --> F[Kiểm tra và loại câu lỗi]
  F --> G[Bộ đề và lần làm bài]
```

Mỗi câu nên lưu: câu hỏi, các lựa chọn, đáp án, lời giải, mã đoạn nguồn, vị trí trang và đoạn bằng chứng. Nên giữ phiên bản tài liệu, câu hỏi và cấu hình/mô hình sinh để truy vết khi người dùng báo sai.

Kiểm tra tự động phải phát hiện thiếu trường, đáp án ngoài danh sách, lựa chọn trùng, câu trùng và dẫn nguồn không tồn tại. Đánh giá ngữ nghĩa phải kiểm tra đáp án có thật sự được nguồn hỗ trợ, có nhiều đáp án hợp lý hay không và câu hỏi có giúp ôn tập hay chỉ nhắc lại từ khóa. Không dùng việc một mô hình khác đồng ý làm bằng chứng duy nhất về độ đúng.

Nếu người dùng yêu cầu nhiều câu hơn nội dung có thể hỗ trợ, trả số câu ít hơn kèm lý do hoặc báo không đủ dữ liệu. Khi một số trang OCR lỗi, nói rõ phần nào đã được dùng; không tự lấy kiến thức ngoài tài liệu để bù cho đủ.

Cần bộ đánh giá gồm PDF có chữ, PDF scan, ảnh rõ/mờ, tiếng Việt có dấu, tài liệu ngắn và nội dung có bảng/công thức. Theo dõi tỷ lệ xử lý thành công, tỷ lệ câu bị loại, câu sai/không có căn cứ, độ bao phủ nội dung, thời gian và chi phí cho một bộ đề được chấp nhận. Chưa đặt cam kết độ chính xác khi chưa đo.

## 6. Kiến trúc ban đầu

Phương án nhỏ gọn: một ứng dụng mobile, một backend chia module, một tiến trình xử lý nền, cơ sở dữ liệu và kho tệp riêng tư. Chưa cần microservices hay vector database cho luồng một tài liệu tạo một bộ đề.

- Mobile: Flutter là ứng viên đã được nêu trong hội thoại; tài liệu chính thức xác nhận hỗ trợ Android và iOS. Chọn sau khi chốt nền tảng, năng lực đội và kiểm tra tích hợp camera/tệp. [Flutter: Supported deployment platforms](https://docs.flutter.dev/reference/supported-platforms).
- Backend: FastAPI là một ứng viên. API tạo tác vụ và trả mã theo dõi; OCR/sinh đề chạy qua worker có hàng đợi, trạng thái lưu bền và cơ chế phục hồi. FastAPI cũng phân biệt tác vụ nền nhỏ với công việc nặng cần công cụ như Celery. Việc chọn worker ở đây là đề xuất thiết kế. [FastAPI: Background Tasks](https://fastapi.tiangolo.com/tutorial/background-tasks/).
- Dữ liệu: PostgreSQL cho tài liệu, tác vụ, bộ đề và lần làm; kho object riêng tư cho tệp/ảnh. Nếu dùng Supabase Storage, phải thiết kế chính sách quyền truy cập theo chủ sở hữu; tài liệu của Supabase mô tả cơ chế RLS. [Supabase: Storage Access Control](https://supabase.com/docs/guides/storage/security/access-control).
- Tích hợp AI/OCR: đi qua backend; khóa dịch vụ không đặt trong app. Chưa chọn nhà cung cấp khi thiếu mẫu đầu vào, ngân sách và yêu cầu lưu dữ liệu.

Trạng thái tác vụ đề xuất: `queued → extracting → generating → validating → ready`; có nhánh `failed` và kết quả cần người dùng xem lại khi chỉ xử lý được một phần. API phải trả mã lỗi có thể hiểu được, không để giao diện chờ vô hạn.

Mỗi yêu cầu tạo đề có khóa chống trùng theo người dùng và thao tác. Gửi lại không sinh nhiều kết quả chính thức hoặc ghi hạn mức nhiều lần. Timeout nhà cung cấp không chứng minh tác vụ chưa được thực hiện; cần lưu mã yêu cầu/trạng thái và đối soát khi có thể trước khi gọi lại, đồng thời đặt giới hạn retry và chi phí.

Các nhóm dữ liệu chính: `users`, `documents`, `document_pages/chunks`, `generation_jobs`, `quizzes`, `questions/options`, `attempts/answers`. Lần làm phải gắn với phiên bản đề để chỉnh câu hỏi sau này không đổi kết quả cũ.

## 7. Rủi ro cần xử lý trước beta

| Rủi ro | Cách kiểm soát đề xuất |
| --- | --- |
| Câu hỏi sai, mơ hồ hoặc vượt ngoài nguồn | Dẫn chứng theo trang/đoạn, bộ đánh giá do người đọc đối chiếu, báo sai câu, loại câu không đủ căn cứ |
| OCR sai dấu, thứ tự cột hoặc công thức | Kiểm tra chất lượng đầu vào, xem lại trang, giới hạn nội dung hỗ trợ, báo phần không đọc được |
| App đóng/mất mạng hoặc yêu cầu bị gửi lại | Xử lý trên server, trạng thái lưu bền, khôi phục theo mã tác vụ, chống trùng kết quả/lần tính hạn mức |
| Lộ tài liệu học tập cá nhân | Quyền theo chủ sở hữu, tệp riêng tư, kiểm soát truy cập từng tài nguyên, không ghi nội dung tài liệu vào log mặc định |
| Xóa không hết dữ liệu | Chốt tài liệu gốc, OCR, bộ đề và lịch sử nào bị xóa; thu hồi truy cập trước, theo dõi việc dọn dữ liệu; xác minh chính sách nhà cung cấp |
| Chi phí tăng do tài liệu dài hoặc retry | Giới hạn trang/dung lượng/số câu, đo chi phí trên bộ đề thành công, đặt ngân sách tác vụ và hạn mức |
| Điểm cao nhưng người học không hiểu hơn | Đánh giá độ bao phủ, chất lượng phương án nhiễu và khả năng dùng lời giải để sửa sai; chưa coi điểm quiz là thước đo tiến bộ đầy đủ |

Không thể suy ra tổng chi phí từ riêng giá token. Cần đo OCR, AI tạo/kiểm tra, lưu trữ, truyền dữ liệu và số lần thất bại. Chưa có căn cứ để ước lượng lịch phát triển khi chưa chốt nền tảng, định dạng và tiêu chí chất lượng.

## 8. Tiêu chí nghiệm thu đề xuất

1. Camera và trình chọn tệp đều đi hết luồng đến bộ đề/làm bài trên mẫu thuộc phạm vi. Quyền bị từ chối và tệp không đọc được có thông báo cùng cách khắc phục.
2. Câu được chấp nhận có đủ cấu trúc, một đáp án và vị trí nguồn tồn tại; người đánh giá đối chiếu tính đúng và mức căn cứ. Tài liệu thiếu không bị ép tạo đủ số câu. Ngưỡng chất lượng phải được chốt từ bộ đánh giá trước beta.
3. Đóng/mở app và gửi lại cùng yêu cầu vẫn theo dõi cùng tác vụ; chỉ có một kết quả chính thức và một lần ghi hạn mức. Tác vụ lỗi kết thúc rõ ràng và có thể phục hồi theo chính sách.
4. Điểm tính nhất quán từ phiên bản đề lúc bắt đầu. Nộp lặp không tạo lịch sử trùng; khôi phục được đáp án đã lưu theo phạm vi mạng/offline đã chốt.
5. Hai tài khoản không đọc được tài liệu, bộ đề hoặc lịch sử của nhau. Xóa tài liệu thu hồi truy cập và xử lý dữ liệu phát sinh theo chính sách; tác vụ đang chạy không được xuất bản lại tài liệu đã xóa.

Đây là kế hoạch kiểm chứng; chưa có tiêu chí nào được xác nhận bằng việc chạy app hoặc test mã nguồn.

## 9. Quyết định còn mở và bước tiếp theo

Cần chốt trước triển khai: đây là đồ án hay sản phẩm phát hành; nền tảng đầu tiên; người học/môn học ưu tiên; định dạng và giới hạn đầu vào; có cần làm bài offline; phạm vi tài khoản; chính sách gửi/lưu/xóa dữ liệu tại bên thứ ba; ngân sách cho mỗi bộ đề.

Thứ tự triển khai khuyến nghị theo bằng chứng:

1. Chốt phạm vi và bộ tài liệu mẫu được phép sử dụng, xây tiêu chí đánh giá câu hỏi.
2. Làm thử pipeline đọc tài liệu → tạo câu → đối chiếu nguồn; đo chất lượng, độ trễ và chi phí.
3. Thống nhất tên, điều hướng và các trạng thái màn hình từ thiết kế xanh hiện có.
4. Xây một luồng mobile hoàn chỉnh gồm cả quét và chọn tệp, xử lý nền, làm bài và kết quả.
5. Chạy kiểm thử luồng lỗi, quyền truy cập và khôi phục; chỉ mở rộng định dạng/tính năng sau khi luồng lõi đạt tiêu chí đã chốt.

Trọng tâm nên là “tạo bài ôn tập đáng tin từ tài liệu của người học”. Chất lượng nguồn, câu hỏi và trải nghiệm hoàn thành lần đầu quyết định giá trị của bản MVP.
