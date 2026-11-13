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

### Yêu cầu bổ sung khi tạo đề — 13/11/2026

Theo ảnh cấu hình tạo đề của người dùng, bổ sung ô nhiều dòng “Yêu cầu thêm cho AI (tùy chọn)” ngay sau số câu hỏi. Tái sử dụng InputDecoration, màu mint, viền và font hiện tại; không cần concept mới cho thay đổi cục bộ này. Ô nhập 3–5 dòng, tối đa 2.000 ký tự, có ví dụ về ngữ pháp/câu hỏi vận dụng và hướng dẫn để trống. Khi gửi, nội dung được trim và truyền qua `instructions`; relay kiểm tra kiểu/độ dài trước khi nhận tác vụ. Yêu cầu bổ sung là nội dung user, không thay thế chỉ dẫn hệ thống về nguồn, số câu, đáp án và JSON. Client cũ không gửi trường này vẫn hoạt động.

Kiểm chứng: analyzer sạch; 55 test Flutter và 33 test Python đạt, gồm nhập nhiều dòng, vị trí ô nhập trên bàn phím giả lập ở 393×852 và 1280×900, gửi nội dung/để trống, từ chối dữ liệu sai kiểu/quá dài và kiểm tra payload AI bằng mock. Đã review [ảnh widget 393 px](../verification/chatbot/instructions-393.png): ô nhập theo bố cục một cột, nhãn/hướng dẫn không tràn. Ảnh widget dùng Arial thay font nền tảng; một số chữ nút gradient không có glyph trong môi trường capture. Capture màn rộng chưa hoàn tất; không dùng ảnh này để khẳng định fidelity. Chưa chạy AI upstream hoặc cài bản mới lên iPhone thật.

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


## Chat với AI theo ảnh mẫu — 13/11/2026

Tham chiếu: [ảnh người dùng](references/chat-ai.png). Đối tượng là người học muốn mô tả nhanh một bộ đề; hành động chính là nhập yêu cầu rồi gửi. Giữ nền trắng, thẻ mint, điểm nhấn xanh, font hệ thống, bố cục một cột tối đa 720 px và nhịp khoảng cách 8/12/16/22/24 px. Thứ bậc: tiêu đề → thẻ chào có robot và vạch phân cách → số câu → gợi ý → mẹo nhập → thanh gửi cố định. Không thêm hiệu ứng chuyển động hoặc dependency. Tái sử dụng RobotArt, MintIcon, ChoicePill và token hiện hành; ChoicePill hỗ trợ icon tùy chọn để đánh dấu lựa chọn.

Ba thẻ gợi ý điền câu lệnh theo 5/10/15 câu đang chọn, chưa gửi API. Các từ “lớp 8”, “lớp 9” được giữ cùng dòng. Dưới 350 px nội dung hoặc khi tăng cỡ chữ, các gợi ý xếp dọc. Khi đã gửi, ẩn phần chào/gợi ý/mẹo để hội thoại và trạng thái tác vụ nằm trong vùng nhìn. Giữ khóa gửi trùng, báo lỗi, mở đề đã tạo, giới hạn 4.000 ký tự và bù bàn phím tại composer. Không đổi endpoint hoặc payload.

Design review thủ công trên [393×852](../verification/chatbot/chat-393.png) và [1280×900](../verification/chatbot/chat-1280.png): đúng thứ tự, căn lề, bo góc, nhóm màu và thanh gửi; không thấy overflow. Khác biệt đã biết: robot đọc sách sẵn có thay robot vẫy tay; mũ tốt nghiệp/sổ kiểm tra dùng Material Icons thay ảnh 3D; font hệ thống thay font gốc không được cung cấp. Không dựng viền điện thoại/status bar của ảnh minh họa. Capture dùng Arial, emoji bàn tay không có glyph trong môi trường widget; không coi đây là ảnh iPhone. Chưa đo tỷ lệ fidelity. Kiểm tra chi tiết ở [verification](../verification/chatbot/verification.md).


## Menu có nút quét nổi — 13/11/2026

Theo [mẫu người dùng](references/center-navigation.png): thanh trắng bo góc trên 30 px, bốn tab chia hai bên nút + xanh có viền trắng/mint và bóng mềm. Giữ token, font hệ thống, icon và trạng thái chọn của menu hiện hành. Nút tròn 80 px gồm vòng ngoài, nhô 24 px lên trên thanh; toàn bộ vùng chạm nằm trong bounds. Nhãn tab co vừa vùng hẹp, không xuống dòng. Dùng SafeArea cho home indicator, semantics/tooltip cho nút quét, không thêm animation. Điện thoại 320/393 px và tablet/desktop dùng cùng bốn tab, khe giữa 80 px.

Nút + ở Home và kết quả mở thẳng ScanScreen trong luồng ImportScreen hiện có. Khi có ảnh, trở về xem lại và nhập tên tài liệu; hủy khi chưa có ảnh trở lại màn trước, giữ tab cũ. Bot chat tiếp tục ở góc phải. Ảnh chỉ có mẫu menu; không dựng lại khung điện thoại hoặc thay thiết kế các màn khác. Không có font/asset gốc của mẫu nên tái sử dụng icon Material và font ứng dụng.

Review cuối: bản render 320/393/1280 px và ảnh iPhone 17 Simulator cho thấy nhãn một dòng, nút + đầy đủ và menu tránh vùng home indicator. Analyzer sạch, 58 test đạt, build/cài/mở simulator thành công. Chưa kiểm tra camera máy thật; relay đang báo lỗi xác thực. Xem [kết quả kiểm chứng](../verification/center-navigation/verification.md).

## Icon Hỏi AI theo mẫu — 13/11/2026

Tham chiếu: [ảnh người dùng](references/ai-launcher.png). Nút nổi 190×106 px ở góc phải trên menu: bong bóng kem viền xanh, chữ Hỏi AI và sao vàng, robot cắt trong vòng xanh 84 px có quầng sáng; anten vàng và điểm lấp lánh. Tái sử dụng robot, font hệ thống và điều hướng chat hiện có, không thêm chuyển động/dependency. Mặt robot được phóng lớn thay hình toàn thân để gần mẫu. Robot gốc khác ảnh mẫu nên không bảo đảm trùng từng chi tiết; giữ tài sản thương hiệu hiện hành. Toàn cụm là một nút có tooltip và hỗ trợ bàn phím. Bố cục dùng cùng kích thước ở điện thoại/tablet/desktop.

Review cuối: kiểm tra thủ công ở 320/393/1280 px và iPhone 17 Simulator; không tràn menu, chữ Hỏi AI một dòng và các chi tiết hiển thị đầy đủ. Analyzer sạch, 61 test (gồm 3 capture) đạt. Đã cài/mở bản mới trên simulator. Xem [kiểm chứng](../verification/ai-launcher/verification.md).
## Robot nhỏ và lời nhắn theo thời gian — 13/11/2026

Thu nhỏ vòng robot từ 84 xuống khoảng 61 px, vùng chạm 68×78 px; giữ vị trí góc phải trên menu và tài sản robot hiện hành. Bong bóng riêng bên trái chỉ nhận chạm khi hiện. Lời chào hiện sau 800 ms, giữ 5 giây rồi ẩn; các gợi ý sau cách nhau ngẫu nhiên 25–45 giây, không lặp liên tiếp. Chuyển động fade/slide 320 ms, tắt khi người dùng bật giảm chuyển động. Tạm dừng timer khi app ra nền, hủy khi dispose và bỏ qua lần hiện khi đang ở màn con.

Review thủ công các bản render 320/393/1280 px và iPhone 17 Simulator: robot nhỏ hơn, lời chào rõ, trạng thái ẩn giữ robot và không chặn vùng bong bóng. Giữ màu/font/điều hướng hiện có. Xem [kiểm chứng](../verification/ai-launcher-timed/verification.md).


## Tiến trình iOS / Live Activity

- Dùng ActivityKit (iOS 16.2+) và WidgetKit; iPhone có Dynamic Island hiển thị compact/minimal/expanded, thiết bị khác dùng Live Activity trên màn hình khóa khi được hỗ trợ.
- Kế thừa màu xanh `#008F21`, dùng chữ hệ thống và SF Symbols của iOS để phù hợp vùng hệ thống. Nội dung gồm QuizMind AI, bước thực tế và số tác vụ đồng thời; không đưa tên/nội dung tài liệu, tin nhắn hoặc thông tin kết nối ra màn hình khóa.
- Theo dõi thao tác gửi backend và các job queued/extracting/generating/validating. Hoàn tất và thất bại có biểu tượng riêng, tự đóng sau 20 giây; đổi relay đóng ngay. Không tạo Activity từ lịch sử tác vụ đã kết thúc.
- Không có phần trăm thực tế từ backend nên dùng chỉ báo chờ. Sau 30 giây không cập nhật, giao diện ghi “Mở app để cập nhật tiến trình”. iOS chỉ cấp thời gian nền ngắn; cập nhật sau khi app bị đình chỉ cần APNs (chưa được cấu hình), không giả định polling Dart chạy nền vô hạn.
- Đây là bổ sung hành vi vào giao diện hệ thống, không thiết kế lại màn hình app nên không tạo mockup mới. Design review áp dụng kiểm tra màu, độ dài trạng thái, vùng compact và tính trung thực của dữ liệu; skill design-review được cài chỉ là catalogue, không có upstream runner.

### Center scan icon
- Replace the plus with a white 34 px scan frame and glowing scan line; preserve the existing green 80 px button, menu layout, tooltip and scanner route.
- Sweep down/up for 2.2 seconds on appearance, then rest in the center. Reduced motion displays the static icon immediately. No new assets or dependencies.

### Floating menu reference refinement
- Reference: `references/floating-menu.png`. Preserve the four tabs and scanner action. White floating pill with 16 px side insets, 28 px corners, a curved central recess and soft green shadow. Selected tab uses the existing mint token and rounded 22 px background.
- Scan button: 72 px white outer ring, 60 px green interior, raised 24 px above the bar. Keep the existing scan animation and reduced-motion behavior. Safe-area clearance stays outside the floating pill. Retain app typography and responsive labels.

Manual design review: 320/393/1280 px captures and iPhone 17 Simulator confirm the curved recess, soft shadow, raised scanner and single-line navigation labels. Reuse existing Material icons and app font; source font/icon assets were not supplied. See [verification](../verification/floating-menu/verification.md).

### Menu shadow and curved outline correction
- Feedback reference: `references/menu-shadow-feedback.png`; keep the original floating menu reference authoritative. The elevation-only version lost its outline against the white screen.
- Paint the exact recessed silhouette with a 1 px mint border, broad green shadow (12 px down, sigma 12, 15% alpha) and close contact shadow (4 px down, sigma 4, 7% alpha). Preserve tab sizing, safe area, scan control and animation.
- Manual design review at 320/393/1280 px and iPhone Simulator; border follows both shoulders and the central U recess, shadow remains soft without a thick solid frame. Analyzer clean, 15 focused tests passed.

### Scan button clearance — 14/11/2026
- Raise the center scan button another 6 px relative to the menu (30 px rise instead of 24 px). Keep its 72 px diameter, curved border and shadows; the bottom gap grows from approximately 3 to 9 px.

### Transparent area behind floating navigation — 14/11/2026
- Extend Home and results content behind the floating menu. Disable only the bottom SafeArea for these scroll views and retain the navigation-height inset as scroll padding so final actions remain reachable above the menu.
- Keep the white menu silhouette, curved mint outline, two shadows, scan clearance and animation. No new assets or visual concept.
- Manual design review on iPhone 17 Simulator confirms loaded content is visible in the central recess and below the menu, without a rectangular background strip. Screenshot: `../verification/floating-menu/iphone-transparent-background.png`.
