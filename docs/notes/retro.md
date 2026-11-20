# Báo Cáo Retrospective — Dự án Đảo Đèn Lồng (Phases 1–4)

**Học viên:** Hồ Sỹ Tùng — MSSV: 2A202603650  
**Dự án:** Game 3D Đảo Đèn Lồng (Godot 4.7 GDScript)  
**Mốc phát hành:** v1.0.0 (Contract 1.3)

---

## 1. Tổng kết đánh giá 4 Phase (Evaluation Across Phases)

| Phase | Trọng tâm | Thách thức chính | Kết quả |
|---|---|---|:---:|
| **Phase 1** (PRD-0) | Dựng core gameplay Đảo Bến, kiến trúc tách biệt render và headless contract 1.0 | Khái niệm mơ hồ về kích thước đảo và tầm tương tác; trục tọa độ WASD tương đối theo camera | Đạt 100% headless scenarios; tính tất định (determinism) byte-identical |
| **Phase 2** (Ticket-02) | Mở rộng 3 đảo (Đảo Bến, Đảo Cau, Đảo Chuông), bùa gió, Gió Lạc, bệ phóng, dash | Quản lý đồng bộ contract 1.1 khi thêm nhiều thực thể và trạng thái; cơ chế hồi chiêu và đẩy gió | Toàn bộ 11 scenarios mới và cũ đều pass; thời gian chạy đêm < 7s |
| **Phase 3** (Ticket-03) | Change Request: "Đèn cạn dầu", Bóng Mực hút dầu, luật thắng bình minh (dawn survival) | Phá vỡ logic cũ (không còn thắng sớm `all_lit`); cập nhật regression suite và sửa test kịch bản deposit | Hoàn thành ADR-001; 16 scenario tests trong Python harness pass 100% |
| **Phase 4** (Ticket-04) | Non-functional & Release: Benchmark 200 quái, Soak test 10 đêm, Leaderboard, Accessibility | Tối ưu FPS cảnh đông quái; tránh rò rỉ bộ nhớ qua 10 đêm chạy liên tục | `avg_fps` đạt 161.7 FPS; soak test 10 đêm 0 crash, bộ nhớ giữ nguyên 56 MB |

---

## 2. Những lần AI sai và cách phát hiện / khắc phục

Trong quá trình đồng hành cùng AI agent trong SDLC, một số lỗi tiêu biểu đã xuất hiện:

1. **Sai lệch góc nhìn và chiều trục tọa độ Camera (Phase 1):**
   - *Lỗi:* AI sinh vector di chuyển WASD bị ngược chiều Z khi xoay camera quanh người chơi.
   - *Cách phát hiện:* Kiểm tra tương tác thực tế và đọc snapshot tọa độ player qua các tick đầu.
   - *Cách sửa:* Chuẩn hóa phép quay vector `move.rotated(Vector3.UP, camera_yaw)` và ghi chú quy ước trục trong `AGENTS.md`.
2. **Kịch bản test hồi quy mang giá trị cũ (Phase 3):**
   - *Lỗi:* File kịch bản `tests/scenarios/deposit.json` giữ giá trị `carried: 5` từ Phase 1 (khi chi phí thắp đèn là 5), khiến test kiểm tra sự kiện `lantern_lit` bị fail khi luật Phase 2/3 nâng chi phí lên 10.
   - *Cách phát hiện:* Chạy kiểm tra thực tế bộ test `run_phase1_checks.py`, nhận `AssertionError` ở assert `lantern_lit`.
   - *Cách sửa:* Cập nhật số đom đóm mang lên 10 trong kịch bản; thêm ghi chú vào test suite giải thích rõ lý do thay đổi theo Contract 1.2.
3. **Phụ thuộc vào Windows Python App Execution Alias (Phase 3):**
   - *Lỗi:* Lệnh `python` mặc định trỏ vào shim `WindowsApps\python.exe` gây lỗi truy cập trong sandbox.
   - *Cách phát hiện:* Lệnh kiểm tra môi trường báo lỗi `ResourceUnavailable`.
   - *Cách sửa:* Cập nhật script test tự động dò tìm binary Python 3.13 thực và Godot executable trên hệ thống mà không cần thiết lập thủ công.
4. **Hàm không tồn tại trong Godot API (Phase 4):**
   - *Lỗi:* AI gợi ý `InputMap.clear_actions()` (vốn không phải static method của Godot 4).
   - *Cách phát hiện:* Chạy kiểm tra headless với tham số CLI bị bắt lỗi compile `Parse Error`.
   - *Cách sửa:* Chuyển sang duyệt danh sách action và gọi `InputMap.action_erase_events(action)`.

---

## 3. Harness AI nào hiệu quả nhất?

- **`AGENTS.md` (Hiệu quả cao nhất):** Giữ ngắn gọn (~20 dòng), cố định các lệnh build, lệnh chạy headless, quy ước tọa độ, và đặc biệt là quy tắc "Không xác nhận pass nếu thiếu bằng chứng thực thi". Điều này ngăn AI hallucinate kết quả.
- **Test Contract (`game.contract.json`):** Đóng vai trò như Single Source of Truth (SSOT). Mọi tuning, tên sự kiện, và tham số mô phỏng đều đối chiếu trực tiếp từ đây, giúp AI không tự ý bịa thêm tham số hoặc đổi kiểu dữ liệu giữa các phase.
- **Headless Scenario Harness (`tests/run_phase1_checks.py`):** Cho phép kiểm tra hồi quy tự động chỉ trong vài giây sau mỗi lần AI sửa code, phát hiện ngay lập tức bất kỳ side-effect nào lên các phase trước.

---

## 4. Quản lý và tiết kiệm Token

- **Ước tính sử dụng qua các Phase:**
  - Phase 1: ~45,000 tokens (dựng khung kiến trúc, Test Contract ban đầu).
  - Phase 2: ~35,000 tokens (thêm 2 map và entity mới).
  - Phase 3: ~30,000 tokens (refactor cơ chế dầu và luật thắng bình minh).
  - Phase 4: ~35,000 tokens (benchmark, soak test, leaderboard, accessibility).
  - *Tổng cộng toàn bộ lab:* ~145,000 tokens (tương đương khoảng \$0.15 - \$0.25 chi phí API).
- **Chiến lược tiết kiệm Token:**
  - Không nạp lại toàn bộ codebase vào prompt; chỉ đọc các hàm hoặc vùng cần chỉnh sửa thông qua `read_file` với dải dòng cụ thể.
  - Sử dụng các lệnh shell / script nhỏ để kiểm tra nhanh (verify locally) trước khi yêu cầu AI phân tích tiếp, tránh prompt lặp lại khi không có lỗi.
  - Kế hoạch rõ ràng trước khi code: duyệt qua acceptance criteria giúp hạn chế các lượt sửa sai (re-turns).

---

## 5. Bài học rút ra & Nếu làm lại thì đổi gì?

1. **Thiết kế kiến trúc Headless-first ngay từ tick đầu tiên:** Việc tách rời 100% logic mô phỏng (fixed 60 Hz) khỏi scene tree đồ họa giúp game chạy soak test và benchmark cực kỳ nhẹ và hoàn toàn tất định.
2. **Cập nhật đồng bộ Test Scenario khi có Change Request:** Khi thay đổi Contract (như chi phí đèn từ 5 lên 10), cần rà soát lại toàn bộ input/scenario JSON có liên quan ngay trong cùng commit để tránh fail kiểm tra hồi quy ngầm.
3. **Nếu làm lại:** Sẽ thiết lập sẵn CI/CD hoặc local git hook để tự động chạy `tests/run_phase1_checks.py` trước mỗi lần commit và gắn tag.
