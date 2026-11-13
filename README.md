## Chạy nhanh trên iOS

Từ thư mục dự án:

```sh
./dev     # Chạy debug trên máy ảo iOS, tự bật backend nếu cần.
./build   # Build release, cài và mở app trên iPhone thật với URL ngrok cố định.
```

Dừng `./dev` bằng Ctrl+C trước khi chạy `./build`; các lệnh dùng chung khóa để tránh Xcode build đồng thời.

Kết nối iPhone, mở khóa và chọn tin cậy Mac trước khi chạy `./build`. Hai lệnh tự chọn thiết bị iOS đầu tiên phù hợp. `./build` kiểm tra tunnel và tự bật nếu chưa chạy; giữ terminal và Mac thức để app dùng backend. Nếu cổng 8787 đang có backend riêng nhưng tunnel chưa chạy, dừng backend riêng trước rồi chạy lại. API AI Cockpit cần đang hoạt động theo cấu hình hiện có.

`./dev` chạy debug với hot reload tắt vì Flutter hiện tại vẫn ghi một phần cache hot reload vào `build/`. Chạy lại lệnh sau khi sửa code. Máy này thiếu ứng dụng Simulator trong Xcode; lệnh vẫn cài/chạy được trên simulator đã boot, nhưng cần khôi phục ứng dụng Simulator để xem cửa sổ.

Flutter sử dụng cấu hình riêng trong `.local/flutter-config` và xuất artifact vào `.flutter-build/`, vì tên `build` được dùng cho lệnh. Khi gọi Flutter thủ công trong dự án, chạy `source scripts/flutter-env.sh` sau khi đặt `ROOT="$PWD"` để dùng cùng cấu hình.

# QuizMind AI

Ứng dụng Flutter biến tài liệu thành bài trắc nghiệm tiếng Việt. Bản đầu dành cho một người dùng, chạy cùng dịch vụ local trên Mac.

## Chức năng hiện có

- Nhập PDF, TXT/MD UTF-8, JPG/PNG; chọn ảnh từ thư viện hoặc chụp bằng camera trên mobile.
- Chat với AI qua nút robot nổi ở góc phải các tab chính: mô tả chủ đề, chọn 5/10/15 câu, theo dõi tác vụ và mở bộ đề khi hoàn tất. Nội dung AI tạo được lưu trong thư viện và có nhãn riêng ở phần giải thích.
- Xem lại và sắp xếp ảnh trước khi gửi, kiểm tra chữ đã đọc trước khi tạo đề.
- OCR trên Mac bằng PDFKit/Vision, hỗ trợ nhận dạng tiếng Việt và tiếng Anh.
- Đặt tên tài liệu bắt buộc; nhập số câu từ 1–100 hoặc chọn nhanh 5/10/15. AI có thể trả ít câu hơn nếu nguồn ngắn.
- Làm bài, giữ đáp án nháp trên thiết bị, chấm điểm, giải thích và trích dẫn theo trang.
- Lưu tài liệu, bộ đề, tác vụ và lịch sử trên Mac. Tác vụ AI không tự gọi lại khi lỗi hoặc khởi động lại dịch vụ.

## Chạy trên máy này

Yêu cầu: macOS, Xcode command-line tools, Python 3 và Flutter. Swift extractor được biên dịch ở lần mở dịch vụ đầu tiên. Các dependency Flutter đã có trong cache máy hiện tại.

1. Mở API AI local đã có của bạn.
2. Mở terminal trong thư mục dự án và chạy:

```sh
./scripts/start-server.sh
```

Dịch vụ lắng nghe tại `http://127.0.0.1:8787`. Giữ terminal này mở.

3. Trong terminal khác:

```sh
flutter pub get --offline
flutter devices
python3 scripts/flutter-local.py run -d <device-id>
```

Lệnh này tự tạo hoặc dùng lại token của relay trên Mac và cấp cấu hình cho app; không cần nhập token trong tab **Cá nhân**, kể cả khi mở lại app. Relay vẫn cần chạy ở terminal đầu tiên. Với iPhone Simulator, địa chỉ loopback trỏ về Mac.

Build riêng cũng dùng cùng lệnh để giữ kết nối tự động:

```sh
python3 scripts/flutter-local.py build ios --simulator --debug --no-pub
```

Đây là build cá nhân gắn với relay của máy này: token có trong bản build, không chia sẻ bản build hoặc các tệp cấu hình build. Tệp JSON tạm quyền `0600` được xóa khi lệnh kết thúc; token gốc được giữ tại `~/.config/quizmind/relay-token`. Sau khi đổi/xóa token gốc, cần build lại app và khởi động lại relay để dùng cùng token.

Với Android nối USB hoặc emulator có ADB, chuyển cổng trước khi chạy app:

```sh
adb reverse tcp:8787 tcp:8787
python3 scripts/flutter-local.py run -d <android-device-id>
```

## Một lệnh bật backend + tunnel cho điện thoại thật

Trong thư mục dự án, chạy:

```sh
python3 scripts/start-phone.py
```

Lệnh tự bật relay, kiểm tra Bearer token, mở Cloudflare Tunnel và kiểm tra HTTPS (không token phải trả 401, token đúng trả 200). Không tắt backend đang chạy từ lệnh khác; nếu cổng 8787 đã dùng, hãy dừng terminal backend cũ trước. Cần `cloudflared` trong PATH hoặc `~/.local/bin/cloudflared`. Giữ terminal mở và Mac có mạng, không ngủ; Ctrl+C dừng cả hai tiến trình. Lệnh không tự bật dịch vụ API AI riêng của bạn.

Sau khi báo sẵn sàng, cài app lên điện thoại một lần với địa chỉ/token tự động:

```sh
flutter devices
python3 scripts/flutter-local.py --phone run -d <device-id>
```

Bản build riêng có thể dùng `python3 scripts/flutter-local.py --phone build ios --release`. iPhone cần cấu hình ký ứng dụng của Xcode. Token được giữ trong tệp build tạm quyền 0600, không đưa lên dòng lệnh. Không chia sẻ bản app cá nhân chứa token.

**Mặc định yêu cầu URL cố định** trong `tunnel.json` như hướng dẫn dưới đây. Nếu chưa có, lệnh dừng để tránh tự đổi URL. Chỉ khi chủ động thêm `--temporary` mới tạo tunnel tạm; URL tạm đổi khi chạy lại và cần cài lại cấu hình app. Địa chỉ và log được lưu riêng tại `~/.config/quizmind/phone-url` và `phone.log`; không chia sẻ các tệp này. Địa chỉ chỉ được công bố sau khi kiểm tra HTTPS thành công, và bị xóa khi dừng lệnh.

**URL cố định miễn phí, không có tên miền riêng:** dùng tài khoản [ngrok](https://dashboard.ngrok.com/signup). Mỗi tài khoản được cấp một dev domain cố định. Cài `brew install ngrok`, sau đó thực hiện bước kết nối agent theo dashboard ngrok trong terminal riêng; không gửi authtoken vào chat hoặc lưu trong dự án. Tạo `~/.config/quizmind/tunnel.json` với hostname được cấp (không kèm `https://`):

```json
{
  "provider": "ngrok",
  "hostname": "YOUR-ASSIGNED-DOMAIN.ngrok-free.dev"
}
```

Chạy cùng lệnh `python3 scripts/start-phone.py`. Script dùng chính xác URL này, không tự chuyển sang URL ngẫu nhiên nếu ngrok lỗi. Request inspection của ngrok được tắt bằng `--inspect=false`; backend vẫn yêu cầu token và chỉ chấp nhận đúng hostname. Sau khi kiểm tra HTTPS thành công, cài app bằng `--phone` một lần. Những lần bật lại backend/tunnel sau đó giữ nguyên URL và token thì không cần cài lại app. Gói miễn phí có giới hạn lưu lượng/yêu cầu theo tài khoản; chưa có tài khoản thì chưa thể cấp và kiểm tra URL thật.

**Nếu đã có tên miền riêng:** dùng Cloudflare named tunnel và hostname cố định. Sau khi tạo tunnel và bản ghi DNS trỏ tới tunnel đó trong tài khoản Cloudflare của bạn, tạo `~/.config/quizmind/tunnel.json`:

```json
{
  "hostname": "quiz.example.com",
  "tunnel": "12345678-1234-1234-1234-123456789abc",
  "credentials_file": "/absolute/path/to/tunnel-credentials.json"
}
```

Thay các giá trị minh họa bằng hostname, UUID và tệp credentials thật của bạn; giữ credentials riêng tư. Chạy lại cùng lệnh `python3 scripts/start-phone.py`, rồi cài app bằng `--phone`. Những lần sau chỉ cần bật lệnh này và mở app; không cần build lại nếu địa chỉ và relay-token không đổi. Script chỉ định tuyến đúng hostname đó đến loopback, các hostname khác trả 404. Script không tự tạo tài khoản, sửa DNS hay cấp tunnel Cloudflare.

Relay vẫn chỉ lắng nghe loopback; đổi địa chỉ sang IP Wi-Fi trong app sẽ bị từ chối. Kết nối điện thoại đi qua HTTPS tunnel và vẫn bắt buộc Bearer token.

## Cấu hình API AI

Cấu hình đã được tạo riêng trên máy tại `~/.config/quizmind/ai.json`, bên ngoài dự án. App không chứa khóa AI. Mẫu cho một máy mới, hãy thay giá trị minh họa bằng khóa riêng của máy đó:

```json
{
  "base_url": "http://localhost:57220/v1",
  "api_key": "REPLACE_WITH_YOUR_LOCAL_API_KEY",
  "model": "gpt-6.1-sol"
}
```

Giới hạn quyền thư mục `0700`, tệp `0600`. Không đưa tệp thật vào Git hoặc chia sẻ cùng app. Có thể chọn đường dẫn riêng qua biến `QUIZMIND_AI_CONFIG` trước khi mở server. Upstream phải là `http://localhost:<port>/v1` hoặc `http://127.0.0.1:<port>/v1`, tương thích `/models` và `/chat/completions`.

Luồng dữ liệu: app → relay trên Mac → API AI đã cấu hình. Đọc PDF/OCR diễn ra trên Mac. Khi bấm tạo đề, văn bản được gửi đến API AI; API local này vẫn có thể chuyển tiếp đến nhà cung cấp bên ngoài. Không mặc định coi đây là suy luận AI hoàn toàn offline.

Relay bỏ qua proxy môi trường, không theo redirect, không ghi body hoặc khóa vào log, và từ chối yêu cầu có browser Origin. Đây là dịch vụ cá nhân trên cùng máy, chưa có tài khoản hay cơ chế phân quyền nhiều người dùng.

## Giới hạn đầu vào và dữ liệu

- Tối đa tổng 12 MB/lần, 10 ảnh; PDF tối đa 20 trang, không có mật khẩu.
- Văn bản sau trích xuất từ 80 đến 50.000 ký tự. Chưa hỗ trợ DOCX/PPTX, viết tay hoặc công thức phức tạp như một tính năng đã kiểm chứng.
- Nguồn gốc trích dẫn được kiểm tra bằng đối chiếu văn bản. Điều đó chưa bảo đảm toàn bộ suy luận hoặc đáp án AI đều đúng; luôn có thể đối chiếu nguồn trong kết quả.
- Tệp ảnh/PDF tạm được xóa sau trích xuất. Chữ đã đọc, bộ đề và lịch sử còn trong `~/.local/share/quizmind/state.json` (quyền `0600`). Có thể chọn thư mục khác bằng `QUIZMIND_DATA`.
- Vuốt trái tài liệu ở Trang chủ hoặc Thư viện để hiện **Đổi tên / Xóa**; vuốt hết không tự xóa. Đổi tên bắt buộc 1–160 ký tự sau trim, không đổi tên bộ đề đã lưu trong lịch sử. Tác vụ đang xử lý sẽ chặn đổi tên/xóa tài liệu liên quan.
- **Xóa** có xác nhận tên và dùng cơ chế ẩn hiện có: tài liệu cùng dữ liệu liên quan được ẩn khỏi thư viện; dữ liệu vẫn còn trong bản lưu trên Mac. Chưa có giao diện xóa vĩnh viễn/khôi phục.
- Nháp đáp án và địa chỉ relay được lưu trong SharedPreferences của thiết bị. Dữ liệu trên Mac chưa được mã hóa riêng ngoài cơ chế bảo vệ ổ đĩa của hệ điều hành.

## Kiểm tra

```sh
python3 -m unittest discover -s server -p 'test_*.py' -v
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --simulator --debug --no-pub
```

Xem [bằng chứng kiểm tra](docs/verification/2026-11-12.md) và [quyết định giao diện](docs/design/DESIGN.md). Build macOS hiện vướng TLS khi tải chỉ mục CocoaPods; Android và camera trên thiết bị thật chưa được kiểm chứng.
