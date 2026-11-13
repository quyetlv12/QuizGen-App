# QuizMind AI — giao diện theo ảnh tham chiếu

## Phạm vi và hướng thiết kế

Ứng dụng Flutter đọc tài liệu và tạo bài ôn tập qua API AI local. Tên dự án giữ là QuizMind AI; nhãn hiển thị **QuizGen AI** theo ảnh người dùng cung cấp. Hướng giao diện: thân thiện, nền trắng, xanh lá và mint, biểu tượng rõ nghĩa, một hành động chính nổi bật trên mỗi màn.

Nguồn chuẩn là sáu ảnh đã lưu trong [references](references/): [trang chủ](references/home.png), [làm bài](references/quiz.png), [cấu hình](references/config.png), [kết quả](references/result.png), [quét](references/scan.png), [thư viện](references/library.png). Khung điện thoại, bóng bên ngoài và thanh trạng thái trong ảnh không phải thành phần cần vẽ lại trong app.

## Màu và chữ

Token tập trung trong `lib/theme.dart`:

| Vai trò | Giá trị |
| --- | --- |
| Xanh chính | `#008F21` |
| Xanh đậm | `#006C39` |
| Nền mint | `#ECFBF0` |
| Chữ chính | `#071C14` |
| Chữ phụ | `#506661` |
| Viền | `#DCEDE3` |
| Gradient hành động | `#80E33D` → `#05A12C` → `#006C39`, điểm dừng 0 / 0,48 / 1 |

Nền chính trắng; màn quét dùng xanh đậm. Tiêu đề trang 28 px, tiêu đề mục 20 px, nội dung 14–16 px; cỡ chữ chi tiết được điều chỉnh theo từng thành phần. Dùng font hệ thống của Flutter/nền tảng, hỗ trợ tiếng Việt. Không có tệp font gốc của ảnh để xác định hoặc tái tạo chính xác kiểu chữ.

## Thành phần và bố cục

`lib/ui.dart` chứa thanh thương hiệu, robot, tiêu đề/quay lại, nút gradient, nhãn trạng thái, biểu tượng tệp, hàng tài liệu/đề, vùng tải tệp, lựa chọn cấu hình và thanh hành động dưới. Dùng Material Icons qua widget `Icon`, ưu tiên biến thể outlined/rounded; bộ icon gốc trong ảnh không được cung cấp.

Nội dung một cột, lề ngang 18 px, khoảng cách mục thường 12–20 px, góc bo thường 16–20 px. `PageBody` giới hạn chiều rộng 720 px trên iPad và cuộn theo nội dung. Thanh điều hướng **Trang chủ / Tài liệu / Bộ đề / Cá nhân** dùng nền mint cho tab đang chọn. Mục Cá nhân mở cài đặt kết nối hiện có; app chưa có hệ thống tài khoản.

Các màn đã áp dụng: trang chủ, thư viện, nhập tài liệu, cấu hình tạo đề, làm bài, kết quả/giải thích và quét. Thống kê, tệp, số câu, điểm và trạng thái dùng dữ liệu thật của relay; không sao chép số liệu hay tên tài liệu minh họa từ ảnh.

## Robot

Tài sản sử dụng thật: [`assets/robot.png`](../../assets/robot.png), đã khai báo trong `pubspec.yaml`. Robot được dựng lại từ ảnh trang chủ bằng công cụ imagegen native, nền trong suốt. Mục tiêu model là `gpt-image-2.5`; runtime không cung cấp thông tin xác nhận model đã phục vụ nên **model thực tế chưa được xác minh**. Đây là tài sản tái dựng, không phải bản trích xuất nguyên gốc được bảo đảm giống từng điểm ảnh.

Prompt đã dùng:

> Extract ONLY the small white and emerald green friendly 3D robot holding an open green book at the upper right beside Chào Leah. Preserve rounded white head, dark green face, smiling closed eyes, green ear pieces, hands holding book and yellow sparkle. Remove phone frame/background/text/cards/status bars/buttons. Center entire robot on genuinely transparent RGBA canvas. Preserve identity/pose/green colors/soft 3D lighting/book design.

## Hành vi và trạng thái

Giữ luồng chọn tệp/chụp ảnh → sắp xếp trang → đọc chữ → xem lại nguồn → tạo đề → làm bài → kết quả và trích dẫn. Loading, lỗi kết nối, thư viện rỗng, tìm không có kết quả và tác vụ AI đang chạy đều có trạng thái thực. Không có phần trăm tiến độ AI giả.

Màn làm bài cho phép đánh dấu, bỏ qua, nhảy đến câu đánh dấu và giữ nháp gồm đáp án/vị trí/thời điểm bắt đầu. Mã nộp bài ổn định được giữ nguyên. Kết quả có xem tất cả hoặc chỉ câu sai; lời giải giữ trang và đoạn trích nguồn. Thời gian làm được lưu trên thiết bị cho lần nộp mới; lịch sử cũ chưa có thời gian hiển thị `—`.

## Khác biệt với ảnh và giới hạn

- Lời chào dùng “Chào bạn”; số liệu và nội dung thay đổi theo dữ liệu thật. Tệp hỗ trợ là PDF, TXT/MD, JPG/PNG; không quảng cáo DOCX/PPTX chưa được hỗ trợ.
- Cấu hình hiện có 5/10/15 câu, độ khó tự động, luyện tập và toàn bộ tài liệu. Các lựa chọn 20/30/50 câu, độ khó thủ công, thi và chọn chương trong ảnh chưa được triển khai.
- Màn quét dùng camera nhúng trong khung, giữ nguyên tỷ lệ hình; không có tự bắt cạnh hoặc chỉnh phối cảnh.
- Font, nét icon và robot chưa có tài sản gốc để bảo đảm trùng tuyệt đối. Chưa có phép đo độ giống theo điểm ảnh; không khẳng định 100%.

## Review render — 12/11/2026

Sửa ngày 13/11/2026 theo ảnh lỗi người dùng: `PageBody` dùng `SafeArea` bao quanh vùng cuộn để tiêu đề và nút quay lại tránh status bar/tai thỏ và nội dung tránh home indicator. Giữ nguyên token, khoảng cách nội dung, chiều rộng tối đa và điều hướng; màn có AppBar không cộng lặp khoảng trống phía trên.

Đã đọc skill `design-review` cài sẵn; tệp này là mục giới thiệu, không chứa bộ script upstream. Review được thực hiện thủ công trên bản render thật, không tuyên bố đã chạy công cụ audit upstream.

Đã đối chiếu sáu màn trên iPhone 17 Simulator với ảnh tham chiếu về màu, thứ bậc, icon, khoảng cách và nút chính; xem thêm trang chủ iPad Pro 13. Không thấy overflow ở các ảnh chụp cuối. Test widget bổ sung kiểm tra sáu màn ở 320×740, text scale 1,25 và 1024×1366. Điều hướng, tìm tài liệu, chọn đáp án, nháp, đánh dấu và lời giải nguồn được kiểm tra bằng test; camera thật chưa kiểm chứng.

Ảnh trước/sau và kết quả kiểm tra ở [verification](../verification/2026-11-12.md). REA đã được dùng để quan sát việc khởi chạy app trên simulator; bằng chứng đó không chứng minh độ giống giao diện.

## Quét với camera nhúng — 13/11/2026

Tham chiếu mới: [ảnh người dùng](references/scan-inline-camera.png). Giữ nền gradient xanh/mint, khung emerald viền sáng có bốn góc và lưới, cụm điều khiển trắng bo tròn và thẻ định dạng mint. Tái sử dụng token, font nền tảng và Material Icons. Icon tài liệu, độ chuyển gradient và font khác ảnh do không có tài sản gốc; không tái tạo khung điện thoại hay thanh trạng thái. Danh sách định dạng phản ánh backend thật, không thêm DOC/PPT theo hình minh họa.

`lib/scan_screen.dart` quản lý camera sau bằng package `camera`, không thu âm. Lần nhấn đầu bật preview ngay trong vùng quét, lần tiếp theo chụp và chuyển ảnh sang luồng nhập hiện có. Preview được clip trong khung và giữ toàn bộ tỷ lệ sensor, có khoảng nền khi tỷ lệ khác khung. Thư viện vẫn dùng bộ chọn ảnh hiện có. Camera được giải phóng khi app ra nền/rời màn, mở lại khi trở về; trạng thái tải, từ chối quyền, không có camera và thử lại có nội dung riêng. Ảnh chụp tạm được xóa sau khi đọc bytes; giới hạn 10 ảnh/12 MB được giữ.

Đã review bản render iPhone 17 Simulator so với ảnh mới: header tránh status bar, các góc khung và cụm điều khiển nằm trong vùng an toàn, không thấy overflow. [Ảnh trạng thái không có camera](../verification/scan-inline-camera/iphone-unavailable.png). Widget test kiểm tra bố cục ở điện thoại nhỏ với text scale 1,25 và tablet; không có bản render camera thật trên tablet.

Kiểm chứng: `flutter analyze --no-pub` không có vấn đề; `flutter test --no-pub` đạt 34 test, gồm preview trong khung/đúng tỷ lệ, chụp/đọc/xóa tệp tạm, từ chối quyền và vòng đời camera. Build iOS simulator thành công và đã cài/mở. Máy ảo không cung cấp camera; việc lấy hình và chụp trên phần cứng thật chưa được kiểm chứng.

## Menu bo tròn — 13/11/2026

Theo [mẫu menu](references/rounded-navigation.png), `StudyNavigation` giữ nền trắng, viền mint mảnh và bốn tab hiện có. Hai góc trên thanh bo 24 px; nền tab đang chọn và hiệu ứng chạm cùng bo 20 px, bao cả icon và nhãn. Tăng đệm dọc tab lên 10 px; dùng icon nhà outlined đồng nhất với mẫu. Giữ màu mint/xanh, font, SafeArea, trạng thái chọn cho trình đọc màn hình và tùy chọn giảm chuyển động. Thay đổi chỉ ở thành phần menu dùng chung; giữ nguyên điều hướng và dữ liệu.

Review thủ công bản render iPhone 17 ở tab Cá nhân: nền chọn bao trọn icon/nhãn, các góc bo rõ, không tràn hoặc đè home indicator. [Ảnh kiểm tra](../verification/rounded-navigation/iphone.png). 19 test app/motion đạt, bao gồm điện thoại nhỏ/tablet và giữ trạng thái khi đổi tab; analyzer sạch, build iOS simulator thành công. Chưa kiểm tra trên máy thật. Relay đang không kết nối ở lần kiểm tra giao diện này.
