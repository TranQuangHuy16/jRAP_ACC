# jRAP_ACC — Adaptive Cruise Control (Model-Based Design)

Mô hình Simulink cho hệ thống ga tự động thích ứng (ACC): xe tự bám tốc độ đặt khi đường trống, tự giảm
tốc bám theo xe phía trước khi có vật cản, phanh khẩn cấp khi nguy cơ va chạm, kèm cảm biến khoảng cách
phía trước và mô phỏng 2D trực quan.

---

## Yêu cầu môi trường

| Thành phần | Phiên bản |
|---|---|
| MATLAB / Simulink | **R2026a** (xem ghi chú bên dưới) |
| Stateflow | cần cho khối `ACC_Mode_Status` |

### Nếu bạn dùng R2025a

Dùng các model trong thư mục **`export_R2025a/`** — đuôi `.slx` bình thường, mở thẳng được.

> ⚠️ **Đừng dùng các file `<tên>.slx.r2025a`.** Đó **không phải** bản export. Đó là backup tự động do
> Simulink tạo ra khi lưu một model vốn được lưu lần cuối ở bản cũ hơn, và nội dung bên trong là phiên bản
> **trước khi sửa**. Ai đổi tên chúng ra dùng là đang chạy model lỗi thời mà không hề biết. Chúng đã được
> đưa vào `.gitignore`.

**Nếu bạn sửa model bằng R2026a, hãy sinh lại bản export TRƯỚC khi commit:**

```matlab
export_r2025a('check')   % xem bản nào đã lỗi thời
export_r2025a            % sinh lại tất cả vào export_R2025a/
```

---

## Chạy lần đầu

```matlab
cd 'D:\GO JAPAN 2026\project\jRAP_ACC'
startup                 % nạp path + tham số. BẮT BUỘC trước mọi thao tác khác
open_system('ACC_Main')
sim('ACC_Main')
```

`startup.m` làm hai việc: thêm `models/`, `scripts/`, `scripts/tests/` vào MATLAB path, và chạy
`acc_init_setup.m` để nạp tham số vào base workspace.

> ⚠️ **Bỏ qua `startup` là lỗi phổ biến nhất của dự án này.** Không có path, các khối Model-reference
> trong `ACC_Main` không tìm được model đích. Simulink sẽ báo cổng và đường nối "mất nguồn", và model nhìn
> như bị đứt hết dây dù thực tế hoàn toàn bình thường.

---

## Chạy kiểm thử

```matlab
startup
run('scripts/tests/run_acc_scenario_tests.m')
```

Kết quả mong đợi — **5/5 scenario pass** (~90 giây):

```
[PASS] AccScenarioTest/tPBI16_CruiseConvergesToDesiredSpeed
[PASS] AccScenarioTest/tPBI17_FollowingReducesSpeedBelowDesired
[PASS] AccScenarioTest/tPBI18_SpeedRestoresAfterLeadLeaves
[PASS] AccScenarioTest/tPBI19_EmergencyBrakeOverridesNormalControl
[PASS] AccScenarioTest/tPBI21_ProximityLevelTracksDistance
```

Chạy lẻ một kịch bản khi đang sửa lỗi:

```matlab
runtests('AccScenarioTest/tPBI19_EmergencyBrakeOverridesNormalControl')
```

Logic test nằm trong `scripts/tests/AccScenarioTest.m` (`matlab.unittest`). Mỗi test độc lập và tự khôi
phục mọi thay đổi lên model, kể cả khi fail giữa chừng. Runner xuất báo cáo JUnit XML vào `testresults/`
để gắn CI.

Đặc tả hành vi dạng Gherkin nằm trong `scripts/tests/*.feature` — đọc trước khi sửa logic điều khiển.

## Demo cảm biến khoảng cách

```matlab
startup
run('scripts/demo_front_sensor.m')
```

Xe phía trước chạy đều → phanh gấp → dừng ~2s → tăng tốc bỏ đi. Quan sát đèn cảm biến trước mũi xe ego
đổi màu xanh → vàng → đỏ và tiếng bíp dồn dập dần khi khoảng cách thu hẹp.

---

## Cấu trúc dự án

```
ACC_Main.slx              Model tích hợp toàn hệ thống (điểm vào chính)
startup.m                 Bootstrap môi trường — chạy đầu tiên
updateCar2D.m             Điểm vào của mô phỏng 2D (gọi từ Vehicle2DAnimation_Module)

+viz/                     Phần trình diễn của mô phỏng 2D
  RoadScene.m               Vẽ đường, hai xe, HUD, đồng hồ tốc độ
  ProximityBeeper.m         Nhịp bíp/nháy của cảm biến khoảng cách
  isAnimationDisabled.m     Đọc cờ ACC_DISABLE_ANIMATION

models/                   10 module con, đều là Model-reference của ACC_Main
  VehicleDynamics_Module      Động học xe: ga/phanh → gia tốc, vận tốc, vị trí
  DesiredSpeed_Module         Tốc độ đặt của người lái
  SpeedController_Module      Bộ điều khiển ga
  BrakeController_Module      Bộ điều khiển phanh
  LeadVehicle_Module          Kịch bản xe phía trước
  DistanceCalculation_Module  Khoảng cách và tốc độ tiếp cận
  EmergencyBrake_Module       Phanh khẩn cấp (ghi đè điều khiển thường)
  ProximitySensor_Module      Cảm biến khoảng cách trước
  Throttle_and_UI_Module      Hiển thị thông số
  Vehicle2DAnimation_Module   Cầu nối sang updateCar2D.m

scripts/
  acc_init_setup.m        Tham số môi trường ACC
  demo_front_sensor.m     Demo cảm biến khoảng cách
  export_r2025a.m         Sinh lại các bản *.slx.r2025a cho thành viên dùng R2025a
  tests/
    *.feature             Đặc tả hành vi (Gherkin)
    run_acc_scenario_tests.m   Test harness

docs/
  CODE_REVIEW_2026-07-26.md  Báo cáo review chất lượng + lộ trình refactor
```

### Kiến trúc tín hiệu (mức tổng quan)

```
DesiredSpeed ─┐
              ├─→ SpeedArbitration ─→ SpeedController ─→┐
LeadVehicle ──┤        (chọn min giữa tốc độ đặt        ├─→ EmergencyBrake ─→ VehicleDynamics
              │         và tốc độ bám an toàn)          │      (ghi đè)            │
              └─→ DistanceCalculation ─→ BrakeController┘                          │
                            │                                                      │
                            └──────────── phản hồi vị trí / vận tốc ───────────────┘
                                                  │
                            ProximitySensor ──────┴────→ Vehicle2DAnimation
```

---

## Tham số chính

Khai báo trong `scripts/acc_init_setup.m`:

| Tham số | Giá trị | Ý nghĩa |
|---|---|---|
| `a_throttle_mps2` | 2 | Gia tốc khi ga mở hết (m/s²) |
| `a_brake_mps2` | 2 | Giảm tốc khi phanh hết (m/s²) |
| `v_cruise_kmh` | 80 | Tốc độ đặt ban đầu (km/h) |
| `v_cruise_lowered_kmh` | 40 | Tốc độ đặt sau khi người lái hạ xuống ở t=12s (km/h) |
| `speed_tolerance` | 0.5 | Vùng sai số cho phép quanh tốc độ đặt (km/h) |
| `D_noLead_m` | 1000 | Khoảng cách báo về khi không có xe phía trước (m) |
| `D_emergency_m` | 8 | Khoảng cách kích hoạt phanh khẩn cấp (m) |
| `D_safe` | 20 | Khoảng cách an toàn tối thiểu (m) |
| `D_followBlend_m` | 60 | Khoảng cách vượt trên `D_safe` để trả hết về tốc độ đặt (m) |
| `k_closing` | 0.5 | Hệ số trừ theo tốc độ tiếp cận |
| `Sensor_FarRange_m` | 40 | Khoảng cách bắt đầu cảnh báo (m) |
| `Sensor_NearRange_m` | 3 | Khoảng cách cảnh báo cường độ tối đa (m) |
| `m`, `Cd`, `A`, `rho` | 1500 / 0.32 / 2.4 / 1.225 | Khối lượng và cản gió — ⚠️ **chưa nối**, xem bên dưới |

Tất cả tham số trên (trừ nhóm cuối) đều thực sự được model sử dụng — sửa giá trị ở đây là đổi được hành vi.
Kiểm chứng bằng:

```matlab
Simulink.findVars('ACC_Main','SearchReferencedModels',true)
```

> ⚠️ **`m`, `Cd`, `A`, `rho` chưa được nối** vì `VehicleDynamics_Module` hiện không mô hình hoá lực cản
> gió: gia tốc là hằng số theo mức ga, không phụ thuộc vận tốc, nên xe không có tốc độ tới hạn. Muốn dùng
> bốn tham số này phải **thêm khối** để tính `a = (F_ga − ½·ρ·Cd·A·v²)/m` — tức là đổi vật lý của model,
> không phải đổi tham số. Đây là quyết định về sản phẩm, chưa thực hiện.

**Quy ước:** mọi biến trong `acc_init_setup.m` phải được ít nhất một khối tham chiếu tới. Biến khai báo mà
model không dùng còn tệ hơn là không có — người đọc tưởng sửa ở đây là đổi được hành vi, trong khi giá trị
thật nằm hardcode trong khối.

---

## Quy ước đóng góp

- Nhánh làm việc: `dev`. Không commit thẳng vào `main`.
- **Chạy `run_acc_scenario_tests.m` trước khi commit** — phải xanh 5/5.
- File `.slx` là binary, Git không merge được. Thống nhất trước với team ai đang sửa model nào,
  hoặc cấu hình Simulink 3-way merge trước khi làm việc song song trên cùng một model.
- Commit message viết bằng một ngôn ngữ (khuyến nghị tiếng Anh), và **mô tả rõ đã đổi gì bên trong model** —
  với file binary thì commit message là tài liệu duy nhất người sau đọc được.

## Trạng thái chất lượng

Xem [`docs/CODE_REVIEW_2026-07-26.md`](docs/CODE_REVIEW_2026-07-26.md) — điểm hiện tại **6.5/10**, kèm lộ
trình refactor 3 sprint.
