% ACC_Main scenario validation (PBI-16, 17, 18, 19, 20)
%
% Fallback to matlab.unittest-free scripted assertions because the
% MATLAB MCP Server Toolbox's model_test/Gherkin pipeline is unavailable
% in this MATLAB version (toolbox is built for R2026b, session runs
% R2026a). Scenario intent mirrors scripts/tests/*.feature.
%
% Run from the project root (models/ and scripts/ on path).
%
% Note: MATLAB's run() temporarily cd's into this script's folder, which
% breaks Vehicle2DAnimation_Module's MATLAB Function call to
% updateCar2D.m (lives at the project root). Add the project root to the
% path explicitly so it resolves regardless of the current folder.
projectRoot = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(projectRoot);

% Skip the 2D animation entirely for automated test runs - it only slows
% sim() down (see updateCar2D.m for the flag check). Reset explicitly at
% the end of this script - onCleanup does not fire reliably for
% top-level scripts invoked via run(), since script variables land in
% (and persist in) the base workspace rather than a function scope.
assignin('base', 'ACC_DISABLE_ANIMATION', true);

results = struct('name', {}, 'passed', {}, 'detail', {});

%% PBI-16: normal cruise, no lead vehicle -> ego speed converges to DesiredSpeed
appearBefore = get_param('LeadVehicle_Module/StepAppear','Before');
appearAfter  = get_param('LeadVehicle_Module/StepAppear','After');
disappearAfter = get_param('LeadVehicle_Module/StepDisappear','After');
try
    % LeadPresent = boolean(StepAppear - StepDisappear); disabling only
    % StepAppear leaves Sum go negative once StepDisappear fires at t=25,
    % and casting a negative value to boolean evaluates true. Disable
    % both steps so the presence signal stays exactly 0 throughout.
    set_param('LeadVehicle_Module/StepAppear','After','0'); % lead never appears
    set_param('LeadVehicle_Module/StepDisappear','After','0');
    set_param('ACC_Main','SimulationCommand','update');

    phSpeed = get_param('ACC_Main/Model','PortHandles');
    set_param(phSpeed.Outport(3),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName','EgoSpeed_16');
    phDS = get_param('ACC_Main/Model2','PortHandles');
    set_param(phDS.Outport(1),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName','DesiredSpeed_16');

    out = sim('ACC_Main','StopTime','30','SaveOutput','on');
    logsout = out.get('logsout');
    egoSpeed = logsout.getElement('EgoSpeed_16').Values;
    desired  = logsout.getElement('DesiredSpeed_16').Values;

    finalSpeed = egoSpeed.Data(end);
    finalDesired = desired.Data(end);
    err = abs(finalSpeed - finalDesired);
    passed = err < 3; % km/h tolerance
    results(end+1) = struct('name','PBI-16 Normal cruise converges to desired speed', ...
        'passed', passed, 'detail', sprintf('finalSpeed=%.2f finalDesired=%.2f err=%.2f', finalSpeed, finalDesired, err));
catch ME
    detail = ME.message;
    if isprop(ME,'cause')
        for ci = 1:numel(ME.cause)
            detail = [detail ' | CAUSE: ' ME.cause{ci}.message]; %#ok<AGROW>
        end
    end
    results(end+1) = struct('name','PBI-16 Normal cruise converges to desired speed','passed',false,'detail',detail);
end
set_param('LeadVehicle_Module/StepAppear','After', appearAfter);
set_param('LeadVehicle_Module/StepDisappear','After', disappearAfter);

%% PBI-17: slow lead vehicle present -> effective/ego speed reduced below desired
try
    set_param('ACC_Main','SimulationCommand','update');
    phEff = get_param('ACC_Main/SpeedArbitration','PortHandles');
    set_param(phEff.Outport(1),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName','Effective_17');
    phLP = get_param('ACC_Main/Model6','PortHandles');
    set_param(phLP.Outport(1),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName','LeadPresent_17');
    phDS2 = get_param('ACC_Main/Model2','PortHandles');
    set_param(phDS2.Outport(1),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName','DesiredSpeed_17');

    out = sim('ACC_Main','StopTime','20','SaveOutput','on');
    logsout = out.get('logsout');
    eff = logsout.getElement('Effective_17').Values;
    lp  = logsout.getElement('LeadPresent_17').Values;
    ds  = logsout.getElement('DesiredSpeed_17').Values;

    idx = find(lp.Data > 0, 1, 'last');
    tCheck = lp.Time(idx);
    effAtCheck = interp1(eff.Time, eff.Data, tCheck);
    desAtCheck = interp1(ds.Time, ds.Data, tCheck);
    passed = effAtCheck < desAtCheck - 1;
    results(end+1) = struct('name','PBI-17 Following reduces speed below desired', ...
        'passed', passed, 'detail', sprintf('t=%.1f effective=%.2f desired=%.2f', tCheck, effAtCheck, desAtCheck));
catch ME
    detail = ME.message;
    if isprop(ME,'cause'); for ci=1:numel(ME.cause); detail = [detail ' | CAUSE: ' ME.cause{ci}.message]; end; end %#ok<AGROW>
    results(end+1) = struct('name','PBI-17 Following reduces speed below desired','passed',false,'detail',detail);
end

%% PBI-18: lead vehicle disappears -> effective speed returns to desired speed
try
    set_param('ACC_Main','SimulationCommand','update');
    out = sim('ACC_Main','StopTime','30','SaveOutput','on');
    logsout = out.get('logsout');
    eff = logsout.getElement('Effective_17').Values; % reuse logging from previous run's config
    lp  = logsout.getElement('LeadPresent_17').Values;
    ds  = logsout.getElement('DesiredSpeed_17').Values;

    lastFalseIdx = find(lp.Data == 0 & lp.Time > 20, 1, 'first');
    if isempty(lastFalseIdx)
        lastFalseIdx = numel(lp.Time);
    end
    tCheck = lp.Time(end) - 1; % 1s before end, should be back on desired speed
    effEnd = interp1(eff.Time, eff.Data, tCheck);
    desEnd = interp1(ds.Time, ds.Data, tCheck);
    passed = abs(effEnd - desEnd) < 3;
    results(end+1) = struct('name','PBI-18 Effective speed restores after lead vehicle leaves', ...
        'passed', passed, 'detail', sprintf('t=%.1f effective=%.2f desired=%.2f', tCheck, effEnd, desEnd));
catch ME
    detail = ME.message;
    if isprop(ME,'cause'); for ci=1:numel(ME.cause); detail = [detail ' | CAUSE: ' ME.cause{ci}.message]; end; end %#ok<AGROW>
    results(end+1) = struct('name','PBI-18 Effective speed restores after lead vehicle leaves','passed',false,'detail',detail);
end

% turn off temp logging added above
try
    set_param(phSpeed.Outport(3),'DataLogging','off');
    set_param(phDS.Outport(1),'DataLogging','off');
    set_param(phEff.Outport(1),'DataLogging','off');
    set_param(phLP.Outport(1),'DataLogging','off');
    set_param(phDS2.Outport(1),'DataLogging','off');
catch
end

%% PBI-19: EmergencyBrake_Module standalone - close distance triggers full brake override
try
    mdl = 'EmergencyBrake_Module';
    if ~bdIsLoaded(mdl); load_system(mdl); end
    % ExternalInput matrices are double; temporarily relax the boolean
    % LeadPresent port so it accepts the double test input (discarded by
    % the close/reload at the end of this script).
    set_param([mdl '/LeadPresent'], 'OutDataTypeStr', 'double');
    % Root Inports need an external input source for standalone sim;
    % drive constant values via a workspace time-series matrix.
    % Columns match port order: LeadPresent, ActualDistance_m, ClosingSpeed_kmh, NormalThrottle, NormalBrake
    inVals  = [1, 2, 40, 0.6, 0]; % dangerously close distance, fast closing, driver wants throttle
    eb_test_input = [0 inVals; 1 inVals]; %#ok<NASGU>
    assignin('base','eb_test_input', eb_test_input);

    set_param(mdl,'SimulationCommand','update');
    out = sim(mdl,'StopTime','1','SaveOutput','on','SaveFormat','Dataset', ...
        'LoadExternalInput','on','ExternalInput','eb_test_input');

    % root-level Outport blocks (FinalThrottle, FinalBrake, EmergencyBrakeActive,
    % in port-number order) come back automatically via out.yout
    finalThrottle = out.yout{1}.Values.Data(end);
    finalBrake = out.yout{2}.Values.Data(end);
    active = out.yout{3}.Values.Data(end);

    passed = (active == 1) && (finalThrottle == 0) && (finalBrake > 0.8);
    results(end+1) = struct('name','PBI-19 Emergency brake overrides normal control', ...
        'passed', passed, 'detail', sprintf('Active=%d FinalThrottle=%.2f FinalBrake=%.2f', active, finalThrottle, finalBrake));
catch ME
    detail = ME.message;
    if isprop(ME,'cause'); for ci=1:numel(ME.cause); detail = [detail ' | CAUSE: ' ME.cause{ci}.message]; end; end %#ok<AGROW>
    results(end+1) = struct('name','PBI-19 Emergency brake overrides normal control','passed',false,'detail',detail);
end

%% PBI-21: ProximitySensor_Module standalone - proximity level tracks distance to lead vehicle
try
    mdl = 'ProximitySensor_Module';
    if ~bdIsLoaded(mdl); load_system(mdl); end
    % ExternalInput matrices are double; temporarily relax the boolean
    % LeadPresent port so it accepts the double test input (discarded by
    % the close/reload at the end of this script).
    set_param([mdl '/LeadPresent'], 'OutDataTypeStr', 'double');

    % Scenario A: distance steps from 50m to 2m at t=1s (mirrors PBI-19's
    % EmergencyBrake_Module trigger case) - proximity must saturate near
    % max, consistent with EmergencyBrake_Module also triggering at 2m.
    % Columns: LeadPresent, Distance
    proxStepInput = [0 1 50; 1 1 50; 1 1 2; 2 1 2]; %#ok<NASGU>
    assignin('base','prox_step_input', proxStepInput);
    set_param(mdl,'SimulationCommand','update');
    outA = sim(mdl,'StopTime','2','SaveOutput','on','SaveFormat','Dataset', ...
        'LoadExternalInput','on','ExternalInput','prox_step_input');
    proxLevelA = outA.yout{1}.Values.Data(end);
    passedA = proxLevelA >= 0.95 && proxLevelA <= 1.0;

    % Scenario B: safe far distance (200m, beyond Sensor_FarRange_m) -> silent
    proxFarInput = [0 1 200; 1 1 200]; %#ok<NASGU>
    assignin('base','prox_far_input', proxFarInput);
    set_param(mdl,'SimulationCommand','update');
    outB = sim(mdl,'StopTime','1','SaveOutput','on','SaveFormat','Dataset', ...
        'LoadExternalInput','on','ExternalInput','prox_far_input');
    proxLevelB = outB.yout{1}.Values.Data(end);
    passedB = proxLevelB == 0;

    % Scenario C: mid-range distance (20m) -> partial/proportional level
    proxMidInput = [0 1 20; 1 1 20]; %#ok<NASGU>
    assignin('base','prox_mid_input', proxMidInput);
    set_param(mdl,'SimulationCommand','update');
    outC = sim(mdl,'StopTime','1','SaveOutput','on','SaveFormat','Dataset', ...
        'LoadExternalInput','on','ExternalInput','prox_mid_input');
    proxLevelC = outC.yout{1}.Values.Data(end);
    passedC = proxLevelC >= 0.4 && proxLevelC <= 0.7;

    % Scenario D: no lead vehicle -> gated off even at a close distance
    proxGatedInput = [0 0 2; 1 0 2]; %#ok<NASGU>
    assignin('base','prox_gated_input', proxGatedInput);
    set_param(mdl,'SimulationCommand','update');
    outD = sim(mdl,'StopTime','1','SaveOutput','on','SaveFormat','Dataset', ...
        'LoadExternalInput','on','ExternalInput','prox_gated_input');
    proxLevelD = outD.yout{1}.Values.Data(end);
    passedD = proxLevelD == 0;

    passed = passedA && passedB && passedC && passedD;
    results(end+1) = struct('name','PBI-21 Proximity sensor tracks distance to lead vehicle', ...
        'passed', passed, 'detail', sprintf(['Saturated(2m)=%.3f(%d) Silent(200m)=%.3f(%d) ' ...
        'Partial(20m)=%.3f(%d) Gated(noLead,2m)=%.3f(%d)'], ...
        proxLevelA, passedA, proxLevelB, passedB, proxLevelC, passedC, proxLevelD, passedD));
catch ME
    detail = ME.message;
    if isprop(ME,'cause'); for ci=1:numel(ME.cause); detail = [detail ' | CAUSE: ' ME.cause{ci}.message]; end; end %#ok<AGROW>
    results(end+1) = struct('name','PBI-21 Proximity sensor tracks distance to lead vehicle','passed',false,'detail',detail);
end

%% Restore LeadVehicle_Module / EmergencyBrake_Module to original saved state (discard test-only edits)
try
    close_system('LeadVehicle_Module', 0); load_system('LeadVehicle_Module');
    close_system('EmergencyBrake_Module', 0); load_system('EmergencyBrake_Module');
    close_system('ProximitySensor_Module', 0); load_system('ProximitySensor_Module');
    set_param('ACC_Main','SimulationCommand','update');
catch
end

assignin('base', 'ACC_DISABLE_ANIMATION', false);

%% Report (PBI-20: aggregate system validation)
fprintf('\n=== ACC_Main Scenario Test Results ===\n');
nPass = 0;
for i = 1:numel(results)
    r = results(i);
    if r.passed
        status = 'PASS';
        nPass = nPass + 1;
    else
        status = 'FAIL';
    end
    fprintf('[%s] %s\n    %s\n', status, r.name, r.detail);
end
fprintf('---------------------------------------\n');
fprintf('%d / %d scenarios passed\n', nPass, numel(results));
