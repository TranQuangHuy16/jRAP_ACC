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

Mỗi model có kèm một bản export `<tên>.slx.r2025a`. Chép bản đó thành `<tên>.slx` trong thư mục làm việc
của bạn (đừng commit đè lên bản chính).

**Nếu bạn sửa model bằng R2026a, hãy sinh lại các bản export TRƯỚC khi commit:**

```matlab
export_r2025a('check')   % xem bản nào đã lỗi thời
export_r2025a            % sinh lại tất cả
```

Bỏ bước này là đồng đội dùng R2025a sẽ chạy phải phiên bản model cũ mà không hề biết.

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
| `Sensor_FarRange_m` | 40 | Khoảng cách bắt đầu cảnh báo (m) — ✅ đang có tác dụng |
| `Sensor_NearRange_m` | 3 | Khoảng cách cảnh báo cường độ tối đa (m) — ✅ đang có tác dụng |
| `D_safe` | 20 | Khoảng cách an toàn tối thiểu (m) — ✅ đang có tác dụng |
| `D_followBlend_m` | 60 | Khoảng cách vượt trên `D_safe` để trả hết về tốc độ đặt (m) — ✅ |
| `k_closing` | 0.5 | Hệ số trừ theo tốc độ tiếp cận — ✅ |
| `v_target` | 30 | Tốc độ mong muốn (m/s) — ⚠️ chưa nối |
| `m`, `Cd`, `A`, `rho` | 1500 / 0.32 / 2.4 / 1.225 | Khối lượng và cản gió — ⚠️ chưa nối |
| `Kp`, `Ki`, `Kd` | 50 / 0.1 / 0 | Tham số PID — ⚠️ chưa nối |

> ⚠️ Các tham số đánh dấu "chưa nối" vẫn đang bị hardcode bên trong từng module (`VehicleDynamics_Module`,
> `EmergencyBrake_Module`...), nên **sửa giá trị ở đây sẽ không có tác dụng**. Việc nối chúng cần sửa các
> model đang lưu ở R2025a, nên đang chờ team thống nhất phiên bản MATLAB trước (mục S2.4 trong lộ trình).

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
