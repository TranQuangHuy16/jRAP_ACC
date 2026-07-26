# Cập nhật Product Backlog — 2026-07-27

Nội dung soạn sẵn để dán vào Google Sheets
([link](https://docs.google.com/spreadsheets/d/17yGFZoBc-zwiE5DeZ5l_1LQWMNuCI2_0R6swH3CET-A/edit#gid=625752978)).

Gồm hai việc: **(1)** thêm PBI-21 cho cảm biến khoảng cách, **(2)** cập nhật cột `Status`.

---

## 1. Dòng mới: PBI-21

Cảm biến khoảng cách đã được cài đặt và kiểm thử nhưng không có trong backlog gốc (backlog chỉ tới PBI-20).
Thêm dòng này để tính năng có chỗ truy vết.

| Cột | Nội dung |
|---|---|
| **No** | 5 |
| **Epic** | Safety |
| **Product Backlog Item (PBI)** | PBI-21 |
| **Status** | Done |
| **Titile** | Cảnh báo khoảng cách phía trước |
| **User Story** | Là một người lái xe, tôi muốn được cảnh báo bằng đèn và âm thanh khi khoảng cách tới xe phía trước thu hẹp, để tôi nhận biết nguy cơ trước khi hệ thống phải phanh khẩn cấp. |
| **Acppentance** | - Không cảnh báo khi khoảng cách vượt ngưỡng xa (40 m) - Mức cảnh báo tăng dần khi khoảng cách giảm từ 40 m xuống 3 m - Đạt cường độ tối đa khi khoảng cách ≤ 3 m - Không cảnh báo khi không có xe phía trước, kể cả lúc giá trị khoảng cách nhỏ - Nhịp bíp và màu đèn (xanh → vàng → đỏ) thay đổi theo mức cảnh báo |
| **Priority** | Could |
| **Note** | Bổ sung sau khi Sprint 3 đã bắt đầu, không có trong backlog gốc. Cài đặt tại `models/ProximitySensor_Module.slx`, hiển thị trong mô phỏng 2D (`+viz/`). Ngưỡng cấu hình qua `Sensor_FarRange_m` / `Sensor_NearRange_m`. Kiểm thử: 4 kịch bản trong `scripts/tests/ProximitySensor_scenario.feature`, chạy tự động trong `AccScenarioTest`. |

### Dán nhanh (tab-separated — dán vào ô đầu dòng, Sheets tự tách cột)

```
5	Safety	PBI-21	Done	Cảnh báo khoảng cách phía trước	Là một người lái xe, tôi muốn được cảnh báo bằng đèn và âm thanh khi khoảng cách tới xe phía trước thu hẹp, để tôi nhận biết nguy cơ trước khi hệ thống phải phanh khẩn cấp.	- Không cảnh báo khi khoảng cách vượt ngưỡng xa (40 m) - Mức cảnh báo tăng dần khi khoảng cách giảm từ 40 m xuống 3 m - Đạt cường độ tối đa khi khoảng cách ≤ 3 m - Không cảnh báo khi không có xe phía trước, kể cả lúc giá trị khoảng cách nhỏ - Nhịp bíp và màu đèn (xanh → vàng → đỏ) thay đổi theo mức cảnh báo	Could	Bổ sung sau khi Sprint 3 đã bắt đầu, không có trong backlog gốc. Cài đặt tại models/ProximitySensor_Module.slx. Kiểm thử: 4 kịch bản trong scripts/tests/ProximitySensor_scenario.feature.
```

---

## 2. Cập nhật cột `Status`

**Toàn bộ 21 PBI đều đã hoàn thành.** Trước cập nhật, sheet chỉ đánh `Done` cho 6 PBI.

| PBI | Status cũ | Status mới | Bằng chứng |
|---|---|---|---|
| PBI-01 | Done | Done | — |
| PBI-02 | Done | Done | `VehicleDynamics_Module`: `a = F/m` với `F_engine_max`/`m`. **Trước 2026-07-27 tiêu chí "có xét đến khối lượng xe" chưa đạt** (gia tốc là `throttle × 2`), nay đã sửa |
| PBI-03 | Done | Done | — |
| PBI-04 | *(trống)* | **Done** | `ACC_Enable` + `ThrottleSelect`/`BrakeSelect` + `ManualThrottle`/`ManualBrake` trong `ACC_Main` |
| PBI-05 | *(trống)* | **Done** | `LeadVehicle_Module`: xuất hiện (`StepAppear`), biến mất (`StepDisappear`), phanh gấp (`LeadSpeed_kmh`), tăng tốc rời đi (`AccelerateAway`) |
| PBI-06 | *(trống)* | **Done** | `DistanceCalculation_Module`: khoảng cách, tốc độ tiếp cận, `CollisionFlag` |
| PBI-07 | Done | Done | Test `tPBI16` xanh: tốc độ hội tụ về tốc độ đặt, sai số 0.32 km/h |
| PBI-08 | *(trống)* | **Done** | Test `tPBI17` xanh: tốc độ trọng tài 6.29 km/h < tốc độ đặt 40 km/h khi bám xe chậm |
| PBI-09 | *(trống)* | **Done** | Test `tPBI18` xanh: quay lại đúng tốc độ đặt sau khi xe trước rời đi |
| PBI-10 | Done | Done | — |
| PBI-11 | Done | Done | — |
| PBI-12 | *(trống)* | **Done** | `D_safe` cấu hình được từ `acc_init_setup.m` (trước Sprint 2 là hằng số 20 chôn trong model nên tiêu chí *"có thể cấu hình"* chưa đạt); phân vùng khoảng cách qua `SpeedArbitration` |
| PBI-13 | *(trống)* | **Done** | Test `tPBI19` xanh: `Active=1`, `FinalThrottle=0`, `FinalBrake=1.00` |
| PBI-14 | *(trống)* | **Done** | `Throttle_and_UI_Module` hiển thị Speed, DesiredSpeed, LeadSpeed, Distance, Throttle, Brake, Acceleration, CollisionFlag + 3 Scope |
| PBI-15 | *(trống)* | **Done** | Stateflow `ACC_Mode_Status`: Off / Cruising / Following / Braking / Emergency Braking |
| PBI-16 | *(trống)* | **Done** | Test `tPBI16` xanh |
| PBI-17 | *(trống)* | **Done** | Test `tPBI17` xanh |
| PBI-18 | *(trống)* | **Done** | Test `tPBI18` xanh |
| PBI-19 | *(trống)* | **Done** | Test `tPBI19` xanh |
| PBI-20 | *(trống)* | **Done** | `run_acc_scenario_tests.m`: **5/5 kịch bản pass**, báo cáo JUnit tại `testresults/` |
| PBI-21 | *(mới)* | **Done** | Test `tPBI21` xanh: bão hoà 1.000 ở 2 m, im lặng ở 200 m, 0.541 ở 20 m, bị chặn khi không có xe trước |

### Dán nhanh cột Status

Dán vào ô `Status` của PBI-01, kéo xuống hết 21 dòng:

```
Done
Done
Done
Done
Done
Done
Done
Done
Done
Done
Done
Done
Done
Done
Done
Done
Done
Done
Done
Done
Done
```

---

## Cách tự kiểm chứng lại

```matlab
cd 'D:\GO JAPAN 2026\project\jRAP_ACC'
startup
run('scripts/tests/run_acc_scenario_tests.m')     % phải ra 5/5
```

Kết quả chạy ngày 2026-07-27:

```
[PASS] AccScenarioTest/tPBI16_CruiseConvergesToDesiredSpeed
[PASS] AccScenarioTest/tPBI17_FollowingReducesSpeedBelowDesired
[PASS] AccScenarioTest/tPBI18_SpeedRestoresAfterLeadLeaves
[PASS] AccScenarioTest/tPBI19_EmergencyBrakeOverridesNormalControl
[PASS] AccScenarioTest/tPBI21_ProximityLevelTracksDistance
5 / 5 scenarios passed
```

## Ghi chú cho Sprint Review

Nhóm đã tự ghi trong sheet rằng PBI-16 → PBI-20 *"thực chất không phải tính năng mà là kịch bản kiểm thử và
hoạt động xác nhận"*. Nhận định đó đúng, và hiện chúng đã được hiện thực hoá đúng như vậy trong code: mỗi
PBI tương ứng một `Scenario` trong `scripts/tests/*.feature` và một test method trong `AccScenarioTest.m`.
Nếu giảng viên hỏi, đây là bằng chứng nhóm hiểu vấn đề chứ không chỉ liệt kê cho đủ.
