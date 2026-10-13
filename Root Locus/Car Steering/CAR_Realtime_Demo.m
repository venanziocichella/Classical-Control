function CAR_Realtime_Demo
%CAR_REALTIME_DEMO  Real-time simulation of a car changing lanes with a steering controller.
%
%   Run CAR_Realtime_Demo to watch the controller C(s) designed in
%   CAR_Control_Design steer the car so that its front follows the commanded
%   lane (dashed line), which changes every 8 s. Apply a side gust
%   with the buttons (or the Left/Right arrow keys). R = reset, Space = pause.
%
%   >>> TO TRY YOUR OWN CONTROLLER, EDIT THE LINE  C = ...  IN THE BOX BELOW <<<

%% ===================== YOUR CONTROLLER: EDIT HERE =====================
s = tf('s');
C = 2;                                % <-- type your controller C(s) here
%% ======================================================================
% The controller sees the error e = r - y (commanded minus actual lateral
% position of the front of the car) and sets the steering angle phi = C(s) e.

%% Model (Chapter 1, car with front-wheel steering; same values as CAR_Control_Design.m)
l = 1;              % wheelbase [m]
v = 1;              % constant forward speed [m/s] (acceleration f = 0)
% Plant: px' = v cos(theta), py' = v sin(theta), theta' = v/l phi
% Output y = py + l sin(theta) (front of the car)
% Linearized around theta = 0: G(s) = v (s + v/l)/s^2
plant = @(x, u) [v*cos(x(3)); v*sin(x(3)); v/l*u];   % state x = [px; py; theta]
x0 = [0; 0; 0];                       % initial state after a reset
yOf = @(x) x(2) + l*sin(x(3));        % output: lateral position of the front [m]
lanes = 2*[1 0 1 2 1 0];              % commanded lane centers (lanes are 2 m wide) [m]
rOf = @(t) lanes(mod(floor(t/8), numel(lanes)) + 1);   % new lane every 8 s
isFailed = @(x) abs(x(2) - 2) > 4;    % the car left the road
failText = 'Off the road!';
uLim = [-0.5 0.5];                    % steering angle limits [min max] [rad]
push = 0.3; pushTime = 0.5;           % side gust (as an equivalent steering angle) [rad], [s]
pushNames = {'Gust from the left', 'Gust from the right'};
yLabel = 'lateral position [m]'; yScale = 1;
figName = 'Car lane change: closed-loop simulation';

%% ============== Simulation engine (no need to edit below) ==============
[numC, denC] = tfdata(tf(C), 'v');
[Ac, Bc, Cc, Dc] = localTf2ss(numC, denC);
nc = size(Ac, 1);
x = x0; xc = zeros(nc, 1); t = 0; u = 0; r = rOf(0);
d = 0; dUntil = -1;              % current disturbance and when it ends
paused = false; stopped = false; speed = 1; dt = 1e-3;
sc = struct();                   % graphics handles of the animation
nH = 3000; tHist = nan(1, nH); yHist = tHist; rHist = tHist; kHist = 0;

fig = uifigure('Name', figName, 'Position', [100 100 1000 650], 'Color', 'w');
gl = uigridlayout(fig, [2 2]);
gl.ColumnWidth = {'1x', 220}; gl.RowHeight = {'2x', '1x'};

% Animation
ax = uiaxes(gl); ax.Layout.Row = 1; ax.Layout.Column = 1;
axis(ax, 'equal'); hold(ax, 'on');
ax.XTick = []; ax.YTick = []; ax.Box = 'on';
ax.Toolbar.Visible = 'off'; disableDefaultInteractivity(ax);
setupScene();
msg = text(ax, mean(ax.XLim), ax.YLim(2) - 0.08*diff(ax.YLim), '', ...
    'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold', ...
    'Color', [0.8 0 0]);

% Output plot (reference dashed, output solid)
axY = uiaxes(gl); axY.Layout.Row = 2; axY.Layout.Column = 1;
hold(axY, 'on'); grid(axY, 'on'); axY.Toolbar.Visible = 'off';
disableDefaultInteractivity(axY);
xlabel(axY, 'time [s]'); ylabel(axY, yLabel);
rLine = plot(axY, NaN, NaN, 'k--', 'LineWidth', 1);
yLine = plot(axY, NaN, NaN, 'LineWidth', 1.5, 'Color', [0 0.45 0.74]);

% Control panel
pn = uigridlayout(gl, [9 1]); pn.Layout.Row = [1 2]; pn.Layout.Column = 2;
pn.RowHeight = repmat({'fit'}, 1, 9);
uilabel(pn, 'Text', 'Disturbance', 'FontWeight', 'bold');
uibutton(pn, 'Text', pushNames{1}, 'ButtonPushedFcn', @(~,~) doPush(-1));
uibutton(pn, 'Text', pushNames{2}, 'ButtonPushedFcn', @(~,~) doPush(1));
uilabel(pn, 'Text', 'Speed', 'FontWeight', 'bold');
uidropdown(pn, 'Items', {'0.25x', '0.5x', '1x (real time)', '2x', '5x', '10x'}, ...
    'Value', '1x (real time)', 'ValueChangedFcn', @(src,~) setSpeed(src.Value));
uibutton(pn, 'Text', 'Reset  (R)', 'ButtonPushedFcn', @(~,~) reset());
uibutton(pn, 'Text', 'Pause  (Space)', 'ButtonPushedFcn', @(~,~) togglePause());
lblT = uilabel(pn, 'Text', 't = 0.0 s', 'FontSize', 14);
uilabel(pn, 'WordWrap', 'on', 'FontColor', [0.4 0.4 0.4], 'Text', ...
    ['To try your controller, edit the line  C = ...  at the top of ' mfilename '.m']);
fig.WindowKeyPressFcn = @keyPress;

%% Real-time loop
reset();
carry = 0; tFrame = tic;
while isvalid(fig)
    dWall = min(toc(tFrame), 0.05);   % wall time since last frame (capped)
    tFrame = tic;
    if ~(paused || stopped)
        carry = carry + dWall*speed;  % plant time to simulate
        while carry >= dt && ~stopped
            step(dt);
            carry = carry - dt;
        end
        if kHist == nH
            tHist = [tHist(2:end) NaN]; yHist = [yHist(2:end) NaN]; rHist = [rHist(2:end) NaN];
        else
            kHist = kHist + 1;
        end
        tHist(kHist) = t; yHist(kHist) = yOf(x)*yScale; rHist(kHist) = r*yScale;
    else
        carry = 0;
    end
    draw();
    drawnow limitrate
    pause(0.005);
end

%% Engine functions
    function step(h)
        % One RK4 step of length h (plant seconds) for plant + controller.
        if t >= dUntil, d = 0; end
        r = rOf(t);
        [k1, c1] = deriv(x, xc);
        [k2, c2] = deriv(x + h/2*k1, xc + h/2*c1);
        [k3, c3] = deriv(x + h/2*k2, xc + h/2*c2);
        [k4, c4] = deriv(x + h*k3, xc + h*c3);
        x = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
        xc = xc + h/6*(c1 + 2*c2 + 2*c3 + c4);
        t = t + h;
        if isFailed(x), stopped = true; end
    end

    function [dx, dxc] = deriv(x, xc)
        e = r - yOf(x);                                 % tracking error
        u = min(max(Cc*xc + Dc*e, uLim(1)), uLim(2));   % saturated control input
        dxc = Ac*xc + Bc*e;
        dx = plant(x, u + d);                           % disturbance adds to u
    end

    function draw()
        drawScene();
        if stopped, msg.String = [failText '  Press R'];
        elseif paused, msg.String = 'Paused';
        elseif d ~= 0, msg.String = 'Disturbance!';
        else, msg.String = '';
        end
        yLine.XData = tHist(1:kHist); yLine.YData = yHist(1:kHist);
        rLine.XData = tHist(1:kHist); rLine.YData = rHist(1:kHist);
        axY.XLim = [max(0, t - 10), max(10, t)];
        lblT.Text = sprintf('t = %.1f s', t);
    end

    function doPush(dir)
        d = dir*push; dUntil = t + pushTime;
    end

    function setSpeed(v)
        speed = sscanf(v, '%f');     % '0.25x' -> 0.25, '1x (real time)' -> 1
        dt = 1e-3*max(1, speed/2);   % larger steps when running fast
    end

    function reset()
        x = x0; xc = zeros(nc, 1); t = 0; r = rOf(0); d = 0; dUntil = -1;
        stopped = false;
        kHist = 0; tHist(:) = NaN; yHist(:) = NaN; rHist(:) = NaN;
    end

    function togglePause()
        paused = ~paused;
    end

    function keyPress(~, evt)
        switch evt.Key
            case 'leftarrow',  doPush(-1);
            case 'rightarrow', doPush(1);
            case 'r', reset();
            case 'space', togglePause();
        end
    end

%% Animation of the car seen from above (the view follows the car)
    function setupScene()
        ax.XLim = [-4 12]; ax.YLim = [-2 7];
        patch(ax, [-50 5000 5000 -50], [-1 -1 5 5], [0.35 0.35 0.35], 'EdgeColor', 'none');
        plot(ax, [-50 5000], [-1 -1], 'w', 'LineWidth', 3);
        plot(ax, [-50 5000], [5 5], 'w', 'LineWidth', 3);
        for yl = [1 3]                         % dashed lane markings
            xm = -50:2:5000;
            plot(ax, reshape([xm; xm + 1; nan(size(xm))], 1, []), yl*ones(1, 3*numel(xm)), ...
                'w', 'LineWidth', 2);
        end
        sc.ref = plot(ax, [-50 5000], [0 0], '--', 'Color', [0.47 0.67 0.19], 'LineWidth', 2);
        sc.trail = plot(ax, NaN, NaN, 'Color', [1 0.8 0.2], 'LineWidth', 1.5);
        sc.tx = nan(1, 600); sc.ty = sc.tx;
        sc.tr = hgtransform('Parent', ax);    % car body: rear axle at the origin
        patch('Parent', sc.tr, 'XData', [-0.25 1.25 1.25 -0.25], 'YData', [-0.4 -0.4 0.4 0.4], ...
            'FaceColor', [0.85 0.15 0.15], 'EdgeColor', [0.2 0.2 0.2]);
        patch('Parent', sc.tr, 'XData', [0.6 1.0 1.0 0.6], 'YData', [-0.3 -0.3 0.3 0.3], ...
            'FaceColor', [0.7 0.85 1], 'EdgeColor', 'none');
        for yw = [-0.45 0.45]                 % rear wheels
            line('Parent', sc.tr, 'XData', [-0.15 0.15], 'YData', [yw yw], 'Color', 'k', 'LineWidth', 4);
        end
        sc.wheelL = line('Parent', sc.tr, 'XData', [0.85 1.15], 'YData', [0.45 0.45], ...
            'Color', 'k', 'LineWidth', 4);   % front wheels (steered)
        sc.wheelR = line('Parent', sc.tr, 'XData', [0.85 1.15], 'YData', -[0.45 0.45], ...
            'Color', 'k', 'LineWidth', 4);
        sc.front = plot(ax, NaN, NaN, 'o', 'MarkerSize', 6, 'MarkerFaceColor', [1 0.8 0.2], ...
            'MarkerEdgeColor', 'k');
    end

    function drawScene()
        px = x(1); py = x(2); th = x(3);
        ax.XLim = px + [-4 12];
        sc.tr.Matrix = makehgtform('translate', [px py 0]) * makehgtform('zrotate', th);
        phi = u + d;                          % steering angle of the front wheels
        sc.wheelL.XData = l + 0.15*cos(phi)*[-1 1]; sc.wheelL.YData = 0.45 + 0.15*sin(phi)*[-1 1];
        sc.wheelR.XData = l + 0.15*cos(phi)*[-1 1]; sc.wheelR.YData = -0.45 + 0.15*sin(phi)*[-1 1];
        sc.ref.YData = [r r];
        sc.front.XData = px + l*cos(th); sc.front.YData = yOf(x);
        sc.tx = [sc.tx(2:end) px + l*cos(th)]; sc.ty = [sc.ty(2:end) yOf(x)];
        sc.trail.XData = sc.tx; sc.trail.YData = sc.ty;
    end
end

function [A, B, C, D] = localTf2ss(num, den)
% Controllable canonical realization of a proper transfer function.
num = num(:).'/den(1); den = den(:).'/den(1);
n = numel(den) - 1;
if numel(num) > n + 1
    error('The controller C(s) must be proper (numerator degree <= denominator degree).');
end
num = [zeros(1, n + 1 - numel(num)) num];
D = num(1);
r = num - D*den;                 % strictly proper remainder
A = [zeros(n - 1, 1) eye(n - 1); -fliplr(den(2:end))];
B = [zeros(n - 1, 1); 1];
C = fliplr(r(2:end));
if n == 0, A = zeros(0); B = zeros(0, 1); C = zeros(1, 0); end
end
