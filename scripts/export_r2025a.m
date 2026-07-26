function export_r2025a(varargin)
% EXPORT_R2025A  Sinh lại toàn bộ bản R2025a của các model trong dự án.
%
% Team còn thành viên dùng MATLAB R2025a, trong khi một số model đã được
% lưu ở R2026a. Mỗi model vì thế có hai bản: bản chính <tên>.slx và bản
% export <tên>.slx.r2025a. Làm tay thì chắc chắn có lúc quên, dẫn tới bản
% R2025a lệch khỏi bản chính mà không ai biết.
%
% Chạy script này sau mỗi lần sửa model, TRƯỚC khi commit:
%   startup
%   export_r2025a          % sinh lại tất cả
%   export_r2025a('check') % chỉ kiểm tra bản nào đã cũ, không ghi đè
%
% Người dùng R2025a: chép <tên>.slx.r2025a thành <tên>.slx trong bản làm
% việc của mình (đừng commit đè lên bản chính).

TARGET_RELEASE = 'R2025A';

checkOnly = nargin > 0 && strcmpi(varargin{1}, 'check');
projectRoot = fileparts(fileparts(mfilename('fullpath')));

models = [ dir(fullfile(projectRoot, '*.slx')) ; dir(fullfile(projectRoot, 'models', '*.slx')) ];

fprintf('=== Export sang %s ===\n', TARGET_RELEASE);
nStale = 0; nOk = 0; nFail = 0;

for i = 1:numel(models)
    srcPath = fullfile(models(i).folder, models(i).name);
    dstPath = [srcPath '.r2025a'];
    [~, shortName] = fileparts(models(i).name);

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

        % Simulink.exportToVersion chỉ chấp nhận tên file kết thúc bằng
        % .slx/.mdl, nên không ghi thẳng ra <tên>.slx.r2025a được. Xuất ra
        % thư mục tạm với tên hợp lệ rồi mới đổi tên về đúng quy ước.
        stagingFile = fullfile(tempdir, [shortName '.slx']);
        if isfile(stagingFile); delete(stagingFile); end
        Simulink.exportToVersion(shortName, stagingFile, TARGET_RELEASE);
        movefile(stagingFile, dstPath, 'f');

        if ~wasLoaded
            close_system(shortName, 0);
        end
        fprintf('  [SINH  ] %-28s -> %s\n', shortName, [models(i).name '.r2025a']);
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
