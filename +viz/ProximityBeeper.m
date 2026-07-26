classdef ProximityBeeper < handle
    %PROXIMITYBEEPER  Nhịp bíp/nháy của cảm biến khoảng cách phía trước.
    %
    %   Càng gần vật cản thì chu kỳ bíp càng ngắn và cao độ càng cao, mô
    %   phỏng cảm biến lùi/tiến trên xe thật.
    %
    %   Nhịp tính theo simTime (thời gian mô phỏng) chứ không theo
    %   wall-clock, để không phụ thuộc tốc độ vẽ khung hình.
    %
    %   Trước đây mỗi tiếng bíp đều dựng lại vector sin ngay trong vòng
    %   lặp solver. Nay các tông được dựng sẵn một lần thành audioplayer
    %   và tái sử dụng, nên lúc chạy chỉ còn thao tác play() không đồng bộ.

    properties (Constant, Access = private)
        PERIOD_MAX   = 1.0    % giây - chu kỳ khi vật cản còn xa
        PERIOD_MIN   = 0.08   % giây - chu kỳ khi vật cản rất gần
        ON_FRACTION  = 0.3    % tỉ lệ thời gian sáng/kêu trong mỗi chu kỳ
        TONE_FS      = 8000   % Hz - tần số lấy mẫu
        FREQ_MIN     = 600    % Hz - cao độ khi còn xa
        FREQ_MAX     = 1400   % Hz - cao độ khi rất gần
        NUM_TONES    = 8      % số mức cao độ dựng sẵn
    end

    properties (Access = private)
        players        % mảng audioplayer dựng sẵn theo mức độ gần
        nextPulseTime = []
        pulseOffTime  = -Inf
        isOn = false
    end

    methods

        function obj = ProximityBeeper()
            obj.players = obj.buildTonePlayers();
        end

        function on = update(obj, level, simTime)
            %UPDATE  Cập nhật nhịp theo mức độ gần, trả về đèn đang sáng hay không.
            if level <= 0
                obj.nextPulseTime = [];
                obj.isOn = false;
                on = false;
                return;
            end

            period = obj.PERIOD_MAX - level * (obj.PERIOD_MAX - obj.PERIOD_MIN);

            if isempty(obj.nextPulseTime)
                % Vật cản vừa lọt vào tầm cảm biến - đợi hết một chu kỳ
                % rồi mới bíp, không kêu ngay lập tức.
                obj.nextPulseTime = simTime + period;
            elseif simTime >= obj.nextPulseTime
                obj.playTone(level);
                obj.isOn = true;
                obj.pulseOffTime  = simTime + obj.ON_FRACTION * period;
                obj.nextPulseTime = simTime + period;
            end

            if obj.isOn && simTime >= obj.pulseOffTime
                obj.isOn = false;
            end
            on = obj.isOn;
        end
    end

    methods (Access = private)

        function playTone(obj, level)
            idx = min(obj.NUM_TONES, max(1, round(level * (obj.NUM_TONES-1)) + 1));
            p = obj.players{idx};
            if isempty(p); return; end   % máy không có thiết bị âm thanh
            try
                stop(p);
                play(p);
            catch
                % Mất thiết bị âm thanh giữa chừng - bỏ qua, phần hình vẫn chạy.
            end
        end

        function players = buildTonePlayers(obj)
            players = cell(1, obj.NUM_TONES);
            for i = 1:obj.NUM_TONES
                level = (i-1) / (obj.NUM_TONES-1);
                freq  = obj.FREQ_MIN + level * (obj.FREQ_MAX - obj.FREQ_MIN);
                amp   = 0.15 + level * 0.65;
                % Độ dài tông lấy theo chu kỳ tương ứng với mức độ gần này.
                period = obj.PERIOD_MAX - level * (obj.PERIOD_MAX - obj.PERIOD_MIN);
                t = 0:(1/obj.TONE_FS):(obj.ON_FRACTION * period);
                try
                    players{i} = audioplayer(amp * sin(2*pi*freq*t), obj.TONE_FS);
                catch
                    players{i} = [];   % không có thiết bị âm thanh
                end
            end
        end
    end
end
