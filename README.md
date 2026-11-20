# Đảo Đèn Lồng (Lantern Island) — Release v1.0.0

> **Video demo game:** [Xem video demo tại docs/demo/demo.mp4](docs/demo/demo.mp4) (hoặc xem tại GitHub Release v1.0.0)

Game 3D góc nhìn từ trên xuống (top-down), phát triển bằng Godot Engine 4.7 theo quy trình AI SDLC 4 Phase.  
Người chơi điều khiển Mây thu thập đom đóm, thắp sáng và duy trì nhiên liệu đèn lồng trên ba hòn đảo, né tránh Bóng Mực và Gió Lạc, dùng Xung Sáng để tự vệ và bảo vệ các ngọn đèn cho đến khi bình minh xuất hiện.

---

## 1. Cài đặt & Chạy nhanh (Tối đa 3 lệnh)

Yêu cầu: Đã cài [Godot Engine 4.7 Standard](https://godotengine.org/download) (hoặc Godot 4.7 console).

```bash
git clone https://github.com/SyxTun9/K5-L3A-DAY12-HoSyTung-2A202603650-AI-SDLC-Dao-Den-Long.git
cd K5-L3A-DAY12-HoSyTung-2A202603650-AI-SDLC-Dao-Den-Long
godot --path dao-den-
```

*(Trên Windows nếu `godot` chưa nằm trong PATH, có thể gọi trực tiếp file thực thi, ví dụ: `& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path dao-den-`)*

---

## 2. Điều khiển mặc định (Có thể đổi phím trong Cài đặt)

- **W / A / S / D:** Di chuyển nhân vật (tương đối theo góc xoay camera)
- **Space:** Nhảy
- **Shift:** Lướt (Dash) 14 m/s trong 0,2s (hồi chiêu 1,5s; bỏ hồi chiêu khi có Bùa Gió)
- **E:** Tương tác / Nạp đom đóm vào đèn ở gần
- **Q:** Xung sáng (Pulse), tiêu hao 3 đom đóm, làm choáng Bóng Mực trong bán kính 5m
- **P / Esc:** Tạm dừng (Pause menu); nhấn **R** để chơi lại đêm
- **Giữ chuột phải + rê chuột:** Xoay góc nhìn camera 360° linh hoạt
- **L:** Xem Bảng xếp hạng (Leaderboard) từ menu chính hoặc màn hình tạm dừng

---

## 3. Mục tiêu, Luật chơi & Tính điểm (Contract v1.3)

### Mục tiêu: Sống sót đến Bình Minh (Dawn Survival)
- Giữ ít nhất **60% số đèn sáng** đến bình minh (làm tròn lên):
  - **Đêm 1 (Đảo Bến):** Cần ít nhất 3 / 5 đèn sáng (240s).
  - **Đêm 2 (Đảo Cau):** Cần ít nhất 4 / 6 đèn sáng (270s).
  - **Đêm 3 (Đảo Chuông):** Cần ít nhất 5 / 7 đèn sáng (300s).
- **Nhiên liệu đèn:** Đèn sáng có 100 dầu, tự hao 1.0 đơn vị/giây. Đèn cạn dầu sẽ tắt; thắp lại cần 5 đom đóm (thắp lần đầu cần 10 đom đóm).
- **Bóng Mực hút dầu:** Đèn có dầu < 30 sẽ mất vùng an toàn 6m; Bóng Mực lang thang sẽ tiến đến và hút 5 đơn vị dầu/giây nếu trong cự ly 2m.
- **Sức chứa tăng dần:** Mây bắt đầu với sức chứa 10 đom đóm, mỗi lần thắp/thắp lại đèn thành công sẽ tăng sức chứa thêm 2 (tối đa 20).
- **Thất bại:** Mất hết 3 Ngọn Lửa, hoặc khi hết giờ mà số đèn sáng không đạt ngưỡng 60%.

### Cách tính điểm:
- Nạp đom đóm vào đèn: **+5 điểm** mỗi hạt
- Thắp mới một đèn: **+100 điểm**
- Thắp lại đèn đã tắt: **+40 điểm**
- Làm choáng Bóng Mực: **+5 điểm** (hoặc **+15 điểm** nếu nó đang hút dầu)
- Bình minh (chỉ khi thắng): **+50 điểm** + lượng dầu còn lại cho mỗi đèn đang sáng, cộng **+50 điểm** mỗi Ngọn Lửa còn lại.

---

## 4. Chế độ Headless, Benchmark & Soak Test

### Chạy mô phỏng Headless (60 Hz Deterministic)
```bash
godot --headless --path dao-den- --script res://scripts/headless.gd -- --seed 1 --night 1 --ticks 600 --out user://run.jsonl
```

### Chạy bộ kiểm thử hồi quy tự động (Phase 1–3 Regression Suite)
Yêu cầu Python 3. Script tự động phát hiện binary Godot trên máy:
```bash
python tests/run_phase1_checks.py
```
*(Kết quả: 16 scenario tests, kiểm tra tính tất định determinism và bắt lỗi input không hợp lệ đều PASS)*

### Chạy đo Benchmark (Phase 4)
Cảnh benchmark mở cửa sổ 1280×720, không vsync, sinh 200 Bóng Mực và 100 đom đóm, camera quay 360° trong 30 giây:
```bash
godot --path dao-den- --script res://scripts/bench.gd -- --seed 42 --duration 30 --out bench.json
```
- **Kết quả đo thực tế:** `avg_fps: 161.7` (ngưỡng ≥ 60), `p1_low_fps: 69.0` (ngưỡng ≥ 30), `load_ms: 286 ms` (ngưỡng ≤ 10000). Chi tiết tại [`bench.json`](bench.json).

### Chạy Soak Test kiểm thử sức bền (Phase 4)
Chạy 10 đêm liên tục trong cùng tiến trình với input ngẫu nhiên theo seed:
```bash
godot --headless --path dao-den- --script res://scripts/soak.gd -- --seed 7 --nights 10 --out soak.json
```
- **Kết quả đo thực tế:** 10 đêm 0 crash, bộ nhớ không rò rỉ (`mem_start_mb: 56 MB` → `mem_end_mb: 56 MB`). Chi tiết tại [`soak.json`](soak.json).

### Xuất Bảng Xếp Hạng qua CLI
```bash
godot --headless --path dao-den- -- --export-leaderboard out.json
```

---

## 5. Trợ năng & Dễ tiếp cận (Accessibility)

- **Đổi phím điều khiển (Key Remapping):** Hỗ trợ đổi phím cho toàn bộ 9 hành động trong menu Cài đặt, tự động phát hiện và cảnh báo nếu phím bị trùng lặp, có nút khôi phục mặc định.
- **Phụ đề & Chỉ báo trực quan:**
  - Cảnh báo xuất hiện Bóng Mực kèm mũi tên chỉ hướng tương đối ở mép màn hình.
  - Cảnh báo gió mạnh sắp thổi trước 2 giây.
  - Cảnh báo đếm ngược 10 giây cuối trước bình minh.
  - Cảnh báo và nhấp nháy hải đăng khi đèn lồng có dầu < 30.
- **Chế độ phân biệt màu (Colorblind mode):** Đổi màu viền Bóng Mực sang xanh dương `#00B3FF`, thêm ký hiệu cảnh báo ⚠.
- **Giảm rung chấn / chuyển động (Reduce motion):** Loại bỏ hiệu ứng rung màn hình và chớp giật.
- **Cỡ chữ UI:** Mặc định đạt 20 px (chuẩn ≥ 18 px ở 1280×720), có tùy chọn "Chữ lớn (×1.25)" nâng lên 25 px.

---

## 6. Sáng tạo của tôi (My Creative Additions)

Phần sáng tạo tuân thủ nghiêm ngặt nguyên tắc **không làm thay đổi Test Contract và đầu ra headless**:
1. **Thiết kế nhân vật & kẻ địch chi tiết bằng Procedural Mesh:** Nhân vật Mây được trang bị áo choàng dạ, khăn quàng cổ phấp phới, ủng da, ba lô phiêu lưu và mắt có biểu cảm; Bóng Mực có xúc tu chuyển động và đôi mắt phát quang quỷ dị.
2. **Hệ thống âm thanh tổng hợp đa tầng (Procedural Audio Synthesizer):** Tạo trực tiếp sóng âm PCM thời gian thực trong GDScript (tiếng gió rít, âm trầm Bóng Mực, tiếng bước chân, âm thanh xung sáng và nhạc nền ambient thư giãn) mà không cần tải bất kỳ tệp audio bên ngoài nào.
3. **Mũi tên Radar định vị thông minh trên HUD:** Tính toán góc yaw camera theo thời gian thực để hiển thị chính xác hướng và khoảng cách đến ngọn đèn gần nhất cũng như vị trí Bóng Mực đang lẩn khuất.

---

## 7. Tài liệu, Bằng chứng & Bản quyền

- **Bản Retro tổng kết 4 Phase & Nhật ký AI:** [`docs/notes/retro.md`](docs/notes/retro.md)
- **Đặc tả Phase 4:** [`docs/notes/phase-4-spec.md`](docs/notes/phase-4-spec.md)
- **Bằng chứng hiệu năng & Soak test:** [`docs/proof/phase4-performance-summary.md`](docs/proof/phase4-performance-summary.md)
- **Quyết định thiết kế kiến trúc (ADR-001):** [`docs/notes/adr-001-lamp-fuel-and-dawn-win.md`](docs/notes/adr-001-lamp-fuel-and-dawn-win.md)
- **Lịch sử cập nhật:** [`CHANGELOG.md`](CHANGELOG.md)
- **Chỉ dẫn cho AI Agent:** [`AGENTS.md`](AGENTS.md)
- **Tác giả & Bản quyền:** [`CREDITS.md`](CREDITS.md) | Giấy phép [`LICENSE`](LICENSE) (MIT)
