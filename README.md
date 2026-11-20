# Đảo Đèn Lồng — Phase 1

Game 3D góc nhìn từ trên xuống, làm bằng Godot 4.7. Mây thu thập đom đóm, thắp năm đèn lồng, né Bóng Mực và có thể dùng ánh sáng để làm chúng choáng.

> Phase 1 đang ở trạng thái triển khai và kiểm thử. Cần hoàn tất một lượt chơi tương tác từ đầu đến thắng/thua và ghi bằng chứng trước khi gắn tag nộp.

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
- **E:** nạp đom đóm vào đèn ở gần
- **Q:** tỏa sáng, tốn 1 đom đóm đang mang
- **Giữ chuột phải và rê:** xoay góc camera
- **R:** chơi lại sau thắng/thua

## Mục tiêu và tính điểm

Thắp đủ 5 đèn, mỗi đèn cần 5 đom đóm. Mây mang tối đa 10 đom đóm. Hết 3 lửa hoặc hết 300 giây thì thua.

- Nhặt đom đóm: 10 điểm
- Thắp một đèn: 100 điểm
- Làm choáng Bóng Mực: 5 điểm
- Mỗi giây còn lại khi thắng: 1 điểm
- Mỗi lửa còn lại khi kết thúc: 25 điểm

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

Video demo sẽ được bổ sung ở Release `v1.0.0` sau Phase 4.
