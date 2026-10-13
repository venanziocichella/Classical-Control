function CS_Realtime_Demo
%CS_REALTIME_DEMO  Real-time simulation of the cold storage unit with a controller.
%
%   Run CS_Realtime_Demo to watch the controller C(s) designed in
%   CS_Control_Design adjust the cooling power so that the temperature
%   follows the commanded temperature (dashed line), which changes every few
%   seconds. Open the door or add ice with the buttons (or the Left/Right
%   arrow keys). R = reset, Space = pause.
%
%   >>> TO TRY YOUR OWN CONTROLLER, EDIT THE LINE  C = ...  IN THE BOX BELOW <<<

%% ===================== YOUR CONTROLLER: EDIT HERE =====================
s = tf('s');
C = -2*(s+1)/s;                       % <-- type your controller C(s) here
%% ======================================================================
% The controller sees the error e = r - T (commanded minus actual
% temperature) and sets the cooling power P = C(s) e. The AC can only cool,
% so P cannot be negative.

%% Model (Chapter 1, cold storage unit; same values as CS_Control_Design.m)
h = 1;              % heat transfer constant [1/s]
Ta = 15;            % ambient temperature [deg C]
% Plant: T' = -h (T - Ta) - P,  G(s) = -1/(s + h)  (plus the effect of Ta)
plant = @(x, u) -h*(x(1) - Ta) - u;   % state x = T [deg C]
x0 = 15;                              % initial temperature after a reset [deg C]
yOf = @(x) x(1);                      % output: temperature T [deg C]
targets = [5 0 8 3];                  % commanded temperatures, in order [deg C]
rOf = @(t) targets(mod(floor(t/6), numel(targets)) + 1);   % new command every 6 s
isFailed = @(x) false;
failText = '';
uLim = [0 40];                        % cooling power limits [min max]
push = 10; pushTime = 1;              % heat load / extra cooling and its duration [s]
pushNames = {'Open the door (heat)', 'Add ice (cool)'};
yLabel = 'temperature [deg C]'; yScale = 1;
figName = 'Cold storage unit: closed-loop simulation';

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

%% Animation of the cold room (color = temperature) and a thermometer
    function setupScene()
        ax.XLim = [-5 7]; ax.YLim = [-1.5 7.5];
        sc.room = patch(ax, [-4 2 2 -4], [0 0 5 5], [0.5 0.5 0.9], 'EdgeColor', [0.2 0.2 0.2], ...
            'LineWidth', 3);
        sc.door = patch(ax, [-0.5 1 1 -0.5], [0 0 3.5 3.5], [0.75 0.75 0.75], ...
            'EdgeColor', [0.3 0.3 0.3]);
        patch(ax, [-3.5 -1.5 -1.5 -3.5], [5 5 5.8 5.8], [0.85 0.85 0.85], 'EdgeColor', [0.3 0.3 0.3]);
        text(ax, -2.5, 5.4, 'AC', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
        sc.cold = plot(ax, NaN, NaN, 'Color', [0.2 0.5 1], 'LineWidth', 2);
        sc.ttxt = text(ax, -1, 2.5, '', 'HorizontalAlignment', 'center', 'FontSize', 20, ...
            'FontWeight', 'bold', 'Color', 'w');
        % thermometer from -5 to 20 deg C
        sc.tmap = @(T) 0.2 + 5*(T + 5)/25;
        patch(ax, [4 5 5 4], sc.tmap([-5 -5 20 20]), [0.95 0.95 0.95], 'EdgeColor', [0.3 0.3 0.3]);
        for T = -5:5:20
            plot(ax, [5 5.3], sc.tmap([T T]), 'Color', [0.3 0.3 0.3]);
            text(ax, 5.4, sc.tmap(T), sprintf('%d', T), 'FontSize', 9);
        end
        sc.merc = patch(ax, [4.2 4.8 4.8 4.2], sc.tmap([-5 -5 0 0]), [0.85 0.1 0.1], 'EdgeColor', 'none');
        sc.ref = plot(ax, [3.8 5.2], [0 0], '--', 'Color', [0.47 0.67 0.19], 'LineWidth', 2);
        sc.ptxt = text(ax, -1, -0.8, '', 'HorizontalAlignment', 'center', 'FontSize', 11);
    end

    function drawScene()
        T = x(1);
        a = min(max((T + 5)/25, 0), 1);       % 0 = cold (blue), 1 = warm (red)
        sc.room.FaceColor = (1 - a)*[0.2 0.4 0.9] + a*[0.9 0.4 0.2];
        sc.ttxt.String = sprintf('%.1f C', T);
        sc.merc.YData = sc.tmap([-5 -5 min(max(T, -5), 20) min(max(T, -5), 20)]);
        sc.ref.YData = sc.tmap([r r]);
        if d < 0, sc.door.FaceColor = [1 1 0.8]; else, sc.door.FaceColor = [0.75 0.75 0.75]; end
        n = round(min(u, 40)/5);              % "cold air" lines below the AC
        xs = []; ys = [];
        for i = 1:n
            xi = -3.5 + 2*i/(n + 1); xs = [xs xi xi NaN]; ys = [ys 4.9 4.2 NaN]; %#ok<AGROW>
        end
        if isempty(xs), xs = NaN; ys = NaN; end
        sc.cold.XData = xs; sc.cold.YData = ys;
        sc.ptxt.String = sprintf('Cooling power P = %.1f', u);
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
