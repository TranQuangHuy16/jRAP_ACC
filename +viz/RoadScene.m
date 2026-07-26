classdef RoadScene < handle
    %ROADSCENE  Khung nhìn 2D của mô phỏng ACC: đường, hai xe, HUD, đồng hồ.
    %
    %   Tách ra từ updateCar2D.m để phần vẽ không còn trộn lẫn với phần
    %   âm thanh và phần điều tiết khung hình. Toàn bộ đối tượng đồ hoạ
    %   được giữ trong thuộc tính của lớp thay vì một dãy biến persistent.
    %
    %   Cách dùng:
    %       scene = viz.RoadScene();
    %       scene.render(state);   % state là struct, xem hàm render
    %
    %   Xe được dựng trên hgtransform nên mỗi khung hình chỉ cần dịch
    %   chuyển transform, không phải cập nhật từng bộ phận riêng lẻ.

    properties (Constant, Access = private)
        LEAD_VISIBLE_CUTOFF_M = 400   % xe trước đi xa hơn mức này thì coi như khuất tầm nhìn
        GAUGE_MAX_SPEED = 140         % km/h - thang đo cố định của đồng hồ
        MIN_WINDOW_WIDTH = 100        % m - bề rộng khung nhìn tối thiểu
        CAMERA_MARGIN = 20            % m - khoảng đệm trước mũi xe
    end

    properties (Access = private)
        fig; ax
        roadTop; roadBottom; centerLine
        infoText; statusText; leadText
        egoCar; leadCar
        gaugeArcLow; gaugeArcMid; gaugeArcHigh; gaugeNeedle; gaugeSpeedText
        leadEverAppeared = false
    end

    methods

        function tf = isValid(obj)
            tf = ~isempty(obj.fig) && isgraphics(obj.fig);
        end

        function render(obj, s)
            %RENDER  Vẽ một khung hình.
            %
            %   s là struct với các trường:
            %     position, currentSpeed, desiredSpeed, throttle, brake,
            %     leadPosition, leadPresent, proximityLevel, proxGlowOn

            if ~obj.isValid()
                obj.build(s);
            end

            [carColor, statusLabel, statusColor] = obj.vehicleState(s.throttle, s.brake);

            obj.moveCar(obj.egoCar, s.position, carColor, s.brake > 0.5);
            obj.applyProxGlow(s.proximityLevel, s.proxGlowOn);

            showLead = obj.updateLeadVisibility(s);
            [leftLimit, rightLimit] = obj.updateCamera(s, showLead);
            obj.updateRoad(leftLimit, rightLimit);
            obj.updateReadouts(s, showLead, leftLimit, statusLabel, statusColor);
            obj.updateGauge(s.currentSpeed, rightLimit);

            drawnow limitrate;
        end
    end

    methods (Access = private)

        function build(obj, s)
            obj.fig = figure( ...
                'Name', 'ACC 2D Vehicle Simulation', ...
                'NumberTitle', 'off', ...
                'Color', [0.85 0.92 1.00]);

            obj.ax = axes(obj.fig);
            hold(obj.ax, 'on');

            obj.roadTop    = plot(obj.ax, [0 100], [3 3], 'Color','white','LineWidth',3);
            obj.roadBottom = plot(obj.ax, [0 100], [-1 -1], 'Color','white','LineWidth',3);
            obj.centerLine = plot(obj.ax, [0 100], [1 1], '--', 'Color',[1 1 0],'LineWidth',1.5);

            obj.egoCar  = obj.buildCar([0.10 0.45 0.95]);
            obj.leadCar = obj.buildCar([0.95 0.60 0.10]);
            set(obj.leadCar.tf, 'Visible', 'off');

            obj.leadText = text(obj.ax, s.leadPosition, 2.5, 'LEAD', ...
                'FontSize',9, 'FontWeight','bold', 'HorizontalAlignment','center', ...
                'Color',[0.60 0.35 0.00], 'Visible','off');

            obj.infoText = text(obj.ax, s.position, 6, '', ...
                'FontSize',11, 'FontWeight','bold', 'Color','black');

            obj.statusText = text(obj.ax, s.position, 4.8, '', ...
                'FontSize',12, 'FontWeight','bold');

            [tLow, tMid, tHigh] = obj.gaugeArcAngles();
            obj.gaugeArcLow  = plot(obj.ax, cos(tLow),  sin(tLow),  'Color',[0.15 0.75 0.20],'LineWidth',4);
            obj.gaugeArcMid  = plot(obj.ax, cos(tMid),  sin(tMid),  'Color',[0.95 0.75 0.10],'LineWidth',4);
            obj.gaugeArcHigh = plot(obj.ax, cos(tHigh), sin(tHigh), 'Color',[0.90 0.15 0.10],'LineWidth',4);
            obj.gaugeNeedle  = plot(obj.ax, [0 0], [0 0], 'Color','black','LineWidth',2);
            obj.gaugeSpeedText = text(obj.ax, 0, 0, '', ...
                'FontSize',10, 'FontWeight','bold', 'HorizontalAlignment','center', 'Color','black');

            xlabel(obj.ax, 'Distance (m)');
            ylabel(obj.ax, 'Road');
            title(obj.ax, 'Adaptive Cruise Control - 2D Simulation');
            grid(obj.ax, 'on');
            obj.ax.Color = [0.25 0.25 0.25];
            obj.ax.YLim  = [-2 8];

            obj.leadEverAppeared = false;
        end

        function h = buildCar(obj, bodyColor)
            % Dựng một chiếc xe dạng vector: thân, kính, bánh, đèn, hiệu ứng.
            h.tf = hgtransform('Parent', obj.ax);

            % Thân xe: dáng nhìn nghiêng - mui thấp phía trước, kính dốc
            % lên nóc, nóc bằng, đuôi dốc xuống.
            bodyX = [0   0    1.2  2.5  5.5  6.8  8    8   ];
            bodyY = [0.4 1.1  1.8  1.9  1.9  1.8  1.1  0.4 ];
            h.body = patch(obj.ax, 'XData',bodyX, 'YData',bodyY, ...
                'FaceColor',bodyColor, 'EdgeColor','black', 'LineWidth',1.2, 'Parent',h.tf);

            h.windshield = patch(obj.ax, 'XData',[1.5 2.3 3.3 3.3], 'YData',[1.35 1.85 1.85 1.35], ...
                'FaceColor',[0.75 0.90 1.00], 'FaceAlpha',0.75, 'EdgeColor','none', 'Parent',h.tf);

            h.wheelFront = rectangle(obj.ax, 'Position',[6.0 -0.3 1.2 1.2], ...
                'Curvature',[1 1], 'FaceColor','black', 'Parent',h.tf);
            h.wheelRear  = rectangle(obj.ax, 'Position',[1.0 -0.3 1.2 1.2], ...
                'Curvature',[1 1], 'FaceColor','black', 'Parent',h.tf);

            h.headlight = rectangle(obj.ax, 'Position',[7.7 0.7 0.4 0.5], ...
                'Curvature',[1 1], 'FaceColor',[1.00 0.95 0.60], 'Parent',h.tf);

            % Đèn hậu đổi màu khi phanh.
            h.tailLight = rectangle(obj.ax, 'Position',[-0.1 0.7 0.4 0.5], ...
                'Curvature',[1 1], 'FaceColor',[0.40 0.00 0.00], 'Parent',h.tf);

            h.brakeGlow = rectangle(obj.ax, 'Position',[-0.7 0.4 1.4 1.1], ...
                'Curvature',[1 1], 'FaceColor',[1 0.2 0.2], 'FaceAlpha',0.35, ...
                'EdgeColor','none', 'Parent',h.tf, 'Visible','off');

            % Đèn báo cảm biến khoảng cách, đặt ở cản trước cạnh đèn pha.
            h.proxGlow = rectangle(obj.ax, 'Position',[7.6 -0.2 1.0 1.0], ...
                'Curvature',[1 1], 'FaceColor',[0.15 0.75 0.20], 'FaceAlpha',0.6, ...
                'EdgeColor','none', 'Parent',h.tf, 'Visible','off');

            % Bụi/khói phía sau khi phanh gấp.
            h.smoke = gobjects(1,3);
            smokeOffsets = [-1.3 0.35; -2.0 0.55; -1.1 0.75];
            for i = 1:3
                h.smoke(i) = rectangle(obj.ax, ...
                    'Position',[smokeOffsets(i,1) smokeOffsets(i,2) 0.9 0.9], ...
                    'Curvature',[1 1], 'FaceColor',[0.6 0.6 0.6], 'FaceAlpha',0.4, ...
                    'EdgeColor','none', 'Parent',h.tf, 'Visible','off');
            end

            set(h.tf, 'Matrix', makehgtform('translate',[0 0 0]));
        end

        function moveCar(~, h, position, bodyColor, isBraking)
            set(h.tf, 'Matrix', makehgtform('translate',[position 0 0]));
            set(h.body, 'FaceColor', bodyColor);
            if isBraking
                set(h.tailLight, 'FaceColor', [1.00 0.05 0.05]);
                set(h.brakeGlow, 'Visible', 'on');
                set(h.smoke,     'Visible', 'on');
            else
                set(h.tailLight, 'FaceColor', [0.40 0.00 0.00]);
                set(h.brakeGlow, 'Visible', 'off');
                set(h.smoke,     'Visible', 'off');
            end
        end

        function applyProxGlow(obj, level, on)
            if on && level > 0
                set(obj.egoCar.proxGlow, 'FaceColor', obj.proxLevelColor(level), 'Visible','on');
            else
                set(obj.egoCar.proxGlow, 'Visible', 'off');
            end
        end

        function showLead = updateLeadVisibility(obj, s)
            % Một khi xe trước đã từng xuất hiện thì vẫn tiếp tục hiển thị
            % nó lái đi, kể cả khi leadPresent chuyển về false (ví dụ lúc
            % nó tăng tốc rời khỏi phạm vi theo dõi của ACC), thay vì biến
            % mất đột ngột. Chỉ ẩn hẳn khi đã đi xa quá tầm nhìn.
            if s.leadPresent > 0.5
                obj.leadEverAppeared = true;
            end
            gapToLead = s.leadPosition - s.position;
            showLead = obj.leadEverAppeared && gapToLead < obj.LEAD_VISIBLE_CUTOFF_M;

            if showLead
                obj.moveCar(obj.leadCar, s.leadPosition, [0.95 0.60 0.10], false);
                set(obj.leadCar.tf, 'Visible', 'on');
                set(obj.leadText, 'Position', [s.leadPosition + 4, 2.5, 0], 'Visible','on');
            else
                set(obj.leadCar.tf, 'Visible', 'off');
                set(obj.leadText,   'Visible', 'off');
            end
        end

        function [leftLimit, rightLimit] = updateCamera(obj, s, showLead)
            leftLimit  = max(0, s.position - obj.CAMERA_MARGIN);
            rightLimit = leftLimit + obj.MIN_WINDOW_WIDTH;
            if showLead
                rightLimit = max(rightLimit, s.leadPosition + obj.CAMERA_MARGIN);
            end
            obj.ax.XLim = [leftLimit rightLimit];
        end

        function updateRoad(obj, leftLimit, rightLimit)
            set(obj.roadTop,    'XData',[leftLimit rightLimit], 'YData',[3 3]);
            set(obj.roadBottom, 'XData',[leftLimit rightLimit], 'YData',[-1 -1]);
            set(obj.centerLine, 'XData',[leftLimit rightLimit], 'YData',[1 1]);
        end

        function updateReadouts(obj, s, showLead, leftLimit, statusLabel, statusColor)
            if showLead
                gapLine = sprintf('Gap to Lead: %.1f m\n', s.leadPosition - s.position);
            else
                gapLine = '';
            end

            information = sprintf([ ...
                'Distance: %.1f m\n' ...
                'Current Speed: %.1f km/h\n' ...
                'Desired Speed: %.1f km/h\n' ...
                'Throttle: %.0f %%\n' ...
                'Brake: %.0f %%\n' ...
                '%s'], ...
                s.position, s.currentSpeed, s.desiredSpeed, ...
                s.throttle * 100, s.brake * 100, gapLine);

            set(obj.infoText,   'Position',[leftLimit + 3, 6, 0],  'String', information);
            set(obj.statusText, 'Position',[leftLimit + 40, 6, 0], 'String', statusLabel, 'Color', statusColor);
        end

        function updateGauge(obj, currentSpeed, rightLimit)
            cx = rightLimit - 14;
            cy = 5.2;
            r  = 2.0;

            [tLow, tMid, tHigh] = obj.gaugeArcAngles();
            set(obj.gaugeArcLow,  'XData', cx + r*cos(tLow),  'YData', cy + r*sin(tLow));
            set(obj.gaugeArcMid,  'XData', cx + r*cos(tMid),  'YData', cy + r*sin(tMid));
            set(obj.gaugeArcHigh, 'XData', cx + r*cos(tHigh), 'YData', cy + r*sin(tHigh));

            speedFrac = max(0, min(1, currentSpeed / obj.GAUGE_MAX_SPEED));
            needleAngle = pi - speedFrac * pi;
            set(obj.gaugeNeedle, ...
                'XData', [cx, cx + 0.85*r*cos(needleAngle)], ...
                'YData', [cy, cy + 0.85*r*sin(needleAngle)]);

            set(obj.gaugeSpeedText, 'Position',[cx, cy - 0.7, 0], ...
                'String', sprintf('%.0f km/h', currentSpeed));
        end
    end

    methods (Static, Access = private)

        function [carColor, label, labelColor] = vehicleState(throttle, brake)
            if brake > 0.5
                carColor   = [0.90 0.10 0.10];
                label      = 'BRAKING';
                labelColor = [0.90 0.10 0.10];
            elseif throttle > 0.5
                carColor   = [0.10 0.75 0.20];
                label      = 'ACCELERATING';
                labelColor = [0.00 0.55 0.10];
            else
                carColor   = [0.10 0.45 0.95];
                label      = 'HOLDING SPEED';
                labelColor = [0.10 0.30 0.90];
            end
        end

        function [tLow, tMid, tHigh] = gaugeArcAngles()
            tLow  = linspace(pi,          pi - pi/3,   20);
            tMid  = linspace(pi - pi/3,   pi - 2*pi/3, 20);
            tHigh = linspace(pi - 2*pi/3, 0,           20);
        end

        function c = proxLevelColor(level)
            % Nội suy xanh (an toàn) -> vàng -> đỏ (nguy hiểm).
            level  = max(0, min(1, level));
            green  = [0.15 0.75 0.20];
            yellow = [0.95 0.75 0.10];
            red    = [0.90 0.15 0.10];
            if level <= 0.5
                c = green + (level/0.5) * (yellow - green);
            else
                c = yellow + ((level-0.5)/0.5) * (red - yellow);
            end
        end
    end
end
