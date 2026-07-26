% STARTUP  Chuẩn bị môi trường làm việc cho dự án jRAP_ACC.
%
% MATLAB tự động chạy file này khi khởi động với thư mục hiện hành là gốc
% dự án. Cũng có thể gọi tay bất cứ lúc nào: >> startup
%
% Đây là SCRIPT chứ không phải function, và phải giữ nguyên như vậy: các
% tham số của acc_init_setup cần nằm ở base workspace thì Simulink mới tra
% cứu được khi resolve tham số khối. Nếu bọc thành function, chúng sẽ rơi
% vào workspace của function rồi biến mất khi hàm kết thúc.
%
% Nếu thiếu bước này, ACC_Main sẽ load được nhưng KHÔNG resolve nổi các
% khối Model-reference trong models/. Simulink khi đó báo cổng và đường nối
% của chúng là "mất nguồn", khiến một model hoàn toàn lành lặn trông như bị
% đứt hết dây - đây là bẫy đã từng làm một lần review kết luận sai hoàn toàn.
% Xem docs/CODE_REVIEW_2026-07-26.md muc 0.

accProjectRoot = fileparts(mfilename('fullpath'));

addpath( ...
    accProjectRoot, ...
    fullfile(accProjectRoot, 'models'), ...
    fullfile(accProjectRoot, 'scripts'), ...
    fullfile(accProjectRoot, 'scripts', 'tests'));

acc_init_setup;

fprintf('[jRAP_ACC] Môi trường sẵn sàng (%s)\n', accProjectRoot);
clear accProjectRoot
