% --- acc_init_setup.m ---
% Nạp tham số môi trường ACC vào base workspace.
%
% Tự bảo đảm models/ và scripts/ nằm trên MATLAB path, để script này chạy
% được cả khi người dùng gọi trực tiếp mà chưa qua startup.m. Thiếu bước
% này, các khối Model-reference trong ACC_Main không resolve được.
accRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(accRoot, fullfile(accRoot,'models'), fullfile(accRoot,'scripts'));
clear accRoot

% Thông số Động học xe (Vehicle Dynamics)
m = 1500;       % Khối lượng xe (kg)
Cd = 0.32;      % Hệ số cản gió
A = 2.4;        % Diện tích cản gió (m^2)
rho = 1.225;    % Mật độ không khí (kg/m^3)

% Điều kiện khởi tạo (Initial Conditions)
v0_ego = 20;    % Vận tốc ban đầu xe mình (m/s)
v0_lead = 15;   % Vận tốc ban đầu xe phía trước (m/s)
D0 = 50;        % Khoảng cách ban đầu (m)

% Thông số bộ điều khiển ACC
v_target = 30;  % Tốc độ mong muốn (m/s)
D_safe = 20;    % Khoảng cách an toàn tối thiểu (m)

% Tham số PID tạm thời (sẽ điều chỉnh sau)
Kp = 50; 
Ki = 0.1;
Kd = 0;

% --- Tham số Speed Controller
speed_tolerance = 0.5;   % Vùng sai số cho phép (km/h)

% --- Tham số khối SpeedArbitration (trọng tài giữa tốc độ đặt và tốc độ bám) ---
% Tốc độ bám an toàn = LeadSpeed + blend*(DesiredSpeed - LeadSpeed) - k_closing*ClosingSpeed
% trong đó blend tăng tuyến tính từ 0 (đúng khoảng cách an toàn) tới 1
% (cách xe trước D_safe + D_followBlend_m mét thì bám hẳn tốc độ đặt).
D_followBlend_m = 60;    % Khoảng cách vượt trên D_safe để trả hết về tốc độ đặt (m)
k_closing = 0.5;         % Hệ số trừ theo tốc độ tiếp cận (km/h giảm trên mỗi km/h tiếp cận)

% --- Tham số cảm biến khoảng cách phía trước (Proximity Sensor) ---
Sensor_FarRange_m = 40;   % Khoảng cách bắt đầu kêu (m)
Sensor_NearRange_m = 3;   % Khoảng cách kêu liên tục/cường độ tối đa (m)

disp('Đã tải thành công cấu hình môi trường ACC!');