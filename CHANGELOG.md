# Changelog

## [1.0.0] - Phase 4 — Contract 1.3 (2026-11-20)

### Added
- **Chế độ Benchmark (`bench.gd`):** Mô phỏng 200 Bóng Mực lang thang và 100 đom đóm trong môi trường Đêm 1 với camera quay tròn 360°, xuất kết quả đo lường `bench.json` chuẩn hóa.
- **Soak Testing (`soak.gd`):** Chạy kiểm thử sức bền 10 Đêm liên tiếp không tắt tiến trình với input giả lập ngẫu nhiên theo seed; đạt 0 crash và độ tăng trưởng bộ nhớ 0% (56 MB → 56 MB).
- **Bảng xếp hạng cục bộ (Leaderboard):** Lưu trữ persistent tại `user://leaderboard.json`, giao diện xem Top 10 và hộp thoại nhập tên người chơi (3–12 ký tự [A-Za-z0-9_]); hỗ trợ lệnh xuất CLI `--export-leaderboard <path>`.
- **Trợ năng & Dễ tiếp cận (Accessibility):**
  - Đổi phím điều khiển (Key Remapping) trong mục Cài đặt với cơ chế phát hiện trùng phím và nút khôi phục mặc định.
  - Phụ đề và chỉ báo hình ảnh: thông báo xuất hiện Bóng Mực kèm mũi tên chỉ hướng ở mép màn hình, cảnh báo gió mạnh, cảnh báo 10 giây cuối trước bình minh, cảnh báo đèn yếu (<30 dầu).
  - Tùy chọn giảm rung chấn / chuyển động (Reduce motion).
  - Tùy chọn phóng to chữ giao diện (Large UI text ×1.25).
- **Test Contract v1.3:** Bổ sung `bench_cmd` và `soak_cmd` vào `game.contract.json`.

## Phase 3 — Contract 1.2 (2026-11-20)

### Breaking changes
- Đêm kéo dài 240/270/300 giây. Điều kiện thắng chuyển sang sống sót đến bình minh và giữ sáng ≥ 60% số đèn. Bỏ cơ chế thắng sớm `all_lit`.
- Đèn có 100 dầu, tự hao 1.0 đơn vị/giây, có thể nạp thêm đom đóm (10 dầu/hạt) và cần 5 hạt để thắp lại sau khi cạn dầu. Đèn dưới 30 dầu mất vùng an toàn và bị Bóng Mực hút dầu (5 đơn vị/giây).
- Điểm thưởng tính theo đom đóm nạp (+5), thắp lần đầu (+100), thắp lại (+40), làm choáng Bóng Mực (+5, hoặc +15 nếu đang hút dầu), và thưởng bình minh (50 + sàn(dầu) mỗi đèn sáng, 50 mỗi ngọn lửa còn lại).
- Sức chứa đom đóm tăng từ 10 thêm 2 sau mỗi lần thắp thành công, tối đa 20.
- Snapshot và sự kiện bổ sung trường dầu, trạng thái hút dầu (`drain`), sự kiện `refuel`, `lantern_out`, `fuel_drain`, lý do kết thúc `dawn_survived`.

### Added
- Giao diện thanh dầu trên đèn và hiệu ứng nhấp nháy khi dầu dưới 30.
- Chế độ mù màu (Colorblind mode) với viền xanh dương `#00B3FF` và biểu tượng cảnh báo.
- Kịch bản test headless cho nạp dầu, thắp lại, hút dầu, thắng và thua bình minh.

## Phase 2 — Contract 1.1 (2026-11-20)

### Added
- Ba hòn đảo riêng biệt: Đảo Bến (Đêm 1), Đảo Cau (Đêm 2 - đảo đôi kết nối bằng cầu và bệ phóng), Đảo Chuông (Đêm 3 - đài chuông, gió xoay vần).
- Cơ chế lướt (Dash) 14 m/s, Bùa Gió tăng tốc và bỏ hồi chiêu lướt, thực thể Gió Lạc trộm đom đóm.
- Menu chính, màn hình giới thiệu đêm, màn hình kết quả, menu tạm dừng (Pause), lưu cấu hình âm lượng và độ nhạy chuột.

## Phase 1 — Contract 1.0 (2026-11-20)

### Added
- Core gameplay 3D góc nhìn từ trên xuống tại Đảo Bến với Mây, đom đóm, 5 ngọn đèn lồng và Bóng Mực.
- Cơ chế xung sáng làm choáng và đẩy lùi Bóng Mực.
- Kiến trúc mô phỏng headless fixed 60 Hz deterministic với định dạng JSONL snapshot và events theo Contract v1.0.
