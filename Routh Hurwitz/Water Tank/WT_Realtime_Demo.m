function WT_Realtime_Demo
%WT_REALTIME_DEMO  Real-time simulation of the water tank with a level controller.
%
%   Run WT_Realtime_Demo to watch the controller C(s) designed in
%   WT_Control_Design adjust the inflow so that the water level follows the
%   commanded level (dashed line), which changes every 20 s. Open a drain or
%   an extra supply with the buttons (or the Left/Right arrow keys).
%   R = reset, Space = pause. Use the Speed menu to run faster than real time.
%
%   Type your controller C(s) in the box on the right (e.g. 10*(s+2)/(s+5))
%   and press Enter or Apply. The plant G(s) is shown above the box.

%% Default controller (change C(s) in the sim window, no need to edit here)
C0 = '5*(1 + 0.05/s)';                % initial text of the C(s) box
% The controller sees the error e = r - h (commanded minus actual level)
% and sets the inflow Q_in = C(s) e. The inflow cannot be negative.

%% Model (Chapter 1, water tank; same values as WT_Control_Design.m)
A = 10;             % cross-section [m^2]
k = 0.5;            % outflow coefficient, Q_out = k h [m^2/s]
H = 20;             % tank height [m]
% Plant: A h' = Q_in - k h,  G(s) = 1/(A s + k)
plant = @(x, u) (u - k*x(1))/A*(x(1) > 0 || u > k*x(1));   % state x = h (h >= 0)
x0 = 0;                               % empty tank after a reset
yOf = @(x) x(1);                      % output: level h [m]
targets = [10 15 5 12];               % commanded levels, in order [m]
rOf = @(t) targets(mod(floor(t/20), numel(targets)) + 1);  % new command every 20 s
isFailed = @(x) x(1) > H;             % the tank overflows
failText = 'Overflow!';
uLim = [0 20];                        % inflow limits [min max] [m^3/s]
push = 4; pushTime = 5;               % extra outflow/inflow [m^3/s] and duration [s]
pushNames = {'Open drain (-4 m^3/s)', 'Extra supply (+4 m^3/s)'};
yLabel = 'level h [m]'; yScale = 1;
figName = 'Water tank: closed-loop simulation';

% Linear model from u to y, shown in the sim window
s = tf('s');
G = 1/(A*s + k);
Gtext = '1/(A s + k)';
[numG, denG] = tfdata(G, 'v');

%% ============== Simulation engine (no need to edit below) ==============
Ac = []; Bc = []; Cc = []; Dc = 0; nc = 0;
cInfo = setController(C0);         % text shown under the C(s) box
typingC = false;                  % true while typing in the C(s) box
x = x0; xc = zeros(nc, 1); t = 0; u = 0; r = rOf(0);
d = 0; dUntil = -1;              % current disturbance and when it ends
paused = false; stopped = false; speed = 1; dt = 1e-3;
sc = struct();                   % graphics handles of the animation
nH = 600; tHist = nan(1, nH); yHist = tHist; rHist = tHist; kHist = 0;

fig = uifigure('Name', figName, 'Position', [100 100 1000 720], 'Color', 'w');
gl = uigridlayout(fig, [2 2]);
gl.ColumnWidth = {'1x', 260}; gl.RowHeight = {'2x', '1x'};

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
pn = uigridlayout(gl, [15 1]); pn.Layout.Row = [1 2]; pn.Layout.Column = 2;
pn.RowHeight = repmat({'fit'}, 1, 15);
pn.Scrollable = 'on';
uilabel(pn, 'Text', 'Plant G(s)', 'FontWeight', 'bold');
uilabel(pn, 'WordWrap', 'on', 'Text', {['G(s) = ' Gtext], ['     = ' localTfString(numG, denG)]});
uilabel(pn, 'Text', 'Controller C(s)', 'FontWeight', 'bold');
edC = uieditfield(pn, 'text', 'Value', C0, ...
    'ValueChangingFcn', @(~,~) setTyping(true), 'ValueChangedFcn', @(~,~) applyController());
uibutton(pn, 'Text', 'Apply C(s)  (Enter)', 'ButtonPushedFcn', @(~,~) applyController());
lblC = uilabel(pn, 'Text', cInfo, 'WordWrap', 'on', 'FontColor', [0.4 0.4 0.4]);
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
    ['C(s) is typed in terms of s, e.g. 10*(s+2)/(s+5). The controller sees ' ...
     'the error e = r - y and outputs u = C(s) e.']);
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

    function info = setController(str)
        % Build the state-space realization of the C(s) typed in the box.
        [numC, denC] = localParseController(str);
        [Ac, Bc, Cc, Dc, nExtra] = localTf2ss(numC, denC);
        nc = size(Ac, 1);
        info = ['Simulating C(s) = ' localTfString(numC, denC)];
        if nExtra > 0
            info = sprintf('%s  (improper: times 1/(s/100+1)^%d)', info, nExtra);
        end
    end

    function applyController()
        % Read C(s) from the box and restart the simulation with it.
        typingC = false;
        try
            cInfo = setController(edC.Value);
        catch err
            uialert(fig, err.message, 'Controller not updated (using previous C)');
            return
        end
        lblC.Text = cInfo;
        reset();
    end

    function setTyping(v)
        typingC = v;   % hot keys are off while typing C(s)
    end

    function reset()
        % Restart with the current controller C(s).
        x = x0; xc = zeros(nc, 1); t = 0; r = rOf(0); d = 0; dUntil = -1;
        stopped = false;
        kHist = 0; tHist(:) = NaN; yHist(:) = NaN; rHist(:) = NaN;
    end

    function togglePause()
        paused = ~paused;
    end

    function keyPress(~, evt)
        if typingC, return; end
        switch evt.Key
            case 'leftarrow',  doPush(-1);
            case 'rightarrow', doPush(1);
            case 'r', reset();
            case 'space', togglePause();
        end
    end

%% Animation of the tank (drawn to scale: 1 m of level = 1 unit)
    function setupScene()
        ax.XLim = [-12 12]; ax.YLim = [-3 26];
        w = 6;                                % half width of the drawing [m]
        sc.w = w;
        sc.water = patch(ax, [-w w w -w], [0 0 0 0], [0.3 0.6 0.9], 'EdgeColor', 'none');
        plot(ax, [-w -w w w], [H+1 0 0 H+1], 'Color', [0.2 0.2 0.2], 'LineWidth', 3);
        for hh = 0:5:H                        % level marks
            plot(ax, [w w+0.6], [hh hh], 'Color', [0.4 0.4 0.4]);
            text(ax, w+0.9, hh, sprintf('%d m', hh), 'FontSize', 9, 'Color', [0.4 0.4 0.4]);
        end
        sc.ref = plot(ax, [-w w], [0 0], '--', 'Color', [0.47 0.67 0.19], 'LineWidth', 2);
        % inflow pipe (top left) and outflow pipe (bottom right)
        plot(ax, [-11 -w+1 -w+1], [H+3 H+3 H+2], 'Color', [0.4 0.4 0.4], 'LineWidth', 6);
        plot(ax, [w 11], [0.5 0.5], 'Color', [0.4 0.4 0.4], 'LineWidth', 6);
        sc.inflow = plot(ax, [-w+1 -w+1], [H+2 0], 'Color', [0.3 0.6 0.9], 'LineWidth', 1);
        sc.outflow = plot(ax, [11 11.5], [0.5 -2.5], 'Color', [0.3 0.6 0.9], 'LineWidth', 1);
        sc.qtxt = text(ax, -11, H+4.5, '', 'FontSize', 11);
    end

    function drawScene()
        w = sc.w; h = max(x(1), 0);
        sc.water.YData = [0 0 h h];
        sc.ref.YData = [r r];
        q = u + d;                            % actual inflow (controller + disturbance)
        sc.inflow.LineWidth = max(0.5, 0.6*max(q, 0));
        sc.inflow.YData = [H+2 h];
        if q <= 0.05, sc.inflow.Color = 'none'; else, sc.inflow.Color = [0.3 0.6 0.9]; end
        sc.outflow.LineWidth = max(0.5, 0.6*k*h);
        sc.qtxt.String = sprintf('Q_{in} = %.1f m^3/s    Q_{out} = %.1f m^3/s', max(q, 0), k*h);
    end
end

function [A, B, C, D, nExtra] = localTf2ss(num, den)
% Controllable canonical realization of C(s). tfdata(...,'v') pads num and
% den with leading zeros to the same length (e.g. Kp + Kd*s gives
% den = [0 1]), so strip them first. An improper C(s), such as an ideal PD,
% cannot be simulated as is: nExtra roll-off poles 1/(s/100+1) are added.
num = num(find(num, 1):end); den = den(find(den, 1):end);
if isempty(num), num = 0; end
nExtra = numel(num) - numel(den);
if nExtra > 0
    for k = 1:nExtra, den = conv(den, [0.01 1]); end
end
num = num(:).'/den(1); den = den(:).'/den(1);
n = numel(den) - 1;
num = [zeros(1, n + 1 - numel(num)) num];
D = num(1);
r = num - D*den;                 % strictly proper remainder
A = [zeros(n - 1, 1) eye(n - 1); -fliplr(den(2:end))];
B = [zeros(n - 1, 1); 1];
C = fliplr(r(2:end));
if n == 0, A = zeros(0); B = zeros(0, 1); C = zeros(1, 0); end
end

function [num, den] = localParseController(str)
% C(s) as typed in the sim. Only numbers, s, + - * / ^ and parentheses are
% accepted (e.g. 10*(s+2)/(s+5)), so the same text also works in a browser
% version of the demo.
str = strtrim(char(str));
rest = regexprep(str, '(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?', '');   % drop the numbers
if isempty(str) || ~isempty(regexp(rest, '[^s\s+\-*/^().]', 'once'))
    error('Type C(s) with numbers, s, + - * / ^ and parentheses only, e.g. 10*(s+2)/(s+5)');
end
s = tf('s'); %#ok<NASGU> used by eval
try
    C = tf(eval(str));
catch
    error('Could not read C(s) = %s. Example: 10*(s+2)/(s+5)', str);
end
[num, den] = tfdata(C, 'v');
end

function str = localTfString(num, den)
% num(s)/den(s) as text, e.g. '1.53 / (0.0248 s^2 + s)'.
num = num(find(num, 1):end); den = den(find(den, 1):end);
if isempty(num), str = '0'; return; end
if numel(den) == 1
    str = localPolyString(num/den);
else
    str = localPolyString(num);
    if nnz(num) > 1, str = ['(' str ')']; end
    d = localPolyString(den);
    if nnz(den) > 1, d = ['(' d ')']; end
    str = [str ' / ' d];
end
end

function str = localPolyString(p)
% Polynomial coefficients (highest power first) as text, e.g. '2 s^2 - s + 0.5'.
n = numel(p) - 1; str = '';
for k = 1:numel(p)
    a = p(k); e = n - k + 1;
    if a == 0, continue; end
    if isempty(str)
        if a < 0, str = '-'; end
    elseif a < 0
        str = [str ' - '];
    else
        str = [str ' + '];
    end
    a = abs(a);
    if a ~= 1 || e == 0
        str = [str sprintf('%.4g', a)];
        if e > 0, str = [str ' ']; end
    end
    if e == 1, str = [str 's']; elseif e > 1, str = sprintf('%ss^%d', str, e); end
end
end
