# Đảo Đèn Lồng — Phase 2

Game 3D góc nhìn từ trên xuống, làm bằng Godot 4.7. Mây thu thập đom đóm, thắp đèn trên ba hòn đảo, né Bóng Mực và Gió Lạc, dùng xung sáng để đẩy lùi chúng.

Phase 2 chuẩn hóa gameplay bằng Contract 1.1, bổ sung ba đêm, dash, bệ phóng, bùa gió, Gió Lạc và mô phỏng headless cố định 60 tick/giây.

## Chạy game

Cài Godot 4.7 (standard), mở terminal tại thư mục repo và chạy:

```sh
godot --path dao-den-
```

Trên Windows nếu Godot chưa nằm trong PATH:

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "dao-den-"
```

## Điều khiển

- **W/A/S/D:** di chuyển tương đối theo camera
- **Space:** nhảy
- **Shift:** dash (14 m/s trong 0,2 giây; hồi chiêu 1,5 giây, bỏ hồi chiêu khi có Bùa Gió)
- **E:** nạp tối đa 10 đom đóm vào đèn ở gần
- **Q:** xung sáng, tốn 3 đom đóm, làm choáng mục tiêu trong 5 m
- **P / Esc:** tạm dừng; nhấn lại để tiếp tục, R để chơi lại đêm
- **Giữ chuột phải và rê:** xoay góc camera

## Mục tiêu và tính điểm

Giữ ít nhất 60% số đèn sáng đến bình minh trong ba đêm. Đèn có 100 giây dầu, có thể nạp bằng đom đóm; đèn tắt cần 5 hạt để thắp lại. Mây bắt đầu mang 10 hạt, sức chứa tăng 2 sau mỗi lần thắp thành công (tối đa 20). Mỗi đêm có 3 lửa và thời hạn 240, 270 hoặc 300 giây.

- Nạp đom đóm vào đèn: 5 điểm mỗi hạt
- Thắp một đèn: 100 điểm
- Mỗi Bóng Mực bị trúng xung sáng: 5 điểm
- Thắng bình minh: 50 điểm cộng lượng dầu còn lại cho mỗi đèn sáng, cùng 50 điểm mỗi lửa còn

Các thông số chuẩn nằm trong [`game.contract.json`](game.contract.json). Giả định Phase 1 ở [`docs/notes/phase-1.md`](docs/notes/phase-1.md).

## Chạy headless và kiểm tra

```sh
godot --headless --path dao-den- --script res://scripts/headless.gd -- --seed 1 --night 1 --ticks 600 --out user://run.jsonl
```

Muốn chạy bộ kiểm tra scenario cần Python 3 và Godot 4.7 trong PATH:

```sh
python3 tests/run_phase1_checks.py
```

Trên Windows có thể đặt `GODOT_BIN` trỏ tới executable Godot trước khi chạy script. Test Contract và các scenario của lab được mô tả trong [`game.contract.json`](game.contract.json) và [`tests/`](tests/).

## Bằng chứng, harness và ghi chép

- Scenario/output và kết quả kiểm tra: [`docs/proof/`](docs/proof/)
- Giả định, đánh giá AI và retro: [`docs/notes/phase-1.md`](docs/notes/phase-1.md)
- Quy tắc làm việc cho coding agent: [`AGENTS.md`](AGENTS.md)
- Nguồn asset và giấy phép: [`CREDITS.md`](CREDITS.md), [`LICENSE`](LICENSE)

Thông số chuẩn và lệnh chạy nằm trong [`game.contract.json`](game.contract.json). Theo dõi thay đổi Phase 3 tại [`docs/notes/phase-3-spec.md`](docs/notes/phase-3-spec.md), ADR và [`CHANGELOG.md`](CHANGELOG.md) cùng [`docs/proof/`](docs/proof/).
