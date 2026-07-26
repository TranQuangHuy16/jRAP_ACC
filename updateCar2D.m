function updateCar2D(position, currentSpeed, desiredSpeed, throttle, brake, ...
                     leadPosition, leadPresent, proximityLevel, simTime)
%UPDATECAR2D  Vẽ một khung hình mô phỏng 2D của hệ ACC.
%
%   Được gọi từ khối MATLAB Function trong Vehicle2DAnimation_Module ở mỗi
%   bước solver. Hàm này chỉ lo ba việc: bỏ qua khi animation bị tắt, giới
%   hạn tần số vẽ, rồi giao phần hình cho viz.RoadScene và phần tiếng cho
%   viz.ProximityBeeper.
%
%   position       : m
%   currentSpeed   : km/h
%   desiredSpeed   : km/h
%   throttle       : 0 hoặc 1
%   brake          : 0 hoặc 1
%   leadPosition   : m - vị trí xe phía trước
%   leadPresent    : 0/1 - có xe phía trước hay không
%   proximityLevel : 0..1 - mức độ gần vật cản phía trước (cảm biến)
%   simTime        : giây - thời gian mô phỏng hiện tại

MIN_REDRAW_INTERVAL = 1/30;   % giây - giới hạn ~30 fps để không làm chậm solver

persistent scene beeper lastDrawTic

% Bộ test đặt ACC_DISABLE_ANIMATION = true để sim không bị chậm vì vẽ.
if viz.isAnimationDisabled(simTime)
    return;
end

if isempty(beeper)
    beeper = viz.ProximityBeeper();
end
proxGlowOn = beeper.update(proximityLevel, simTime);

% Bỏ qua khung hình này nếu vừa vẽ cách đây quá gần. Vẫn phải vẽ khung
% đầu tiên (và vẽ lại nếu người dùng đã đóng cửa sổ) để tạo figure.
sceneAlive = ~isempty(scene) && scene.isValid();
if sceneAlive && ~isempty(lastDrawTic) && toc(lastDrawTic) < MIN_REDRAW_INTERVAL
    return;
end
lastDrawTic = tic;

if isempty(scene)
    scene = viz.RoadScene();
end

scene.render(struct( ...
    'position',       position, ...
    'currentSpeed',   currentSpeed, ...
    'desiredSpeed',   desiredSpeed, ...
    'throttle',       throttle, ...
    'brake',          brake, ...
    'leadPosition',   leadPosition, ...
    'leadPresent',    leadPresent, ...
    'proximityLevel', proximityLevel, ...
    'proxGlowOn',     proxGlowOn));
end
