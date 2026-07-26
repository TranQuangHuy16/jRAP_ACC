function updateCar2D(position, currentSpeed, desiredSpeed, throttle, brake, leadPosition, leadPresent)
% position     : m
% currentSpeed : km/h
% desiredSpeed : km/h
% throttle     : 0 hoặc 1
% brake        : 0 hoặc 1
% leadPosition : m (vị trí xe phía trước)
% leadPresent  : 0/1 - có xe phía trước hay không

persistent fig ax roadTop roadBottom centerLine infoText statusText leadText
persistent egoCar leadCar
persistent gaugeArcLow gaugeArcMid gaugeArcHigh gaugeNeedle gaugeSpeedText gaugeMaxSpeed
persistent lastDrawTic
persistent leadEverAppeared

LEAD_VISIBLE_CUTOFF_M = 400; % xe trước đi xa hơn mức này thì coi như đã khuất tầm nhìn

% Cho phép tắt hẳn animation khi chạy test tự động (đặt biến
% ACC_DISABLE_ANIMATION = true trong base workspace trước khi sim) để
% các kịch bản test không bị chậm vì vẽ đồ họa.
if evalin('base', 'exist(''ACC_DISABLE_ANIMATION'',''var'') && ACC_DISABLE_ANIMATION')
    return;
end

GAUGE_MAX_SPEED = 140; % km/h, thang đo cố định của đồng hồ tốc độ
MIN_REDRAW_INTERVAL = 1/30; % giây - giới hạn ~30 fps để không làm chậm solver

% Bỏ qua frame này nếu vừa vẽ cách đây quá gần (vẫn phải vẽ frame đầu
% tiên để tạo figure)
if ~isempty(lastDrawTic) && isgraphics(fig) && toc(lastDrawTic) < MIN_REDRAW_INTERVAL
    return;
end
lastDrawTic = tic;

% Tạo lại cửa sổ nếu chưa tồn tại hoặc đã bị đóng
if isempty(fig) || ~isgraphics(fig)

    fig = figure( ...
        'Name', 'ACC 2D Vehicle Simulation', ...
        'NumberTitle', 'off', ...
        'Color', [0.85 0.92 1.00]);

    ax = axes(fig);
    hold(ax, 'on');

    % Hai biên của đường
    roadTop = plot(ax, [0 100], [3 3], ...
        'Color', 'white', 'LineWidth', 3);

    roadBottom = plot(ax, [0 100], [-1 -1], ...
        'Color', 'white', 'LineWidth', 3);

    % Vạch giữa đường
    centerLine = plot(ax, [0 100], [1 1], '--', ...
        'Color', [1 1 0], 'LineWidth', 1.5);

    % Xe (thân xe dạng vector thay vì khối chữ nhật đơn)
    egoCar = buildCarGraphic(ax, [0.10 0.45 0.95]);
    leadCar = buildCarGraphic(ax, [0.95 0.60 0.10]);
    set([leadCar.tf], 'Visible', 'off');

    leadText = text(ax, leadPosition, 2.5, 'LEAD', ...
        'FontSize', 9, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', ...
        'Color', [0.60 0.35 0.00], ...
        'Visible', 'off');

    % Thông tin tốc độ
    infoText = text(ax, position, 6, '', ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'Color', 'black');

    % Trạng thái xe
    statusText = text(ax, position, 4.8, '', ...
        'FontSize', 12, ...
        'FontWeight', 'bold');

    % Đồng hồ tốc độ (HUD, bám theo mép phải khung nhìn mỗi frame)
    gaugeMaxSpeed = GAUGE_MAX_SPEED;
    thetaLow  = linspace(pi,        pi - pi/3,   20);
    thetaMid  = linspace(pi - pi/3, pi - 2*pi/3, 20);
    thetaHigh = linspace(pi - 2*pi/3, 0,          20);

    gaugeArcLow  = plot(ax, cos(thetaLow),  sin(thetaLow),  'Color', [0.15 0.75 0.20], 'LineWidth', 4);
    gaugeArcMid  = plot(ax, cos(thetaMid),  sin(thetaMid),  'Color', [0.95 0.75 0.10], 'LineWidth', 4);
    gaugeArcHigh = plot(ax, cos(thetaHigh), sin(thetaHigh), 'Color', [0.90 0.15 0.10], 'LineWidth', 4);

    gaugeNeedle = plot(ax, [0 0], [0 0], 'Color', 'black', 'LineWidth', 2);

    gaugeSpeedText = text(ax, 0, 0, '', ...
        'FontSize', 10, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', ...
        'Color', 'black');

    xlabel(ax, 'Distance (m)');
    ylabel(ax, 'Road');
    title(ax, 'Adaptive Cruise Control - 2D Simulation');

    grid(ax, 'on');

    ax.Color = [0.25 0.25 0.25];
    ax.YLim = [-2 8];
end

% Chọn màu và trạng thái của xe
if brake > 0.5
    carColor = [0.90 0.10 0.10];
    vehicleStatus = 'BRAKING';
    statusColor = [0.90 0.10 0.10];

elseif throttle > 0.5
    carColor = [0.10 0.75 0.20];
    vehicleStatus = 'ACCELERATING';
    statusColor = [0.00 0.55 0.10];

else
    carColor = [0.10 0.45 0.95];
    vehicleStatus = 'HOLDING SPEED';
    statusColor = [0.10 0.30 0.90];
end

% Di chuyển xe + đèn phanh + bụi khi phanh gấp
updateCarGraphic(egoCar, position, carColor, brake > 0.5);

% Di chuyển / ẩn-hiện xe phía trước. Một khi xe trước đã từng xuất hiện,
% vẫn tiếp tục hiển thị nó lái đi (kể cả khi leadPresent chuyển về false,
% ví dụ lúc nó tăng tốc rời khỏi phạm vi theo dõi của ACC) thay vì biến
% mất đột ngột - chỉ ẩn hẳn khi nó đã đi xa quá mức nhìn thấy được.
if isempty(leadEverAppeared)
    leadEverAppeared = false;
end
if leadPresent > 0.5
    leadEverAppeared = true;
end
gapToLead = leadPosition - position;
showLead = leadEverAppeared && gapToLead < LEAD_VISIBLE_CUTOFF_M;

if showLead
    updateCarGraphic(leadCar, leadPosition, [0.95 0.60 0.10], false);
    set(leadCar.tf, 'Visible', 'on');
    set(leadText, ...
        'Position', [leadPosition + 4, 2.5, 0], ...
        'Visible', 'on');
else
    set(leadCar.tf, 'Visible', 'off');
    set(leadText, 'Visible', 'off');
end

% Camera đi theo xe (giãn ra để luôn nhìn thấy xe phía trước nếu còn hiển thị)
minWindowWidth = 100;
margin = 20;

leftLimit = max(0, position - margin);
rightLimit = leftLimit + minWindowWidth;

if showLead
    rightLimit = max(rightLimit, leadPosition + margin);
end

ax.XLim = [leftLimit rightLimit];

% Cập nhật đường theo camera
set(roadTop, ...
    'XData', [leftLimit rightLimit], ...
    'YData', [3 3]);

set(roadBottom, ...
    'XData', [leftLimit rightLimit], ...
    'YData', [-1 -1]);

set(centerLine, ...
    'XData', [leftLimit rightLimit], ...
    'YData', [1 1]);

% Cập nhật thông tin
if showLead
    gapLine = sprintf('Gap to Lead: %.1f m\n', gapToLead);
else
    gapLine = '';
end

information = sprintf([ ...
    'Distance: %.1f m\n' ...
    'Current Speed: %.1f km/h\n' ...
    'Desired Speed: %.1f km/h\n' ...
    'Throttle: %.0f %%\n' ...
    'Brake: %.0f %%\n' ...
    '%s'], ...
    position, ...
    currentSpeed, ...
    desiredSpeed, ...
    throttle * 100, ...
    brake * 100, ...
    gapLine);

set(infoText, ...
    'Position', [leftLimit + 3, 6, 0], ...
    'String', information);

set(statusText, ...
    'Position', [leftLimit + 40, 6, 0], ...
    'String', vehicleStatus, ...
    'Color', statusColor);

% Cập nhật đồng hồ tốc độ (bám mép phải khung nhìn)
gaugeCenterX = rightLimit - 14;
gaugeCenterY = 5.2;
gaugeRadius = 2.0;

thetaLow  = linspace(pi,          pi - pi/3,    20);
thetaMid  = linspace(pi - pi/3,   pi - 2*pi/3,  20);
thetaHigh = linspace(pi - 2*pi/3, 0,            20);

set(gaugeArcLow, ...
    'XData', gaugeCenterX + gaugeRadius * cos(thetaLow), ...
    'YData', gaugeCenterY + gaugeRadius * sin(thetaLow));
set(gaugeArcMid, ...
    'XData', gaugeCenterX + gaugeRadius * cos(thetaMid), ...
    'YData', gaugeCenterY + gaugeRadius * sin(thetaMid));
set(gaugeArcHigh, ...
    'XData', gaugeCenterX + gaugeRadius * cos(thetaHigh), ...
    'YData', gaugeCenterY + gaugeRadius * sin(thetaHigh));

speedFrac = max(0, min(1, currentSpeed / gaugeMaxSpeed));
needleAngle = pi - speedFrac * pi;
set(gaugeNeedle, ...
    'XData', [gaugeCenterX, gaugeCenterX + 0.85 * gaugeRadius * cos(needleAngle)], ...
    'YData', [gaugeCenterY, gaugeCenterY + 0.85 * gaugeRadius * sin(needleAngle)]);

set(gaugeSpeedText, ...
    'Position', [gaugeCenterX, gaugeCenterY - 0.7, 0], ...
    'String', sprintf('%.0f km/h', currentSpeed));

drawnow limitrate;
end

function h = buildCarGraphic(ax, bodyColor)
% Dựng 1 chiếc xe dạng vector (thân, kính, bánh, đèn) gắn trên 1
% hgtransform để mỗi frame chỉ cần dịch chuyển transform, không phải
% update từng phần riêng lẻ.

h.tf = hgtransform('Parent', ax);

% Thân xe: đa giác dáng xe nhìn nghiêng (mui thấp phía trước, kính chắn
% gió dốc lên nóc, nóc bằng, đuôi dốc xuống)
bodyX = [0   0    1.2  2.5  5.5  6.8  8    8   ];
bodyY = [0.4 1.1  1.8  1.9  1.9  1.8  1.1  0.4 ];
h.body = patch(ax, 'XData', bodyX, 'YData', bodyY, ...
    'FaceColor', bodyColor, 'EdgeColor', 'black', 'LineWidth', 1.2, ...
    'Parent', h.tf);

% Kính chắn gió
wsX = [1.5 2.3 3.3 3.3];
wsY = [1.35 1.85 1.85 1.35];
h.windshield = patch(ax, 'XData', wsX, 'YData', wsY, ...
    'FaceColor', [0.75 0.90 1.00], 'FaceAlpha', 0.75, 'EdgeColor', 'none', ...
    'Parent', h.tf);

% Bánh xe
h.wheelFront = rectangle(ax, 'Position', [6.0 -0.3 1.2 1.2], ...
    'Curvature', [1 1], 'FaceColor', 'black', 'Parent', h.tf);
h.wheelRear = rectangle(ax, 'Position', [1.0 -0.3 1.2 1.2], ...
    'Curvature', [1 1], 'FaceColor', 'black', 'Parent', h.tf);

% Đèn trước
h.headlight = rectangle(ax, 'Position', [7.7 0.7 0.4 0.5], ...
    'Curvature', [1 1], 'FaceColor', [1.00 0.95 0.60], 'Parent', h.tf);

% Đèn hậu (đổi màu khi phanh)
h.tailLight = rectangle(ax, 'Position', [-0.1 0.7 0.4 0.5], ...
    'Curvature', [1 1], 'FaceColor', [0.40 0.00 0.00], 'Parent', h.tf);

% Quầng sáng đèn phanh (chỉ hiện khi brake > 0.5)
h.brakeGlow = rectangle(ax, 'Position', [-0.7 0.4 1.4 1.1], ...
    'Curvature', [1 1], 'FaceColor', [1 0.2 0.2], 'FaceAlpha', 0.35, ...
    'EdgeColor', 'none', 'Parent', h.tf, 'Visible', 'off');

% Bụi/khói phía sau khi phanh gấp
h.smoke = gobjects(1, 3);
smokeOffsets = [-1.3 0.35; -2.0 0.55; -1.1 0.75];
for i = 1:3
    h.smoke(i) = rectangle(ax, ...
        'Position', [smokeOffsets(i,1) smokeOffsets(i,2) 0.9 0.9], ...
        'Curvature', [1 1], 'FaceColor', [0.6 0.6 0.6], 'FaceAlpha', 0.4, ...
        'EdgeColor', 'none', 'Parent', h.tf, 'Visible', 'off');
end

set(h.tf, 'Matrix', makehgtform('translate', [0 0 0]));
end

function updateCarGraphic(h, position, bodyColor, isBraking)
% Dịch chuyển cả cụm xe tới vị trí mới + cập nhật đèn phanh/bụi.

set(h.tf, 'Matrix', makehgtform('translate', [position 0 0]));
set(h.body, 'FaceColor', bodyColor);

if isBraking
    set(h.tailLight, 'FaceColor', [1.00 0.05 0.05]);
    set(h.brakeGlow, 'Visible', 'on');
    set(h.smoke, 'Visible', 'on');
else
    set(h.tailLight, 'FaceColor', [0.40 0.00 0.00]);
    set(h.brakeGlow, 'Visible', 'off');
    set(h.smoke, 'Visible', 'off');
end
end
