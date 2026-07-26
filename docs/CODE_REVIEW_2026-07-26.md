# Báo cáo Review Dự án jRAP_ACC

| | |
|---|---|
| **Ngày review** | 2026-07-26 |
| **Đính chính & xác minh lại** | 2026-07-27 |
| **Nhánh** | `dev` |
| **Commit HEAD** | `47049f5` — *feat: added distance warning sensor* |
| **Phạm vi** | Toàn bộ repo: `ACC_Main.slx`, 10 model-reference trong `models/`, script MATLAB, test harness, cấu hình Git |
| **Phương pháp** | Đọc tĩnh toàn bộ file + kiểm chứng động trên MATLAB (compile, sim 30s, chạy test suite, truy vấn kết nối/tham số) |
| **Tiêu chí đối chiếu** | Thực hành chuẩn doanh nghiệp cho Model-Based Design ô tô: MAAB style guidelines, nguyên tắc ISO 26262, CI/CD, quản lý cấu hình, sẵn sàng code-gen |

---

## ⚠️ 0. Đính chính quan trọng (2026-07-27)

**Bản review đầu tiên có 4 kết luận SAI, đều nằm ở phần nghiêm trọng nhất.** Đã xác minh lại và sửa.

| Kết luận sai ban đầu | Sự thật đã kiểm chứng |
|---|---|
| "24 dangling line ở root level, plant bị cô lập hoàn toàn" | **Sai.** Load sạch từ đĩa: 83 line object, **0 line mất nguồn** ở root |
| "VehicleDynamics: 5/5 outport không có line nào" | **Sai.** `out1 → Model1`; `out2 → Model5, Model7, Model1`; `out3 → Model1, Model5, Model7, Model4, Model3`. Chỉ `out4`/`out5` là thừa |
| "Ego speed = 0 hằng số, throttle kẹt 1.0, hệ chạy open-loop" | **Sai.** Sim 30s thật: `VD_out3` (speed) 0 → 39.60 km/h bám desired 40; `VD_out2` (position) 0 → 321.58 m |
| "Test 3/5 pass, PBI-16 và PBI-17 fail, PBI-18 pass giả" | **Sai.** Chạy lại: **5/5 PASS** |

### Nguyên nhân lỗi

Khi bắt đầu review, MATLAB đang giữ `ACC_Main` trong bộ nhớ ở trạng thái đã được load **khi thư mục
`models/` chưa nằm trên MATLAB path**. Các khối Model-reference không resolve được model đích, nên Simulink
báo cổng và đường nối của chúng là "mất nguồn". Toàn bộ truy vấn kết nối ban đầu chạy trên trạng thái hỏng đó.

Sau khi `bdclose('all')` → `addpath` → `load_system` lại, mọi kết nối hiện đầy đủ và bình thường.

> **Bài học rút ra và ghi lại ở đây để tránh lặp:** trước khi kết luận bất cứ điều gì về cấu trúc một model
> Simulink, phải load lại sạch với đầy đủ path. Trớ trêu là chính sự cố này **chứng minh** phát hiện
> "thiếu bootstrap path" (mục 3.1) là thật và nghiêm trọng: một model hoàn toàn lành lặn có thể trông như
> hỏng nặng chỉ vì thiếu một dòng `addpath`.

### Kết quả test thật (sau khi load đúng)

```
[PASS] PBI-16 Normal cruise converges to desired speed
       finalSpeed=40.39 finalDesired=40.00 err=0.39
[PASS] PBI-17 Following reduces speed below desired
       t=20.0 effective=6.34 desired=40.00
[PASS] PBI-18 Effective speed restores after lead vehicle leaves
       t=29.0 effective=40.00 desired=40.00
[PASS] PBI-19 Emergency brake overrides normal control
       Active=1 FinalThrottle=0.00 FinalBrake=1.00
[PASS] PBI-21 Proximity sensor tracks distance to lead vehicle
       Saturated(2m)=1.000 Silent(200m)=0.000 Partial(20m)=0.541 Gated=0.000
---------------------------------------
5 / 5 scenarios passed
```

---

## 1. Tổng kết điểm

### **Tổng điểm: 6.5 / 10**

| Tiêu chí | Điểm | Ghi chú |
|---|---|---|
| Tính đúng đắn chức năng | 8/10 | Model chạy đúng, 5/5 test pass; trừ điểm vì algebraic loop |
| Kiến trúc / phân rã module | 7/10 | Tách 10 model-reference rõ ràng — điểm mạnh nhất |
| Naming & MAAB style | 3/10 | `Model`, `Model1`…`Model8` ở top level |
| Quản lý tham số / data management | 3/10 | 13/15 biến chết, phần lớn giá trị hardcode trong model |
| Khả năng tái lập (reproducibility) | 2/10 | Clone về **không chạy được**, không có project/startup |
| Test & traceability | 6/10 | Test xanh + Gherkin + PBI ID (tốt), nhưng harness thủ công, không CI |
| Vệ sinh repo & quy trình Git | 4/10 | Commit artifact build, không README, không PR |
| Sẵn sàng code-gen / embedded | 3/10 | Solver variable-step, algebraic loop, không data type |

### Nhận định chung

**Phần chức năng của dự án là lành mạnh.** Vòng điều khiển đóng đúng, các module hoạt động, toàn bộ 5 kịch
bản test đều xanh. Vấn đề nằm ở **hạ tầng kỹ thuật và vệ sinh** chứ không ở logic: thiếu bootstrap khiến
người mới không chạy được, diagnostics bị tắt khiến lỗi tiềm ẩn không nổi lên, tên khối mặc định khiến code
khó đọc, và không có CI nên không có gì bảo vệ trạng thái xanh hiện tại.

---

## 2. 🔴 P0 — Cần xử lý trước

### 2.1. Diagnostics bị tắt

```
UnconnectedInputMsg  = none
UnconnectedOutputMsg = none
UnconnectedLineMsg   = none
```

Với giá trị `none`, Simulink âm thầm nối ground/terminator vào cổng hở thay vì cảnh báo. Hiện tại model
đang đúng, nhưng đây là **tấm lưới an toàn đã bị gỡ**: nếu ai đó vô tình làm đứt một dây, sim vẫn chạy và
không ai biết. Trong quy trình ISO 26262 / MAAB, việc tắt 3 diagnostic này bị bắt lỗi ngay khi audit.

**Khuyến nghị:** đặt về `warning` (hoặc `error` sau khi đã dọn sạch mục 2.2).

### 2.2. Cổng hở và khối chết còn tồn đọng

Trên bản load sạch, `model_check` báo 16 cảnh báo — không nghiêm trọng nhưng cần dọn:

| Loại | Chi tiết |
|---|---|
| Output không nối (5) | `VehicleDynamics`: `Throttle_Out`, `Brake_Out`<br>`LeadVehicle`: `ObstaclePresent`, `ObstacleSpeed_kmh`, `ObstaclePosition_m` |
| Khối chết (2) | `ACC_Main/Throttle Delay`, `ACC_Main/Brake Delay` (khối `Memory`, output không đi đâu) |
| Đoạn line thừa (6) | Đều nằm trong `SpeedArbitration` |

Toạ độ 6 đoạn line thừa trong `SpeedArbitration` (để tìm trên canvas):

```
từ ClosingGain        (335,285) -> (395,205)
từ (không nguồn)      (335,240) -> (375,175)
từ LeadSpeed_kmh      ( 65,160) -> (395,145)
từ (không nguồn)      (275,240) -> (295,240)
từ DistAboveSafe      (215,235) -> (235,240)
từ ActualDistance_m   ( 65,220) -> (195,265)
```

Đây là các stub bị bỏ lại sau khi sửa sơ đồ. Chúng không ảnh hưởng kết quả sim nhưng làm `model_check` ồn
và che mất lỗi thật.

### 2.3. Algebraic loop (phát hiện mới, thật)

Simulink cảnh báo mỗi lần sim:

```
Warning: Model 'ACC_Main' contains 1 algebraic loops.
Found algebraic loop that contains:
  SpeedArbitration/{SafeFollow_NonNeg, MinSpeed, SelectByLeadPresent, Closing_Pos,
                    ClosingGain, DistAboveSafe, FracGain, Frac, Weighted,
                    SafeFollowBase, SafeFollowSpeed}
  Model3 (SpeedController), Model4 (BrakeController), Model7 (DistanceCalculation),
  Model8 (EmergencyBrake), Model (VehicleDynamics), BrakeSelect, ThrottleSelect
Warning: Discontinuities detected in one or more algebraic loops might prevent
         the algebraic loop solver from solving the loop.
```

Vòng đại số đi xuyên qua toàn bộ chuỗi điều khiển. Hiện solver vẫn giải được, nhưng:
- Simulink nói rõ các khối gián đoạn (Saturate, Switch, MinMax) **có thể** làm solver không hội tụ
- Không thể sinh code embedded khi còn algebraic loop
- Nghiệm phụ thuộc solver → kết quả test không đảm bảo tái lập

**Cách sửa:** bật `Minimize artificial algebraic loop occurrences` cho các model-reference trong vòng,
hoặc chèn một khối trễ (`Unit Delay`/`Memory`) tại đúng một điểm cắt vòng — nhiều khả năng là ở đường phản
hồi từ plant về `DistanceCalculation`. Đáng chú ý: hai khối `Throttle Delay` / `Brake Delay` ở mục 2.2 rất
có thể đã được tạo ra đúng cho mục đích này nhưng chưa nối vào.

### 2.4. Clone repo về là không chạy được

Đây chính là lỗi đã làm review lần đầu sai. Bằng chứng:

```
UPDATE DIAGRAM FAILED: Unable to find model 'Throttle_and_UI_Module'
                       referenced by 'ACC_Main/Model1'
MATLAB path: không có folder nào của project
```

Nguyên nhân:

- Không có Simulink Project (`.prj`), không có `startup.m`
- `ACC_Main` không có callback nào: `PreLoadFcn`, `PostLoadFcn`, `InitFcn`, `StartFcn` đều **rỗng**
- `scripts/acc_init_setup.m` không hề gọi `addpath`
- Mỗi script phải tự hack path riêng: `demo_front_sensor.m:8`, `scripts/tests/run_acc_scenario_tests.m:14`

Đây là tiêu chí *"developer mới onboard và chạy được trong 15 phút"* mà mọi doanh nghiệp đều kiểm.

---

## 3. 🟠 P1 — Nợ kỹ thuật

### 3.1. Naming vi phạm MAAB ở tầng quan trọng nhất

Top level của `ACC_Main`: `Model`, `Model1`, `Model2`, `Model3`, `Model4`, `Model5`, `Model6`, `Model7`, `Model8`.

Hệ quả lan sang cả test code:

```matlab
phLP = get_param('ACC_Main/Model6','PortHandles');   % run_acc_scenario_tests.m:72
component = "ACC_Main/Model8"                         % EmergencyBrake_scenario.feature
```

| Block ID | Tên hiện tại | Nên đặt |
|---|---|---|
| `blk_3` | `Model` | `VehicleDynamics` |
| `blk_4` | `Model1` | `ThrottleAndUI` |
| `blk_9` | `Model2` | `DesiredSpeed` |
| `blk_10` | `Model3` | `SpeedController` |
| `blk_12` | `Model4` | `BrakeController` |
| `blk_14` | `Model5` | `Vehicle2DAnimation` |
| `blk_16` | `Model6` | `LeadVehicle` |
| `blk_17` | `Model7` | `DistanceCalculation` |
| `blk_19` | `Model8` | `EmergencyBrake` |

**Điểm tích cực:** ba khối mới nhất (`ProximitySensor`, `SpeedArbitration`, `ACC_Mode_Status`) đã đặt tên chuẩn.

### 3.2. Quản lý tham số rời rạc

`Simulink.findVars` trên bản load đúng:

```
Được model dùng thật:  Sensor_FarRange_m, Sensor_NearRange_m   (2/15)
KHÔNG được dùng (13):  m, Cd, A, rho, D0, D_safe, Kp, Ki, Kd,
                       v0_ego, v0_lead, v_target, speed_tolerance

Chi tiết theo module:
  VehicleDynamics_Module    : KHÔNG dùng biến workspace nào (hardcode toàn bộ)
  EmergencyBrake_Module     : KHÔNG dùng biến workspace nào (hardcode toàn bộ)
  SpeedController_Module    : chỉ hằng số nội bộ
  BrakeController_Module    : chỉ hằng số nội bộ
  DistanceCalculation_Module: chỉ hằng số nội bộ
```

Nghĩa là khối lượng xe, hệ số cản gió, tham số PID, khoảng cách an toàn... đều hardcode bên trong model,
còn `scripts/acc_init_setup.m` chỉ mang tính trang trí. Ví dụ trong `ACC_Main/SpeedArbitration`:

```
SafeDistance_m : Value = 20        ← lẽ ra phải tham chiếu D_safe
FracGain       : Gain  = 0.016667  ← magic number (= 1/60), không có tài liệu
ClosingGain    : Gain  = 0.5       ← magic number
```

Ngược lại, `ProximitySensor_Module` làm **đúng chuẩn** — nên dùng làm mẫu:

```
FarRange_m : Value = Sensor_FarRange_m
RangeNorm  : Gain  = 1/(Sensor_FarRange_m - Sensor_NearRange_m)
```

**Khuyến nghị:** chuyển sang **Simulink Data Dictionary (`.sldd`)**. Đổ biến rời vào base workspace với tên
một ký tự (`m`, `A`) rất dễ bị script khác ghi đè mà không có cảnh báo.

### 3.3. Version model không đồng nhất

```
Lưu ở R2025a (6): BrakeController, DesiredSpeed, DistanceCalculation,
                  EmergencyBrake, SpeedController, VehicleDynamics
Lưu ở R2026a (5): LeadVehicle, ProximitySensor, Throttle_and_UI,
                  Vehicle2DAnimation, ACC_Main
```

Cộng 6 file `*.slx.r2025a` (bản export song song) được commit → **mỗi model có 2 nguồn sự thật**. Mỗi lần
sim đều hiện cảnh báo `Model 'X' was exported from R2026a to R2025a`.

Doanh nghiệp luôn pin **một** release MATLAB duy nhất cho cả team và ghi rõ trong README.

### 3.4. Test harness chưa đạt chuẩn tự động hóa

**Điểm tốt (nên giữ):** 4 file `.feature` viết rõ, đúng cấu trúc Given/When/Then, có front-matter TOML map
tín hiệu, map được PBI → scenario. Và hiện tại **test đang xanh 5/5** — đây là tài sản thật.

**Vấn đề:**

| # | Vấn đề | Vị trí |
|---|---|---|
| 1 | File `.feature` **không được chạy** — `run_acc_scenario_tests.m` là bản fallback viết tay, spec và test có thể trôi khỏi nhau | `run_acc_scenario_tests.m:1-6` |
| 2 | Test **sửa chính model đang test** (`set_param` StepAppear, đổi `OutDataTypeStr` boolean→double), khôi phục bằng `close_system/load_system`. Script chết giữa chừng là model bị bẩn | dòng 35-36, 138, 172, 224-231 |
| 3 | **Phụ thuộc thứ tự chạy**: PBI-18 tái sử dụng cấu hình logging của PBI-17 → không chạy độc lập được | dòng 101 |
| 4 | Không dùng `matlab.unittest` → không có exit code, không xuất JUnit XML → **không thể gắn CI** | toàn file |
| 5 | Không đo coverage | — |
| 6 | 5 block `catch ME` lặp gần như y hệt (~6 dòng mỗi block) | dòng 55-62, 90-93, 115-118, 159-162, 218-221 |
| 7 | Dùng `assignin('base',...)` truyền cờ `ACC_DISABLE_ANIMATION` — side effect ngoài phạm vi test | dòng 22, 233 |
| 8 | Không có ngưỡng cho algebraic loop warning — test xanh nhưng cảnh báo bị bỏ qua | — |

### 3.5. Vệ sinh repo

| Vấn đề | Chi tiết |
|---|---|
| Commit artifact build | `ProximitySensor_Module.slxc` bị commit **3 lần**: root, `scripts/`, `scripts/tests/` |
| File rác | `data/New Text Document.txt` (rỗng, đang track), `work/New Text Document.txt` |
| `.env` rỗng bị commit | Rủi ro: lần sau ai đó điền secret vào là lộ ngay |
| Không có `README.md` | Không ai biết cách chạy project |
| Không có `.gitattributes` | `.slx` là binary → không merge/diff được; cần `*.slx binary` + Simulink 3-way merge |
| Không có backlog/docs | Commit `d14be53 feat: complete product backlog` nhưng repo không chứa file backlog nào |
| Không có LICENSE, không CI | Không có `.github/workflows/` |

### 3.6. Quy trình Git

Bốn người đóng góp: `JustHungDEVer`, `TranQuangHuy16`, `thuongnguyenTN`, `Meocute5104`.

- Lịch sử tuyến tính, commit thẳng — không thấy PR / code review
- Hai commit **trùng hệt message**: `feat: added distance warning sensor` (`47049f5` và `10e15a8`)
- Message trộn Việt–Anh: `Cập Nhật 2 Module mới`, `change previous version down to rb2025a` (lặp 2 lần)
- Commit chỉ chứa binary `.slx` mà không mô tả thay đổi bên trong — với model binary thì **commit message
  là tài liệu duy nhất**
- Tồn tại nhánh `dev-backup` — dấu hiệu backup thủ công thay vì tin vào Git

---

## 4. 🟡 P2 — Nâng lên chuẩn production

- **Solver**: `VariableStepAuto`, `StopTime=30`. Hệ điều khiển hướng embedded phải dùng **fixed-step** với
  sample time xác định (vd. 0.01s) mới nói chuyện được về code-gen và mới cho kết quả test lặp lại được.
- **Không có data type discipline**: mọi tín hiệu là `double`. Test phải hack `OutDataTypeStr` từ `boolean`
  sang `double` để bơm input — dấu hiệu interface chưa thiết kế cho testability.
- **Chưa chạy Model Advisor / compliance check** bao giờ.
- **Traceability** mới dừng ở PBI ID trong comment. Chuẩn doanh nghiệp cần Requirements Toolbox link hai
  chiều: requirement ↔ model ↔ test.
- **`updateCar2D.m`** là file *chất lượng tốt nhất* repo — comment giải thích "tại sao", giới hạn 30fps,
  guard `isgraphics`, tách hàm rõ ràng. Ba điểm cần sửa:
  - `evalin('base', ...)` chạy **mỗi frame** (dòng 31) → truyền qua tham số hoặc `Simulink.Signal`
  - `sound()` gọi trong vòng lặp solver (dòng 56) → nên tách khỏi model
  - 385 dòng trộn render + audio + state → tách thành package `+viz/`

---

## 5. Lộ trình refactor

### Sprint 1 — Nền tảng ✅ HOÀN THÀNH (2026-07-27)

- [x] **S1.1** Thêm `startup.m` + bootstrap path; `acc_init_setup.m` tự `addpath`; `ACC_Main` có `PostLoadFcn`
- [x] **S1.2** Thêm `README.md`: yêu cầu môi trường, cách chạy, cấu trúc dự án, quy ước đóng góp
- [x] **S1.3** Vệ sinh Git: gỡ 3 `*.slxc`, `.env`, file placeholder khỏi index; mở rộng `.gitignore`; thêm `.gitattributes`
- [x] **S1.4** Xoá 6 đoạn line mồ côi trong `SpeedArbitration`; gắn 5 `Terminator` cho output chủ đích không dùng
- [x] **S1.5** Bật lại 3 diagnostics unconnected về `warning`
- [x] **S1.6** Kiểm chứng: test **5/5 pass**, `model_check` **16 → 2 cảnh báo**

### Sprint 2 — Chất lượng model ✅ HOÀN THÀNH phần lớn (2026-07-27)

- [x] **S2.1** Đổi tên 9 khối `Model`…`Model8` → tên nghiệp vụ; cập nhật `run_acc_scenario_tests.m` và `EmergencyBrake_scenario.feature`
- [x] **S2.2** **Xoá sạch algebraic loop** — nối 2 khối `Memory` (`Throttle Delay`/`Brake Delay`) đang bị bỏ không vào đường `EmergencyBrake → VehicleDynamics`. Đây đúng là ý đồ thiết kế ban đầu bị dở dang
- [x] **S2.3** Thay 3 magic number trong `SpeedArbitration` bằng tham số có tên (`D_safe`, `D_followBlend_m`, `k_closing`), sau đó nối tiếp 8 tham số nữa trong 6 module (nhóm A) và xoá 7 biến chết (nhóm C); số biến workspace được model dùng thật: **2 → 12**
- [x] **S2.4** ~~Thống nhất một release MATLAB~~ → **Team quyết định giữ R2025a**. Thay vì hợp nhất phiên bản, đã tự động hoá việc sinh bản export bằng `scripts/export_r2025a.m`. Phát hiện lúc chạy: **8/11 model có bản R2025a thiếu hoặc lỗi thời**, riêng `ProximitySensor_Module` chưa hề có — người dùng R2025a khi đó không thể chạy dự án. Đã sinh lại đủ 11 bản
- [x] **S2.5** Viết lại harness bằng `matlab.unittest` (`AccScenarioTest.m`), độc lập thứ tự chạy, tự khôi phục cờ Dirty, xuất JUnit XML
- [ ] **S2.6** Gom tham số về Simulink Data Dictionary (`.sldd`) — hoãn, cần làm cùng lúc với việc nối tham số vào các module R2025a

### Sprint 3 — Sẵn sàng production

- [x] **S3.6** Refactor `updateCar2D.m`: 385 dòng → 55 dòng + package `+viz/` (3 lớp). Bỏ `evalin` mỗi
      khung hình (nay 1 lần/lần sim), thay việc dựng vector sin mỗi tiếng bíp bằng `audioplayer` dựng sẵn
- [ ] **S3.1** Chuyển fixed-step solver + định nghĩa sample time — *hoãn theo yêu cầu*
- [ ] **S3.2** GitHub Actions chạy test tự động mỗi PR — *hoãn theo yêu cầu* (runner đã sẵn sàng: harness
      xuất JUnit XML)
- [ ] **S3.3** Model Advisor như một quality gate
- [ ] **S3.4** Bật đo decision coverage
- [ ] **S3.5** Traceability requirement ↔ model ↔ test (Requirements Toolbox)

---

## 6. Điểm sáng cần giữ

1. **Chức năng đúng và test xanh 5/5** — nền tảng vững, mọi việc còn lại là dọn dẹp chứ không phải làm lại.
2. **Phân rã kiến trúc sạch** — 10 model-reference tách bạch theo chức năng, interface rõ ràng.
3. **File `.feature` viết chuẩn Gherkin**, map PBI ID → scenario. Ý định traceability đúng hướng.
4. **`ProximitySensor_Module` parameterize đúng cách** — dùng làm mẫu cho các module còn lại.
5. **Comment giải thích "tại sao" chứ không phải "cái gì"** — thói quen tốt và hiếm gặp. Ví dụ
   `run_acc_scenario_tests.m:10-13` giải thích vì sao phải `addpath` thủ công; dòng 32-34 giải thích vì sao
   phải tắt cả hai step block thay vì một.

---

---

## 7. Nhật ký refactor

### 2026-07-27 — Sprint 1 + Sprint 2

Toàn bộ thay đổi đều được kiểm chứng bằng bộ test sau mỗi bước. Test **xanh 5/5 ở mọi thời điểm**.

| Chỉ số | Trước | Sau |
|---|---|---|
| Cảnh báo `model_check` | 16 | **0** |
| Algebraic loop | 1 (kèm cảnh báo discontinuity) | **0** |
| Line mồ côi trong `SpeedArbitration` | 6 | **0** |
| Diagnostics unconnected | `none` (tắt) | `warning` |
| Tên khối mặc định ở top level | 9 | **0** |
| Biến workspace được model dùng thật | 2/15 | 5/18 |
| Test chạy lẻ được từng kịch bản | không | **có** |
| Xuất báo cáo cho CI | không | **JUnit XML** |

Kết quả số của test gần như không đổi, xác nhận refactor không làm lệch hành vi:

```
PBI-16  err  0.39 -> 0.32 km/h     (khối Memory cắt vòng đại số giúp hội tụ tốt hơn chút)
PBI-17  effective  6.34 -> 6.29 km/h
PBI-18/19/21  không đổi
```

**Về algebraic loop:** hai khối `Throttle Delay` và `Brake Delay` đã nhận sẵn `FinalThrottle`/`FinalBrake`
từ `EmergencyBrake` với `InitialCondition = 0`, nhưng output bỏ trống — rõ ràng ai đó đã dựng đúng lời giải
rồi bỏ dở chưa nối. Chỉ cần chuyển `VehicleDynamics` sang lấy tín hiệu qua hai khối này là vòng đại số biến
mất hoàn toàn.

**Về file `*.slxc` và `.env`:** đã `git rm --cached` (gỡ khỏi Git, vẫn còn trên đĩa).

### 2026-07-27 — Sprint 3 (phần đã chọn làm)

**`updateCar2D.m`: 385 dòng → 55 dòng**, phần còn lại tách vào package `+viz/`:

| File | Vai trò |
|---|---|
| `updateCar2D.m` | Điểm vào cho khối MATLAB Function: kiểm tra cờ tắt, giới hạn ~30fps, uỷ quyền |
| `+viz/RoadScene.m` | Toàn bộ phần vẽ: đường, hai xe, HUD, đồng hồ tốc độ, camera |
| `+viz/ProximityBeeper.m` | Nhịp bíp/nháy của cảm biến |
| `+viz/isAnimationDisabled.m` | Đọc cờ `ACC_DISABLE_ANIMATION` |

Hai điểm nóng đã xử lý:
- `evalin('base',...)` từ **mỗi khung hình** → **1 lần cho mỗi lần sim** (nhận biết sim mới qua việc
  `simTime` tụt xuống).
- Mỗi tiếng bíp trước đây dựng lại một vector sin ngay trong vòng lặp solver → nay 8 mức cao độ được dựng
  sẵn thành `audioplayer` và tái sử dụng.
- 17 biến `persistent` rời rạc → thuộc tính của hai đối tượng có vòng đời rõ ràng.

Kiểm chứng: `checkcode` sạch, sim 12s **có bật animation** chạy tốt và tạo đúng cửa sổ, test vẫn 5/5.

### 2026-07-27 — Nối tham số (nhóm A) và dọn biến chết (nhóm C)

Sprint 3 dừng lại vì không đủ thời gian (S3.1/S3.2/S3.3 hoãn, S3.4 vốn không làm được do máy thiếu
Simulink Coverage). Thay vào đó xử lý dứt điểm phần tham số.

**Nhóm A — nối 1:1, giá trị giữ nguyên nên hành vi không đổi:**

| Khối | Trước | Sau |
|---|---|---|
| `EmergencyBrake_Module/EmergencyDistance_m` | `8` | `D_emergency_m` |
| `SpeedController_Module/Error_GT_0.5` | `0.5` | `speed_tolerance` |
| `BrakeController_Module/Compare To Constant1` | `-0.5` | `-speed_tolerance` |
| `VehicleDynamics_Module/acceleration` | `2` | `a_throttle_mps2` |
| `VehicleDynamics_Module/Brake Deceleration Gain` | `2` | `a_brake_mps2` |
| `DesiredSpeed_Module/Step` Before/After | `80` / `40` | `v_cruise_kmh` / `v_cruise_lowered_kmh` |
| `DistanceCalculation_Module/Constant` | `1000` | `D_noLead_m` |

Số biến workspace được model dùng thật: **5 → 12**. Test vẫn 5/5, số liệu không đổi.

**Nhóm C — xoá 7 biến chết.** Ba trong số đó không chỉ chết mà còn **sai lệch**, ai tin vào chúng sẽ hiểu
nhầm hệ thống:

| Biến | Khai báo | Thực tế trong model |
|---|---|---|
| `D0` | 50 m | `LeadPosition_m` IC = **60** |
| `v0_lead` | 15 m/s (=54 km/h) | `LeadSpeed_kmh` step = **50 km/h** |
| `v0_ego` | 20 m/s | Integrator IC = **0** (xe khởi đầu đứng yên) |
| `Kp`, `Ki`, `Kd` | 50 / 0.1 / 0 | **Không có bộ PID nào** trong toàn bộ 10 module. Cả SpeedController lẫn BrakeController đều là điều khiển đóng-mở |
| `v_target` | 30 m/s (=108 km/h) | Tốc độ đặt thực tế 80→40 km/h |

Đồng thời xoá một khối `Constant` mồ côi trong `DesiredSpeed_Module` (`Desired Speed (km/h)` = 80, output
không nối vào đâu) — nó khiến người đọc tưởng đó là nguồn tốc độ đặt, trong khi nguồn thật là khối `Step`.

**Lỗi tự phát hiện trong `startup.m`:** file được viết dưới dạng `function`, nên `acc_init_setup` chạy
trong workspace của hàm và tham số **không hề tới được base workspace**. Từ Sprint 1 tới giờ nó vẫn có vẻ
hoạt động là nhờ `PostLoadFcn` của `ACC_Main` và `evalin` trong `AccScenarioTest` bù lại. Đã chuyển thành
script.

### 2026-07-27 — Đính chính về các file `*.slx.r2025a`

**`<tên>.slx.r2025a` không phải quy ước export của team — đó là tên file backup tự động của Simulink.** Khi
lưu một model vốn được lưu lần cuối ở bản cũ hơn, Simulink tự tạo bản sao mang đúng tên đó, chứa nội dung
**trước khi sửa**:

```
A copy of the original file 'VehicleDynamics_Module.slx' has been created because it was
last saved in an earlier version of Simulink. To recover the original version, rename the
file 'VehicleDynamics_Module.slx.r2025a' as 'VehicleDynamics_Module.slx'.
```

Nghĩa là các file `.r2025a` nằm trong repo từ trước tới nay chưa bao giờ là bản export của model hiện
hành. Thành viên R2025a nào đổi tên chúng ra dùng đều đang chạy model lỗi thời.

Script `export_r2025a.m` ban đầu cũng chọn nhầm đúng cái tên này nên hai cơ chế ghi đè lẫn nhau. Đã sửa:
bản export thật nay nằm ở **`export_R2025a/<tên>.slx`** (đuôi `.slx` bình thường, mở thẳng được, không phải
đổi tên). `*.slx.r2025a` đã được đưa vào `.gitignore` và gỡ khỏi Git.

**Lưu ý:** `docs` từng nằm trong `.git/info/exclude`, nghĩa là mọi tài liệu trong thư mục này sẽ không bao
giờ được commit. Đã gỡ dòng đó để báo cáo này chia sẻ được cho team.

---

## Phụ lục A — Quy trình kiểm chứng đúng

> Luôn bắt đầu bằng `bdclose('all')` rồi mới `addpath`, nếu không kết quả sẽ sai như lần review đầu.

```matlab
bdclose('all');
root = 'D:\GO JAPAN 2026\project\jRAP_ACC';
addpath(root, fullfile(root,'models'), fullfile(root,'scripts'));
run(fullfile(root,'scripts','acc_init_setup.m'));
load_system(fullfile(root,'ACC_Main.slx'));

% Đếm line lỗi ở root
lines = find_system('ACC_Main','FindAll','on','SearchDepth',1,'Type','line');
% → 83 line, 0 line mất nguồn

% Kiểm tra kết nối của plant
ph = get_param('ACC_Main/Model','PortHandles');
arrayfun(@(h) get_param(h,'Line'), ph.Outport)
% → out1,2,3 có line; out4,out5 = -1

% Diagnostics
get_param('ACC_Main','UnconnectedInputMsg')   % → 'none'

% Tham số thực sự được dùng
Simulink.findVars('ACC_Main','SearchReferencedModels',true)
% → chỉ Sensor_FarRange_m, Sensor_NearRange_m

% Chạy test
run('scripts/tests/run_acc_scenario_tests.m')   % → 5/5 pass
```

## Phụ lục B — Trạng thái môi trường sau review

- `ACC_Main` reload sạch từ đĩa, `Dirty = off` — **không có thay đổi nào được lưu**
- `ACC_DISABLE_ANIMATION` đặt lại `false`
- Toàn bộ `DataLogging` tạm thời đã tắt
- Repo không bị thay đổi trong quá trình review (`git status` sạch trước và sau)
