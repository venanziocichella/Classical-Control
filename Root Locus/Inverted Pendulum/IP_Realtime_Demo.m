function IP_Realtime_Demo
%IP_REALTIME_DEMO  Real-time simulation of the inverted pendulum with a controller.
%
%   Run IP_Realtime_Demo to watch the pendulum balanced by the controller
%   C(s) designed in IP_Control_Design. Push it with the buttons (or the
%   Left/Right arrow keys) to see how the controller rejects a disturbance.
%   R = reset, Space = pause.
%
%   >>> TO TRY YOUR OWN CONTROLLER, EDIT THE LINE  C = ...  IN THE BOX BELOW <<<

%% ===================== YOUR CONTROLLER: EDIT HERE =====================
s = tf('s');
C = 11.8*(1 + 0.2*s + 0.05/s)/(s/100+1);   % <-- type your controller C(s) here
%% ======================================================================
% The controller sees the error e = r - theta (r = 0, upright) and
% produces the control input u = C(s) e.

%% Model (same values as IP_Control_Design.m)
g = 9.8;            % gravity [m/s^2]
L = 1;              % pendulum length [m]
% Plant: theta'' = g/L*sin(theta) + u,  linearization G(s) = 1/(s^2 - g/L)
plant = @(x, u) [x(2); g/L*sin(x(1)) + u];   % state x = [theta; theta']
x0 = [5*pi/180; 0];          % initial state after a reset (5 deg tilt)
yOf = @(x) x(1);             % output: theta [rad]
rOf = @(t) 0;                % reference: upright
isFailed = @(x) abs(x(1)) > pi/2;   % the pendulum fell
failText = 'Fell!';
uLim = [-100 100];           % actuator saturation [min max]
push = 8; pushTime = 0.2;    % size and duration of a push (added to u)
pushNames = {'<-- Push left', 'Push right -->'};
yLabel = 'theta [deg]'; yScale = 180/pi;
figName = 'Inverted Pendulum: closed-loop simulation';

%% ============== Simulation engine (no need to edit below) ==============
srcFile = [mfilename('fullpath') '.m'];   % Reset re-reads C from this file
Ac = []; Bc = []; Cc = []; Dc = 0; nc = 0;
setController(C);
x = x0; xc = zeros(nc, 1); t = 0; u = 0; r = rOf(0);
d = 0; dUntil = -1;              % current disturbance and when it ends
paused = false; stopped = false; speed = 1; dt = 1e-3;
sc = struct();                   % graphics handles of the animation
nH = 600; tHist = nan(1, nH); yHist = tHist; rHist = tHist; kHist = 0;

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
frameTime = 1/30;                     % redraw at ~30 fps
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
    drawnow                           % wait until the frame is rendered, so
                                      % button presses do not queue up behind it
    pause(max(0.001, frameTime - toc(tFrame)));   % idle rest of frame, run callbacks
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

    function setController(Cnew)
        [numC, denC] = tfdata(tf(Cnew), 'v');
        [Ac, Bc, Cc, Dc] = localTf2ss(numC, denC);
        nc = size(Ac, 1);
    end

    function reset()
        % Re-read the controller C(s) from the box at the top of this file
        % (unsaved edits in the Editor included), then restart.
        try
            setController(localReadController(srcFile));
        catch err
            uialert(fig, err.message, 'Controller not updated (using previous C)');
        end
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

%% Animation of the pendulum
    function setupScene()
        ax.XLim = [-1.6 1.6]*L; ax.YLim = [-0.3 1.35]*L;
        plot(ax, [-1.6 1.6]*L, [-0.12 -0.12]*L, 'Color', [0.4 0.4 0.4], 'LineWidth', 2);
        patch(ax, [-0.15 0.15 0.15 -0.15]*L, [-0.12 -0.12 0 0]*L, [0.75 0.75 0.75], ...
            'EdgeColor', [0.4 0.4 0.4]);
        sc.tr = hgtransform('Parent', ax);
        line('Parent', sc.tr, 'XData', [0 0], 'YData', [0 L], 'LineWidth', 6, ...
            'Color', [0.2 0.2 0.2]);
        th = linspace(0, 2*pi, 40);
        patch('Parent', sc.tr, 'XData', 0.08*L*cos(th), 'YData', L + 0.08*L*sin(th), ...
            'FaceColor', [0.85 0.33 0.1], 'EdgeColor', 'none');
        patch(ax, 0.04*L*cos(th), 0.04*L*sin(th), [0.3 0.3 0.3], 'EdgeColor', 'none');
        sc.arrow = plot(ax, NaN, NaN, 'Color', [0.8 0 0], 'LineWidth', 4);
    end

    function drawScene()
        sc.tr.Matrix = makehgtform('zrotate', -x(1));
        if d ~= 0      % show the push as a red arrow at the bob
            sc.arrow.XData = L*sin(x(1)) - sign(d)*[0.4 0.12]*L;
            sc.arrow.YData = L*cos(x(1))*[1 1];
        else
            sc.arrow.XData = NaN; sc.arrow.YData = NaN;
        end
    end
end

function C = localReadController(file)
% Evaluate the YOUR CONTROLLER block of this file and return C.
txt = '';
try   % use the Editor's text, if open, so the file need not be saved
    doc = matlab.desktop.editor.findOpenDocument(file);
    if ~isempty(doc), txt = doc.Text; end
catch
end
if isempty(txt), txt = fileread(file); end
i1 = strfind(txt, 'YOUR CONTROLLER: EDIT HERE');
i1 = i1(1) + find(txt(i1(1):end) == newline, 1);   % first line of the block
i2 = i1 - 1 + strfind(txt(i1:end), '%% ====');      % closing line of the block
eval(txt(i1:i2(1) - 1));                            % defines s and C
if ~exist('C', 'var')
    error('The controller block must define C.');
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
