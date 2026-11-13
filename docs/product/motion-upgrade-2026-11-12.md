# QM-MOTION — nâng cấp chuyển màn hình

PM: MausBot. Yêu cầu từ quyet qua Rio ngày 12/11/2026.
Dự án: /Users/quyetdev/Documents/QuizMind AI.

## Hiện trạng PM đã đọc
- Route dùng AppPageTransitionsBuilder chuyển Cupertino, bỏ animation khi disableAnimations.
- SmoothTabBody fade-out 90 ms / fade-in 180 ms, giữ IndexedStack; chặn tương tác khi motion chưa kết thúc.
- Chưa có Git repository. Báo cáo trước không tính là bằng chứng mới.

## Phạm vi và nghiệm thu
Nâng cấp chuyển route push/pop/replacement và chuyển tab, giữ màu xanh/mint và dữ liệu. Không sửa backend, cấu hình ECC, tính năng sản phẩm khác.
- AC1: Push/pop có chuyển động ngắn, liền mạch, quay lại đúng màn; giữ back gesture trên iOS nếu khả thi.
- AC2: Tab không chồng chữ/trượt xa; bấm nhanh nhiều tab kết thúc đúng tab cuối, không kẹt/ngoại lệ.
- AC3: Cuộn, nội dung form, đáp án nháp giữ nguyên sau chuyển tab/route.
- AC4: Giảm chuyển động có hiệu lực cả khi bật giữa animation; nội dung hiện đúng và nhận tương tác.
- AC5: Analyze, test phù hợp và build simulator có bằng chứng mới; không ghi đạt nếu chưa chạy.
- AC6: Linh kiểm chứng độc lập từng AC, bằng chứng và hạn chế. PM đọc hiện vật trước bàn giao.

## Backlog và quyền sở hữu
| ID | Chủ sở hữu | Đầu ra | Phụ thuộc | Trạng thái |
|---|---|---|---|---|
| MOT-01 | MausBot | Brief, tiêu chí, nguồn trạng thái này | Không | Đã kiểm chứng |
| MOT-02 | Kai | Motion spec ngắn, mã lib/theme.dart, lib/ui.dart; lib/main.dart chỉ nếu cần; test/app_test.dart hoặc test mới; báo cáo docs/verification/motion-dev-2026-11-12.md | MOT-01 | Đã bàn giao dev; PM đã đối chiếu hash/patch/log |
| MOT-03 | Linh | QA độc lập docs/verification/motion-qa-2026-11-12.md | MOT-02 | QA tự động đạt; UX bị chặn ENV-01 |
| MOT-04 | MausBot | Đối chiếu và bàn giao | MOT-03 | Đã đối chiếu hiện vật; bàn giao kỹ thuật, chưa nghiệm thu UX |

Kai sở hữu các file mã/test trên trong thời gian triển khai; PM chỉ sửa brief này. Linh chưa sửa mã; chỉ bắt đầu sau bàn giao Kai. Không ghi cùng file với hội thoại ECC; nếu phát hiện thay đổi ngoài phạm vi thì giữ nguyên và ghi rõ.

## Quyết định thường lệ
Ưu tiên chuyển động tinh tế, không bounce hoặc zoom mạnh; route khoảng 220–300 ms, tab tổng không quá 240 ms; thông số cuối do Kai chọn và ghi lý do sau đọc code. Không yêu cầu phê duyệt từng chặng.

## Đối chiếu PM sau bàn giao dev — 12/11/2026
PM đã đọc motion spec, báo cáo dev, patch và log analyze/test/build. Hash thực tế của ba file lib và test/motion_test.dart khớp báo cáo Kai. Patch giữ phạm vi route/tab và bổ sung controller tìm kiếm để giữ dữ liệu; không sửa backend. Log dev ghi analyze sạch, 18 test qua và build simulator exit 0; đây là bằng chứng dev đã đọc, PM chưa chạy lại và chưa quan sát UI bản mới. AC6 còn mở, chưa nghiệm thu. Linh sở hữu báo cáo QA và bằng chứng riêng, không sửa mã/brief hoặc ghi đè log dev.

## Phối hợp QA chức năng — 12/11/2026 13:08
Rio đã báo giao Linh kiểm thử riêng luồng tài liệu → bộ câu hỏi. Công việc MOT-03 vẫn mở, không bị thay thế. Hai báo cáo/bộ bằng chứng phải tách biệt. Chỉ Linh sử dụng simulator và relay trong các phiên QA; PM không khởi chạy hay thay đổi môi trường song song. Không sửa mã trong các nhiệm vụ QA. Nguồn trạng thái chức năng: document-to-quiz-qa-2026-11-12.md.

## Đối chiếu PM sau QA độc lập — 12/11/2026 13:12
PM đã đọc báo cáo QA, gates.json và log analyze/test/independent-test/ios-build trực tiếp. Tính lại SHA-256 của ba file lib và hai file test: khớp đầy đủ bản Kai/Linh. Log QA mới xác nhận analyze sạch, 18/18 test dự án và 4/4 probe độc lập qua, build iOS Simulator exit 0. PM không chạy lại gate vì không có thay đổi nguồn hoặc lỗi mới cần xác minh.

Kết luận: bàn giao phần triển khai và kiểm chứng tự động; **chưa nghiệm thu UX motion toàn phần**. AC3 đạt phạm vi widget, AC5 đạt; AC6 đã có QA độc lập và PM đối chiếu. AC1/AC2 còn thiếu quan sát chuyển động/gesture/chồng chữ; AC4 còn thiếu Reduce Motion trong Settings iOS thực tế. Không có lỗi sản phẩm tái hiện trong phạm vi QA đã chạy. ENV-01 là thiếu bề mặt Simulator quan sát được, không phải kết luận lỗi mã; chi tiết tái hiện nằm trong báo cáo QA. Chưa có video, frame timing hoặc bằng chứng chạy bản đúng hash trên UI.

Phần còn mở MOT-05: Linh kiểm tra UI trên simulator/device quan sát được khi môi trường sẵn sàng, theo các bước trong báo cáo QA; phụ thuộc giải quyết ENV-01 và điều phối môi trường với QA tài liệu → quiz. Không phát hành public/production. QA chức năng tài liệu → quiz tiếp tục ở nguồn trạng thái riêng, không suy ra đạt từ test motion.

Bàn giao 7 chặng: tiếp nhận/khám phá/chốt MVP — PM, brief hiện tại; thiết kế — Kai, motion spec; phát triển — Kai, patch và manifest; QA — Linh, báo cáo độc lập; đối chiếu — PM, mục này. Chuyển sang nghiệm thu UX chỉ khi có bằng chứng UI cho các AC còn mở. Đã đọc danh sách automation của PM: không có monitor liên quan motion cần dừng; giữ automation thường trực.
