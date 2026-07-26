% demo_front_sensor.m
% Visual/audio demo of the front proximity sensor: lead vehicle cruises,
% hard-brakes, holds for ~2s, then re-accelerates - watch the ego car's
% front sensor glow/beep intensify as the gap closes and ease off again
% as the lead vehicle pulls away.
%
% Run from the project root (models/ and scripts/ on path).
projectRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);

assignin('base', 'ACC_DISABLE_ANIMATION', false);

leadMdl = 'LeadVehicle_Module';
if ~bdIsLoaded(leadMdl); load_system(leadMdl); end

% Save originals so the demo doesn't leave the model dirty afterward.
speedTime0  = get_param([leadMdl '/LeadSpeed_kmh'], 'Time');
rampStart0  = get_param([leadMdl '/AccelerateAway'], 'start');
rampSlope0  = get_param([leadMdl '/AccelerateAway'], 'slope');

try
    % Hard brake (50 -> 0 km/h) at t=10s, hold ~2s, then re-accelerate
    % (ramp) starting at t=12s back toward cruise speed.
    set_param([leadMdl '/LeadSpeed_kmh'], 'Time', '10');
    set_param([leadMdl '/AccelerateAway'], 'start', '12');
    set_param([leadMdl '/AccelerateAway'], 'slope', '15');

    open_system('ACC_Main');
    set_param('ACC_Main', 'SimulationCommand', 'update');

    sim('ACC_Main', 'StopTime', '20', 'SaveOutput', 'off');
catch ME
    detail = ME.message;
    if isprop(ME,'cause')
        for ci = 1:numel(ME.cause)
            detail = [detail ' | CAUSE: ' ME.cause{ci}.message]; %#ok<AGROW>
        end
    end
    fprintf('Demo simulation failed: %s\n', detail);
end

set_param([leadMdl '/LeadSpeed_kmh'], 'Time', speedTime0);
set_param([leadMdl '/AccelerateAway'], 'start', rampStart0);
set_param([leadMdl '/AccelerateAway'], 'slope', rampSlope0);
