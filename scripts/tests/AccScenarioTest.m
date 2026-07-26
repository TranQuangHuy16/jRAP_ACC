classdef AccScenarioTest < matlab.unittest.TestCase
    % ACCSCENARIOTEST  Kiểm thử kịch bản hệ thống ACC (PBI-16..21).
    %
    % Bản viết lại của run_acc_scenario_tests.m theo matlab.unittest. Ba
    % điểm cải thiện so với bản script cũ:
    %
    %   1. Mỗi test độc lập - tự bật logging của riêng mình, không tái sử
    %      dụng cấu hình của test chạy trước, nên chạy lẻ từng test được.
    %   2. Mọi thay đổi lên model đều đăng ký teardown ngay tại chỗ sửa,
    %      nên kể cả khi test fail giữa chừng model vẫn được trả về nguyên
    %      trạng - không cần chiêu close_system/load_system ở cuối script.
    %   3. Chạy được dưới runner có exit code và xuất JUnit XML, tức là
    %      gắn được vào CI.
    %
    % Đặc tả hành vi tương ứng nằm ở scripts/tests/*.feature.
    %
    % Cách chạy:
    %   startup
    %   runtests('AccScenarioTest')              % toàn bộ
    %   runtests('AccScenarioTest/tPBI16_...')   % một test
    %   run('scripts/tests/run_acc_scenario_tests.m')   % có báo cáo gọn

    properties (Constant)
        MainModel = 'ACC_Main'
        SpeedToleranceKmh = 3      % dung sai bám tốc độ đặt (km/h)
    end

    properties (Access = private)
        % Các model đã đăng ký khôi phục cờ Dirty, để không đăng ký trùng.
        DirtyTracked = string.empty
    end

    methods (TestClassSetup)

        function bootstrapEnvironment(testCase)
            % Nạp path + tham số. Không có bước này, các khối
            % Model-reference không resolve được và kết quả kiểm tra kết
            % nối sẽ sai hoàn toàn (xem docs/CODE_REVIEW_2026-07-26.md).
            here = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(fileparts(here));
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture( ...
                    {projectRoot, fullfile(projectRoot,'models'), fullfile(projectRoot,'scripts')}));
            % Nạp tham số vào BASE workspace - đó là nơi Simulink tra cứu
            % giá trị của D_safe, k_closing... khi resolve tham số khối.
            % (Cũng không thể `run` script ngay trong method: workspace
            % của method là static, script không tạo biến ở đó được.)
            evalin('base', sprintf('run(''%s'')', ...
                fullfile(projectRoot,'scripts','acc_init_setup.m')));

            % Tắt animation 2D: chỉ làm sim chậm, không liên quan tới
            % điều gì các test này khẳng định.
            oldFlag = [];
            if evalin('base','exist(''ACC_DISABLE_ANIMATION'',''var'')')
                oldFlag = evalin('base','ACC_DISABLE_ANIMATION');
            end
            assignin('base','ACC_DISABLE_ANIMATION', true);
            testCase.addTeardown(@() restoreAnimationFlag(oldFlag));

            load_system(testCase.MainModel);

            function restoreAnimationFlag(v)
                if isempty(v)
                    evalin('base','clear ACC_DISABLE_ANIMATION');
                else
                    assignin('base','ACC_DISABLE_ANIMATION', v);
                end
            end
        end
    end

    methods (Test)

        function tPBI16_CruiseConvergesToDesiredSpeed(testCase)
            % PBI-16: đường trống -> tốc độ xe hội tụ về tốc độ đặt.
            %
            % LeadPresent = boolean(StepAppear - StepDisappear). Nếu chỉ
            % tắt StepAppear, tổng sẽ âm khi StepDisappear kích hoạt ở
            % t=25, mà ép kiểu số âm sang boolean lại ra true. Phải tắt cả
            % hai để tín hiệu hiện diện đứng yên ở 0.
            testCase.loadModule('LeadVehicle_Module');
            testCase.overrideParam('LeadVehicle_Module/StepAppear','After','0');
            testCase.overrideParam('LeadVehicle_Module/StepDisappear','After','0');

            testCase.logPort('ACC_Main/VehicleDynamics', 3, 'EgoSpeed');
            testCase.logPort('ACC_Main/DesiredSpeed',    1, 'DesiredSpeed');

            logs = testCase.simulateMain(30);
            egoSpeed = logs.getElement('EgoSpeed').Values.Data(end);
            desired  = logs.getElement('DesiredSpeed').Values.Data(end);

            testCase.verifyEqual(egoSpeed, desired, 'AbsTol', testCase.SpeedToleranceKmh, ...
                sprintf('Tốc độ cuối %.2f km/h không bám được tốc độ đặt %.2f km/h', egoSpeed, desired));
        end

        function tPBI17_FollowingReducesSpeedBelowDesired(testCase)
            % PBI-17: có xe chậm phía trước -> tốc độ trọng tài phải thấp
            % hơn tốc độ đặt.
            testCase.logPort('ACC_Main/SpeedArbitration', 1, 'Effective');
            testCase.logPort('ACC_Main/LeadVehicle',      1, 'LeadPresent');
            testCase.logPort('ACC_Main/DesiredSpeed',     1, 'Desired');

            logs = testCase.simulateMain(20);
            eff = logs.getElement('Effective').Values;
            lp  = logs.getElement('LeadPresent').Values;
            ds  = logs.getElement('Desired').Values;

            idx = find(lp.Data > 0, 1, 'last');
            testCase.assertNotEmpty(idx, 'Kịch bản không hề có xe phía trước - kiểm tra LeadVehicle_Module');
            tCheck = lp.Time(idx);

            effAt = interp1(eff.Time, eff.Data, tCheck);
            desAt = interp1(ds.Time,  ds.Data,  tCheck);
            testCase.verifyLessThan(effAt, desAt - 1, ...
                sprintf('t=%.1fs: tốc độ trọng tài %.2f không thấp hơn tốc độ đặt %.2f', tCheck, effAt, desAt));
        end

        function tPBI18_SpeedRestoresAfterLeadLeaves(testCase)
            % PBI-18: xe phía trước rời đi -> tốc độ trọng tài trở lại
            % tốc độ đặt.
            testCase.logPort('ACC_Main/SpeedArbitration', 1, 'Effective');
            testCase.logPort('ACC_Main/DesiredSpeed',     1, 'Desired');

            logs = testCase.simulateMain(30);
            eff = logs.getElement('Effective').Values;
            ds  = logs.getElement('Desired').Values;

            tCheck = eff.Time(end) - 1;   % 1s trước khi kết thúc
            effAt = interp1(eff.Time, eff.Data, tCheck);
            desAt = interp1(ds.Time,  ds.Data,  tCheck);

            testCase.verifyEqual(effAt, desAt, 'AbsTol', testCase.SpeedToleranceKmh, ...
                sprintf('t=%.1fs: tốc độ trọng tài %.2f chưa trở lại tốc độ đặt %.2f', tCheck, effAt, desAt));
        end

        function tPBI19_EmergencyBrakeOverridesNormalControl(testCase)
            % PBI-19: khoảng cách nguy hiểm -> phanh khẩn cấp ghi đè lệnh
            % ga/phanh thường. Chạy module độc lập.
            mdl = 'EmergencyBrake_Module';
            testCase.loadModule(mdl);

            % Ma trận ExternalInput là kiểu double; nới tạm cổng
            % LeadPresent (boolean) để nhận được input test.
            testCase.overrideParam([mdl '/LeadPresent'],'OutDataTypeStr','double');

            % Cột theo thứ tự cổng: LeadPresent, ActualDistance_m,
            % ClosingSpeed_kmh, NormalThrottle, NormalBrake
            % -> rất gần, tiếp cận nhanh, người lái vẫn đang đạp ga.
            vals = '[0 1 2 40 0.6 0; 1 1 2 40 0.6 0]';
            out = testCase.simulateModule(mdl, 1, vals);

            finalThrottle = out.yout{1}.Values.Data(end);
            finalBrake    = out.yout{2}.Values.Data(end);
            active        = out.yout{3}.Values.Data(end);

            testCase.verifyEqual(double(active), 1, 'Phanh khẩn cấp không kích hoạt ở khoảng cách 2m');
            testCase.verifyEqual(finalThrottle, 0, 'AbsTol', 1e-9, 'Ga chưa bị cắt khi phanh khẩn cấp');
            testCase.verifyGreaterThan(finalBrake, 0.8, 'Lực phanh khẩn cấp chưa đạt mức tối đa');
        end

        function tPBI21_ProximityLevelTracksDistance(testCase)
            % PBI-21: mức cảnh báo của cảm biến bám theo khoảng cách.
            mdl = 'ProximitySensor_Module';
            testCase.loadModule(mdl);
            testCase.overrideParam([mdl '/LeadPresent'],'OutDataTypeStr','double');

            % Cột: t, LeadPresent, Distance
            cases = { ...
                'Bão hoà ở 2m',      '[0 1 50; 1 1 50; 1 1 2; 2 1 2]', 2, [0.95 1.00]; ...
                'Im lặng ở 200m',    '[0 1 200; 1 1 200]',              1, [0.00 0.00]; ...
                'Một phần ở 20m',    '[0 1 20; 1 1 20]',                1, [0.40 0.70]; ...
                'Chặn khi không có xe trước', '[0 0 2; 1 0 2]',         1, [0.00 0.00]};

            for i = 1:size(cases,1)
                name = cases{i,1}; input = cases{i,2}; stopT = cases{i,3}; range = cases{i,4};
                out = testCase.simulateModule(mdl, stopT, input);
                level = out.yout{1}.Values.Data(end);
                testCase.verifyGreaterThanOrEqual(level, range(1), ...
                    sprintf('%s: ProximityLevel=%.3f thấp hơn ngưỡng %.2f', name, level, range(1)));
                testCase.verifyLessThanOrEqual(level, range(2), ...
                    sprintf('%s: ProximityLevel=%.3f cao hơn ngưỡng %.2f', name, level, range(2)));
            end
        end
    end

    methods (Access = private)

        function logs = simulateMain(testCase, stopTime)
            % Chạy ACC_Main và trả về logsout.
            set_param(testCase.MainModel,'SimulationCommand','update');
            out = sim(testCase.MainModel,'StopTime',num2str(stopTime),'SaveOutput','on');
            logs = out.get('logsout');
            testCase.assertNotEmpty(logs, 'Sim không trả về logsout - kiểm tra SignalLogging của model');
        end

        function out = simulateModule(testCase, mdl, stopTime, inputExpr)
            % Chạy một module độc lập với ExternalInput dạng ma trận.
            set_param(mdl,'SimulationCommand','update');
            out = sim(mdl,'StopTime',num2str(stopTime),'SaveOutput','on','SaveFormat','Dataset', ...
                'LoadExternalInput','on','ExternalInput',inputExpr);
            testCase.assertNotEmpty(out.yout, sprintf('%s không trả về tín hiệu output nào', mdl));
        end

        function loadModule(testCase, mdl)
            % Nạp module con nếu chưa có, và đóng lại khi test xong nếu
            % chính test này là bên đã nạp nó.
            if ~bdIsLoaded(mdl)
                load_system(mdl);
                testCase.addTeardown(@() close_system(mdl, 0));
            end
        end

        function overrideParam(testCase, blockPath, param, value)
            % Đổi tạm một tham số khối và tự khôi phục khi test kết thúc,
            % kể cả khi test fail.
            testCase.preserveDirtyFlag(bdroot(blockPath));
            original = get_param(blockPath, param);
            set_param(blockPath, param, value);
            testCase.addTeardown(@() set_param(blockPath, param, original));
        end

        function preserveDirtyFlag(testCase, mdl)
            % set_param đánh dấu model là Dirty kể cả khi ta đã trả tham
            % số về đúng giá trị cũ. Ghi lại cờ Dirty lúc đầu và khôi phục
            % đúng cờ đó, để chạy test không làm model "bẩn" giả và không
            % che mất thay đổi thật mà người dùng đang có dở.
            mdl = string(mdl);
            if ismember(mdl, testCase.DirtyTracked); return; end
            testCase.DirtyTracked(end+1) = mdl;
            originalDirty = get_param(mdl,'Dirty');
            testCase.addTeardown(@() restoreDirty(mdl, originalDirty));

            function restoreDirty(m, flag)
                if bdIsLoaded(m); set_param(m,'Dirty', flag); end
            end
        end

        function logPort(testCase, blockPath, portIdx, signalName)
            % Bật logging cho một cổng ra và tự tắt khi test kết thúc.
            testCase.preserveDirtyFlag(bdroot(blockPath));
            ph = get_param(blockPath,'PortHandles');
            testCase.assertGreaterThanOrEqual(numel(ph.Outport), portIdx, ...
                sprintf('%s không có cổng ra số %d', blockPath, portIdx));
            port = ph.Outport(portIdx);
            set_param(port,'DataLogging','on', ...
                'DataLoggingNameMode','Custom','DataLoggingName',signalName);
            testCase.addTeardown(@() set_param(port,'DataLogging','off'));
        end
    end
end
