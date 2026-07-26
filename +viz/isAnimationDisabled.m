function tf = isAnimationDisabled(simTime)
%ISANIMATIONDISABLED  Có đang tắt animation 2D cho lần sim này không?
%
%   Cờ ACC_DISABLE_ANIMATION nằm ở base workspace (bộ test đặt cờ này để
%   sim không bị chậm vì vẽ đồ hoạ). Đọc cờ bằng evalin khá đắt, mà trước
%   đây nó bị gọi ở MỖI khung hình.
%
%   Ở đây cờ chỉ được đọc một lần cho mỗi lần sim. Mốc nhận biết "lần sim
%   mới" là simTime tụt xuống so với lần gọi trước - tức đồng hồ mô phỏng
%   vừa chạy lại từ đầu.

persistent cachedFlag lastSimTime

if isempty(lastSimTime) || simTime < lastSimTime
    cachedFlag = evalin('base', ...
        'exist(''ACC_DISABLE_ANIMATION'',''var'') && ACC_DISABLE_ANIMATION');
end
lastSimTime = simTime;

tf = cachedFlag;
end
