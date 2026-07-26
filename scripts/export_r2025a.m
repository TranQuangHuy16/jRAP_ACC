function export_r2025a(varargin)
% EXPORT_R2025A  Sinh lại toàn bộ bản R2025a của các model trong dự án.
%
% Team còn thành viên dùng MATLAB R2025a, trong khi một số model đã được
% lưu ở R2026a. Làm tay thì chắc chắn có lúc quên, dẫn tới bản R2025a lệch
% khỏi bản chính mà không ai biết.
%
% Kết quả ghi vào thư mục export_R2025a/ với đuôi .slx bình thường, nên
% người dùng R2025a mở thẳng được, không phải đổi tên gì cả.
%
% QUAN TRỌNG - đừng nhầm với <tên>.slx.r2025a:
%   Đó KHÔNG phải bản export. Đó là backup tự động Simulink tạo ra khi ta
%   lưu một model vốn được lưu lần cuối ở bản cũ hơn, và nó chứa nội dung
%   TRƯỚC khi sửa. Ai đổi tên file đó ra dùng là đang chạy model lỗi thời.
%   Vì vậy thư mục đích ở đây phải khác, tránh hai cơ chế ghi đè lẫn nhau.
%
% Chạy script này sau mỗi lần sửa model, TRƯỚC khi commit:
%   startup
%   export_r2025a          % sinh lại tất cả
%   export_r2025a('check') % chỉ kiểm tra bản nào đã cũ, không ghi đè

TARGET_RELEASE = 'R2025A';

checkOnly = nargin > 0 && strcmpi(varargin{1}, 'check');
projectRoot = fileparts(fileparts(mfilename('fullpath')));

models = [ dir(fullfile(projectRoot, '*.slx')) ; dir(fullfile(projectRoot, 'models', '*.slx')) ];

exportDir = fullfile(projectRoot, 'export_R2025a');
if ~checkOnly && ~isfolder(exportDir)
    mkdir(exportDir);
end

fprintf('=== Export sang %s (-> export_R2025a/) ===\n', TARGET_RELEASE);
nStale = 0; nOk = 0; nFail = 0;

for i = 1:numel(models)
    srcPath = fullfile(models(i).folder, models(i).name);
    [~, shortName] = fileparts(models(i).name);
    dstPath = fullfile(exportDir, models(i).name);

    dst = dir(dstPath);
    isStale = isempty(dst) || dst.datenum < models(i).datenum;

    if ~isStale
        fprintf('  [ok    ] %-28s bản export còn mới\n', shortName);
        nOk = nOk + 1;
        continue;
    end

    if checkOnly
        if isempty(dst)
            fprintf('  [THIẾU ] %-28s chưa hề có bản R2025a\n', shortName);
        else
            fprintf('  [CŨ    ] %-28s bản export cũ hơn bản chính\n', shortName);
        end
        nStale = nStale + 1;
        continue;
    end

    try
        wasLoaded = bdIsLoaded(shortName);
        if wasLoaded && strcmp(get_param(shortName,'Dirty'),'on')
            error('Model %s đang có thay đổi chưa lưu - hãy lưu trước khi export.', shortName);
        end
        if ~wasLoaded
            load_system(srcPath);
        end

        if isfile(dstPath); delete(dstPath); end
        Simulink.exportToVersion(shortName, dstPath, TARGET_RELEASE);

        if ~wasLoaded
            close_system(shortName, 0);
        end
        fprintf('  [SINH  ] %-28s -> export_R2025a/%s\n', shortName, models(i).name);
        nOk = nOk + 1;
    catch ME
        fprintf(2, '  [LỖI   ] %-28s %s\n', shortName, ME.message);
        nFail = nFail + 1;
    end
end

fprintf('---------------------------------------\n');
if checkOnly
    fprintf('%d model có bản R2025a lỗi thời hoặc còn thiếu.\n', nStale);
    if nStale > 0
        fprintf('Chạy  export_r2025a  để sinh lại.\n');
    end
else
    fprintf('%d model đã xong, %d lỗi.\n', nOk, nFail);
end
end
