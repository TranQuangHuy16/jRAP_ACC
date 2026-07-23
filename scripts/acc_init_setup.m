% --- acc_init_setup.m ---
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
disp('Đã tải thành công cấu hình môi trường ACC!');