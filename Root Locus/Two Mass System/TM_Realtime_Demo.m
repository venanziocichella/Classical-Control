function TM_Realtime_Demo
%TM_REALTIME_DEMO  Real-time simulation of the two-mass system with a controller.
%
%   Run TM_Realtime_Demo to watch the controller C(s) designed in
%   TM_Control_Design move mass 1 to a commanded position (dashed line) that
%   changes every few seconds. The force acts on mass 1; mass 2 is only
%   connected through the spring k2. Push mass 1 with the buttons (or the
%   Left/Right arrow keys). R = reset, Space = pause.
%
%   >>> TO TRY YOUR OWN CONTROLLER, EDIT THE LINE  C = ...  IN THE BOX BELOW <<<

%% ===================== YOUR CONTROLLER: EDIT HERE =====================
s = tf('s');
C = 5*(s+1)^2/(s*(s/20+1));           % <-- type your controller C(s) here
%% ======================================================================
% The controller sees the error e = r - x1 and produces the force on
% mass 1, u = C(s) e.

%% Model (Chapter 1, two-mass system; same values as TM_Control_Design.m)
% The notes give no numbers for this example; these are chosen values.
m1 = 1; m2 = 1;     % masses [kg]
k1 = 1; k2 = 1;     % spring constants [N/m]
b = 0.5;            % damper on mass 2 [N s/m]
% Plant: m1 x1'' + (k1 + k2) x1 = u + k2 x2
%        m2 x2'' + b x2' + k2 x2 = k2 x1
plant = @(x, u) [x(2); (u + k2*x(3) - (k1 + k2)*x(1))/m1; ...
                 x(4); (k2*x(1) - b*x(4) - k2*x(3))/m2];   % x = [x1; x1'; x2; x2']
x0 = [0; 0; 0; 0];                    % initial state after a reset
yOf = @(x) x(1);                      % output: position of mass 1 [m]
targets = [0.5 -0.5 1 0];             % commanded positions of mass 1, in order [m]
rOf = @(t) targets(mod(floor(t/10), numel(targets)) + 1);   % new command every 10 s
isFailed = @(x) false;
failText = '';
uLim = [-20 20];                      % force saturation [min max] [N]
push = 3; pushTime = 0.5;             % push on mass 1 [N] and duration [s] (added to u)
pushNames = {'<-- Push mass 1 left', 'Push mass 1 right -->'};
yLabel = 'x_1 [m]'; yScale = 1;
figName = 'Two-mass system: closed-loop simulation';

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

%% Animation: wall - k1 - m1 - k2 - m2 - b - wall
    function setupScene()
        ax.XLim = [-3.2 3.2]; ax.YLim = [-0.9 1.3];
        sc.xL = -3; sc.xR = 3; sc.c1 = -1; sc.c2 = 1; sc.w = 0.6; sc.hB = 0.6;
        patch(ax, [-3.2 sc.xL sc.xL -3.2], [-0.25 -0.25 0.75 0.75], [0.6 0.6 0.6], 'EdgeColor', 'none');
        patch(ax, [sc.xR 3.2 3.2 sc.xR], [-0.25 -0.25 0.75 0.75], [0.6 0.6 0.6], 'EdgeColor', 'none');
        plot(ax, [sc.xL sc.xR], [-0.25 -0.25], 'Color', [0.4 0.4 0.4], 'LineWidth', 2);
        sc.tgt = plot(ax, [0 0], [-0.25 0.65], '--', 'Color', [0.47 0.67 0.19], 'LineWidth', 2);
        sc.s1 = plot(ax, 0, 0, 'Color', [0.2 0.2 0.2], 'LineWidth', 2);
        sc.s2 = plot(ax, 0, 0, 'Color', [0.2 0.2 0.2], 'LineWidth', 2);
        sc.dmp = plot(ax, 0, 0, 'Color', [0.2 0.2 0.2], 'LineWidth', 2);
        sc.b1 = patch(ax, [0 1 1 0], [0 0 1 1], [0.85 0.33 0.1], 'EdgeColor', [0.3 0.3 0.3]);
        sc.b2 = patch(ax, [0 1 1 0], [0 0 1 1], [0.3 0.45 0.7], 'EdgeColor', [0.3 0.3 0.3]);
        sc.l1 = text(ax, 0, 0, 'm_1', 'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
        sc.l2 = text(ax, 0, 0, 'm_2', 'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
        sc.arrow = plot(ax, NaN, NaN, 'Color', [0.8 0 0], 'LineWidth', 4);
    end

    function drawScene()
        w = sc.w; p1 = sc.c1 + x(1); p2 = sc.c2 + x(3);
        [sc.s1.XData, sc.s1.YData] = zigzag(sc.xL, p1 - w/2, 0.05);
        [sc.s2.XData, sc.s2.YData] = zigzag(p1 + w/2, p2 - w/2, 0.15);
        % damper (dashpot) from mass 2 to the right wall
        a = p2 + w/2; gap = sc.xR - a; yd = 0.05; hc = 0.07;
        c0 = sc.xR - 0.15*gap; c1 = sc.xR - 0.6*gap; pp = sc.xR - 0.45*gap;
        sc.dmp.XData = [sc.xR c0 NaN c1 c0 c0 c1 NaN pp pp NaN pp a];
        sc.dmp.YData = [yd yd NaN yd+hc yd+hc yd-hc yd-hc NaN yd-0.8*hc yd+0.8*hc NaN yd yd];
        sc.b1.XData = p1 + [-1 1 1 -1]*w/2; sc.b1.YData = -0.25 + [0 0 1 1]*sc.hB;
        sc.b2.XData = p2 + [-1 1 1 -1]*w/2; sc.b2.YData = -0.25 + [0 0 1 1]*sc.hB;
        sc.l1.Position = [p1 0.05 0]; sc.l2.Position = [p2 0.05 0];
        sc.tgt.XData = sc.c1 + [r r];
        if d ~= 0
            sc.arrow.XData = p1 - sign(d)*[0.7 0.35]; sc.arrow.YData = [0.5 0.5];
        else
            sc.arrow.XData = NaN; sc.arrow.YData = NaN;
        end
    end

    function [xs, ys] = zigzag(xa, xb, y0)
        n = 8; xs = linspace(xa, xb, 2*n + 1);
        ys = y0 + 0.07*[0 repmat([1 -1], 1, n-1) 1 0]; ys = ys(1:numel(xs));
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
