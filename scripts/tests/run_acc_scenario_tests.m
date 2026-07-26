% run_acc_scenario_tests.m
% Runner cho bộ kiểm thử kịch bản ACC (PBI-16..21).
%
% Logic test nằm trong AccScenarioTest.m (matlab.unittest). File này chỉ
% chạy bộ test, in báo cáo gọn và xuất JUnit XML để gắn CI.
%
% Cách dùng:
%   startup
%   run('scripts/tests/run_acc_scenario_tests.m')
%
% Chạy lẻ một kịch bản:
%   runtests('AccScenarioTest/tPBI19_EmergencyBrakeOverridesNormalControl')

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot, fullfile(projectRoot,'models'), fullfile(projectRoot,'scripts'), ...
        fullfile(projectRoot,'scripts','tests'));

suite  = matlab.unittest.TestSuite.fromClass(?AccScenarioTest);
runner = matlab.unittest.TestRunner.withTextOutput( ...
    'OutputDetail', matlab.unittest.Verbosity.Terse);

% Báo cáo JUnit cho CI. Thư mục testresults/ đã nằm trong .gitignore.
resultsDir = fullfile(projectRoot,'testresults');
if ~isfolder(resultsDir); mkdir(resultsDir); end
runner.addPlugin(matlab.unittest.plugins.XMLPlugin.producingJUnitFormat( ...
    fullfile(resultsDir,'acc_scenario_results.xml')));

results = runner.run(suite);

%% Báo cáo
fprintf('\n=== ACC_Main Scenario Test Results ===\n');
for i = 1:numel(results)
    r = results(i);
    if r.Passed
        status = 'PASS';
    elseif r.Incomplete
        status = 'SKIP';
    else
        status = 'FAIL';
    end
    fprintf('[%s] %-55s %6.2fs\n', status, r.Name, r.Duration);
end
fprintf('---------------------------------------\n');
fprintf('%d / %d scenarios passed  (%.1fs)\n', ...
    nnz([results.Passed]), numel(results), sum([results.Duration]));
fprintf('Báo cáo JUnit: %s\n', fullfile(resultsDir,'acc_scenario_results.xml'));

% Mã thoát cho CI: dùng khi chạy `matlab -batch "run(...)"`.
if any([results.Failed])
    accTestsFailed = true; %#ok<NASGU>
    fprintf(2, 'CÓ KỊCH BẢN THẤT BẠI - xem chi tiết ở trên.\n');
end
