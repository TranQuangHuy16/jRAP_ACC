% --- acc_init_setup.m ---
% Nạp tham số môi trường ACC vào base workspace.
%
% Quy ước: mọi biến trong file này PHẢI được ít nhất một khối trong model
% tham chiếu tới. Kiểm tra bằng:
%     Simulink.findVars('ACC_Main','SearchReferencedModels',true)
% Biến khai báo ở đây mà model không dùng còn tệ hơn là không có: người
% đọc tưởng sửa giá trị ở đây là đổi được hành vi, trong khi thực tế giá
% trị thật nằm hardcode trong khối.
%
% Tự bảo đảm models/ và scripts/ nằm trên MATLAB path, để script này chạy
% được cả khi người dùng gọi trực tiếp mà chưa qua startup.m. Thiếu bước
% này, các khối Model-reference trong ACC_Main không resolve được.
accRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(accRoot, fullfile(accRoot,'models'), fullfile(accRoot,'scripts'));
clear accRoot

%% Động học xe (VehicleDynamics_Module)
% Gia tốc là hằng số theo mức ga, không phụ thuộc vận tốc. Đây là mô hình
% ĐÚNG theo product backlog: backlog không có yêu cầu nào về lực cản gió,
% nên model cố tình không mô phỏng nó. Vì vậy cũng không có khối lượng xe,
% hệ số cản Cd, diện tích cản A hay mật độ không khí rho trong dự án này -
% đừng thêm lại chúng nếu backlog không đổi.
a_throttle_mps2 = 2;     % Gia tốc khi ga mở hết (m/s^2)
a_brake_mps2 = 2;        % Giảm tốc khi phanh hết (m/s^2)

%% Tốc độ đặt của người lái (DesiredSpeed_Module)
v_cruise_kmh = 80;         % Tốc độ đặt ban đầu (km/h)
v_cruise_lowered_kmh = 40; % Tốc độ đặt sau khi người lái hạ xuống ở t=12s (km/h)

%% Bộ điều khiển ga và phanh (SpeedController / BrakeController)
% Cả hai đều là điều khiển đóng-mở: sai số tốc độ vượt ngưỡng thì ga (hoặc
% phanh) bật hẳn, trong ngưỡng thì tắt. Không có bộ PID nào trong model.
speed_tolerance = 0.5;   % Vùng sai số cho phép quanh tốc độ đặt (km/h)

%% Tính khoảng cách (DistanceCalculation_Module)
D_noLead_m = 1000;       % Khoảng cách báo về khi không có xe phía trước (m)

%% Phanh khẩn cấp (EmergencyBrake_Module)
D_emergency_m = 8;       % Khoảng cách kích hoạt phanh khẩn cấp (m)

%% Trọng tài tốc độ (ACC_Main/SpeedArbitration)
% Tốc độ bám an toàn = LeadSpeed + blend*(DesiredSpeed - LeadSpeed) - k_closing*ClosingSpeed
% trong đó blend tăng tuyến tính từ 0 (đúng khoảng cách an toàn) tới 1
% (cách xe trước D_safe + D_followBlend_m mét thì bám hẳn tốc độ đặt).
D_safe = 20;             % Khoảng cách an toàn tối thiểu (m)
D_followBlend_m = 60;    % Khoảng cách vượt trên D_safe để trả hết về tốc độ đặt (m)
k_closing = 0.5;         % Hệ số trừ theo tốc độ tiếp cận (km/h giảm trên mỗi km/h tiếp cận)

%% Cảm biến khoảng cách phía trước (ProximitySensor_Module)
Sensor_FarRange_m = 40;  % Khoảng cách bắt đầu kêu (m)
Sensor_NearRange_m = 3;  % Khoảng cách kêu liên tục/cường độ tối đa (m)

disp('Đã tải thành công cấu hình môi trường ACC!');
