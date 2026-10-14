function BOP_Realtime_Demo
%BOP_REALTIME_DEMO  Real-time ball on plate: human vs. feedback controller.
%
%   Run BOP_Realtime_Demo and try to keep the ball on the green target by
%   tilting the plate yourself (the target jumps every few seconds), then hand
%   it over to the controller designed in BOP_Control_Design.
%
%   Inputs (HUMAN mode = your input sets the servo angles that tilt the plate,
%           CONTROLLER mode = your input is a disturbance):
%     Joystick/gamepad : left stick (X and Y axes). Press any button once so
%                        the browser engine detects it.
%                        Button 1 = switch Human/Controller, Button 2 = reset.
%     Mouse            : hold the left button on the window; the plate tilts
%                        toward the pointer.
%     Keyboard         : arrow keys.
%   Keys: H = human, C = controller, R = reset, Space = pause.
%
%   Uses core MATLAB graphics (uifigure, uihtml) plus tf from the Control
%   System Toolbox. No Simulink is needed. The joystick is read through the
%   standard browser Gamepad API inside a uihtml component (R2019b or newer).
%
%   >>> TO TRY YOUR OWN CONTROLLER, EDIT THE LINE  C = ...  IN THE BOX BELOW <<<

%% ===================== YOUR CONTROLLER: EDIT HERE =====================
s = tf('s');
C = 3*(s+1)/(s/20+1);                 % <-- type your controller C(s) here
%% ======================================================================
% (default: PD with filter from BOP_Control_Design.m)
% The same controller is used for the x and y axes. It sees the error
% e = r - x (target minus ball position, in m) and produces the servo
% angle command theta_ref = C(s) e (in rad).

%% Model (Chapter 1, ball on plate; values from the Quanser ball balancer lab)
c = 1.09;           % ball acceleration per servo angle [m/s^2/rad] (K_bb in the lab)
K = 1.53;           % servo gain [rad/(V s)]
tau = 0.0248;       % servo time constant [s]
Kp1 = 76.5;         % inner servo loop gain: V = Kp1*(theta_ref - theta) [V/rad]
Vmax = 10;          % servo voltage saturation [V]
half = 0.14;        % half side of the plate [m]; the ball falls off beyond it
thMax = 0.5;        % servo angle command limit [rad]
humanMax = 0.3;     % servo angle command at full stick / full mouse [rad]
distScale = 0.3;    % your input is scaled by this in CONTROLLER mode (disturbance)
targets = [0 0; 0.06 0.06; -0.06 0.06; -0.06 -0.06; 0.06 -0.06];   % [m]
targetPeriod = 4;   % seconds before the target moves
tol = 0.015;        % "on target" radius [m]
% Each axis: x'' = c sin(theta),  tau theta'' + theta' = K V
% (linearized: X(s)/Theta(s) = c/s^2, Theta(s)/V(s) = K/(s(tau s + 1)))

srcFile = [mfilename('fullpath') '.m'];   % Reset re-reads C from this file
Ac = []; Bc = []; Cc = []; Dc = 0; nc = 0;
setController(C);

%% State: per axis [position; velocity; servo angle; servo speed]
X = zeros(4, 2);    % columns: x axis, y axis
XC = zeros(nc, 2);  % controller states, one column per axis
mode = 'human';
paused = false; fallen = false;
tUp = 0; tOn = 0; bestHuman = 0;
iTarget = 1; r = targets(1, :);
keyX = 0; keyY = 0; mouseIn = [0 0]; mouseDown = false;
lastButtons = [];
speed = 1; dt = 1e-3;
thRef = [0 0];

%% UI
fig = uifigure('Name', 'Ball on Plate: Human vs Controller', ...
    'Position', [100 100 1000 650], 'Color', 'w');
gl = uigridlayout(fig, [1 2]);
gl.ColumnWidth = {'1x', 260};

ax = uiaxes(gl);
axis(ax, 'equal'); hold(ax, 'on');
ax.XLim = [-1 1]*0.2; ax.YLim = [-1 1]*0.2;
ax.XTick = []; ax.YTick = []; ax.Box = 'on';
ax.Toolbar.Visible = 'off';
disableDefaultInteractivity(ax);
plate = patch(ax, half*[-1 1 1 -1], half*[-1 -1 1 1], [0.95 0.95 0.95], ...
    'EdgeColor', [0.3 0.3 0.3], 'LineWidth', 2);
plot(ax, [-half half], [0 0], ':', 'Color', [0.7 0.7 0.7]);
plot(ax, [0 0], [-half half], ':', 'Color', [0.7 0.7 0.7]);
th = linspace(0, 2*pi, 40);
tgt = patch(ax, tol*cos(th), tol*sin(th), [0.47 0.67 0.19], 'FaceAlpha', 0.3, ...
    'EdgeColor', [0.47 0.67 0.19], 'LineWidth', 2);
tilt = plot(ax, [0 0], [0 0], 'Color', [0 0.45 0.74], 'LineWidth', 4);   % "downhill" arrow
ball = patch(ax, 0.012*cos(th), 0.012*sin(th), [0.95 0.5 0.1], 'EdgeColor', [0.5 0.25 0]);
text(ax, 0, -0.175, 'blue line = plate tilt (downhill)', 'HorizontalAlignment', 'center', ...
    'FontSize', 9, 'Color', [0.4 0.4 0.4]);
msg = text(ax, 0, 0.17, '', 'HorizontalAlignment', 'center', 'FontSize', 18, ...
    'FontWeight', 'bold', 'Color', [0.8 0 0]);

% Control panel
pn = uigridlayout(gl, [14 1]);
pn.RowHeight = [repmat({'fit'}, 1, 13) {20}];
uilabel(pn, 'Text', 'Who is in control?', 'FontWeight', 'bold');
btnHuman = uibutton(pn, 'state', 'Text', 'Human  (H)', 'Value', true, ...
    'ValueChangedFcn', @(~,~) setMode('human'));
btnCtrl = uibutton(pn, 'state', 'Text', 'Controller  (C)', ...
    'ValueChangedFcn', @(~,~) setMode('controller'));
uilabel(pn, 'Text', 'Input device', 'FontWeight', 'bold');
ddInput = uidropdown(pn, 'Items', {'Auto', 'Joystick', 'Mouse', 'Keyboard'});
uilabel(pn, 'Text', 'Speed', 'FontWeight', 'bold');
uidropdown(pn, 'Items', {'1x (real time)', '0.5x', '0.25x'}, ...
    'ValueChangedFcn', @(src,~) setSpeed(src.Value));
uibutton(pn, 'Text', 'Reset  (R)', 'ButtonPushedFcn', @(~,~) reset());
uibutton(pn, 'Text', 'Pause  (Space)', 'ButtonPushedFcn', @(~,~) togglePause());
lblTime = uilabel(pn, 'Text', 'On target: 0%', 'FontSize', 14);
lblBest = uilabel(pn, 'Text', 'Best human: 0%', 'FontSize', 14);
lblJoy = uilabel(pn, 'Text', 'Joystick: press any button', 'WordWrap', 'on');
lblHelp = uilabel(pn, 'WordWrap', 'on', 'FontColor', [0.4 0.4 0.4], 'Text', ...
    ['Mouse: hold left button; the plate tilts toward the pointer. ' ...
     'Keyboard: arrows. In Controller mode your input is a disturbance.']);
lblHelp.Layout.Row = 13;

% Joystick reader (hidden web component using the Gamepad API)
hj = uihtml(pn, 'HTMLSource', localGamepadHTML());
hj.Layout.Row = 14;

fig.WindowKeyPressFcn = @keyPress;
fig.WindowKeyReleaseFcn = @keyRelease;
fig.WindowButtonDownFcn = @(~,~) mouseButton(true);
fig.WindowButtonUpFcn = @(~,~) mouseButton(false);
fig.WindowButtonMotionFcn = @mouseMove;

%% Real-time loop
reset();
carry = 0;
tFrame = tic;
frameTime = 1/30;                     % redraw at ~30 fps
while isvalid(fig)
    dWall = min(toc(tFrame), 0.05);  % wall time since last frame (capped)
    tFrame = tic;
    [joy, joyOK] = readJoystick();
    human = humanInput(joy, joyOK);
    if ~(paused || fallen)
        carry = carry + dWall*speed;  % plant time to simulate
        while carry >= dt && ~fallen
            step(human, dt);
            carry = carry - dt;
        end
    else
        carry = 0;
    end
    draw(human);
    drawnow                           % wait until the frame is rendered, so
                                      % button presses do not queue up behind it
    pause(max(0.001, frameTime - toc(tFrame)));   % idle rest of frame, run callbacks
end

%% Nested functions
    function step(human, h)
        % One RK4 step of length h (plant seconds), each axis separately.
        for ax2 = 1:2
            f = @(z, zc) deriv(z, zc, human(ax2), ax2);
            z = X(:, ax2); zc = XC(:, ax2);
            [k1, c1] = f(z, zc);
            [k2, c2] = f(z + h/2*k1, zc + h/2*c1);
            [k3, c3] = f(z + h/2*k2, zc + h/2*c2);
            [k4, c4] = f(z + h*k3, zc + h*c3);
            X(:, ax2) = z + h/6*(k1 + 2*k2 + 2*k3 + k4);
            XC(:, ax2) = zc + h/6*(c1 + 2*c2 + 2*c3 + c4);
        end
        tUp = tUp + h;
        if norm(X(1, :) - r) < tol, tOn = tOn + h; end
        if floor(tUp/targetPeriod) ~= floor((tUp - h)/targetPeriod)
            iTarget = mod(iTarget, size(targets, 1)) + 1;
            r = targets(iTarget, :);
        end
        if any(abs(X(1, :)) > half)
            fallen = true;
            if strcmp(mode, 'human'), bestHuman = max(bestHuman, 100*tOn/tUp); end
        end
    end

    function [dz, dzc, ref] = deriv(z, zc, hum, ax2)
        e = r(ax2) - z(1);
        if strcmp(mode, 'controller')
            ref = Cc*zc + Dc*e + distScale*hum;   % human acts as a disturbance
            dzc = Ac*zc + Bc*e;
        else
            ref = hum;
            dzc = zeros(nc, 1);
        end
        ref = max(min(ref, thMax), -thMax);
        thRef(ax2) = ref;
        V = max(min(Kp1*(ref - z(3)), Vmax), -Vmax);    % inner servo loop
        dz = [z(2); c*sin(z(3)); z(4); (K*V - z(4))/tau];
    end

    function v = humanInput(joy, joyOK)
        switch ddInput.Value
            case 'Joystick', v = joy;
            case 'Mouse',    v = mouseIn*mouseDown;
            case 'Keyboard', v = [keyX keyY];
            otherwise % Auto: whichever is active
                if keyX ~= 0 || keyY ~= 0
                    v = [keyX keyY];
                elseif mouseDown
                    v = mouseIn;
                elseif joyOK
                    v = joy;
                else
                    v = [0 0];
                end
        end
        v = humanMax*max(min(v, 1), -1);
    end

    function [v, ok] = readJoystick()
        v = [0 0]; ok = false;
        dj = hj.Data;
        if ~isstruct(dj) || ~isfield(dj, 'connected'), return; end
        if dj.connected
            ok = true;
            v = [double(dj.x) -double(dj.y)];   % stick up = +y
            v(abs(v) < 0.08) = 0;               % dead zone
            setJoyText(['Joystick: ' char(dj.id)]);
            btn = double(dj.buttons(:)');
            if numel(lastButtons) == numel(btn)
                pressed = btn & ~lastButtons;
                if numel(pressed) >= 1 && pressed(1)
                    if strcmp(mode, 'human'), setMode('controller'); else, setMode('human'); end
                end
                if numel(pressed) >= 2 && pressed(2), reset(); end
            end
            lastButtons = btn;
        elseif isfield(dj, 'error') && ~isempty(dj.error)
            setJoyText(['Joystick unavailable: ' char(dj.error)]);
        else
            setJoyText('Joystick: none detected (press any button)');
        end
    end

    function draw(human)
        p = X(1, :);
        ball.XData = p(1) + 0.012*cos(th); ball.YData = p(2) + 0.012*sin(th);
        tgt.XData = r(1) + tol*cos(th); tgt.YData = r(2) + tol*sin(th);
        a = X(3, :);                     % servo angles (positive = ball accelerates +x/+y)
        tilt.XData = [0 0.25*a(1)]; tilt.YData = [0 0.25*a(2)];
        if strcmp(mode, 'controller')
            tilt.Color = [0.47 0.67 0.19];
        else
            tilt.Color = [0 0.45 0.74];
        end
        if fallen
            msg.String = 'Fell off!  Press R';
        elseif paused
            msg.String = 'Paused';
        elseif strcmp(mode, 'controller') && any(human ~= 0)
            msg.String = 'Disturbance!';
        else
            msg.String = '';
        end
        lblTime.Text = sprintf('On target: %.0f%%', 100*tOn/max(tUp, eps));
        lblBest.Text = sprintf('Best human: %.0f%%', bestHuman);
    end

    function setJoyText(t)
        if ~strcmp(lblJoy.Text, t), lblJoy.Text = t; end
    end

    function setMode(newMode)
        if strcmp(mode, 'human') && ~fallen && tUp > 0
            bestHuman = max(bestHuman, 100*tOn/tUp);
        end
        mode = newMode;
        btnHuman.Value = strcmp(newMode, 'human');
        btnCtrl.Value = strcmp(newMode, 'controller');
        XC = zeros(nc, 2);   % start the controller from rest
        tUp = 0; tOn = 0;
        iTarget = 1; r = targets(1, :);
    end

    function setSpeed(v)
        switch v
            case '0.5x',  speed = 0.5;
            case '0.25x', speed = 0.25;
            otherwise,    speed = 1;
        end
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
        X = zeros(4, 2); X(1, :) = [0.03 -0.02];
        XC = zeros(nc, 2);
        fallen = false;
        tUp = 0; tOn = 0;
        iTarget = 1; r = targets(1, :);
    end

    function togglePause()
        paused = ~paused;
    end

    function keyPress(~, evt)
        switch evt.Key
            case 'leftarrow',  keyX = -1;
            case 'rightarrow', keyX = 1;
            case 'uparrow',    keyY = 1;
            case 'downarrow',  keyY = -1;
            case 'h', setMode('human');
            case 'c', setMode('controller');
            case 'r', reset();
            case 'space', togglePause();
        end
    end

    function keyRelease(~, evt)
        if any(strcmp(evt.Key, {'leftarrow', 'rightarrow'})), keyX = 0; end
        if any(strcmp(evt.Key, {'uparrow', 'downarrow'})), keyY = 0; end
    end

    function mouseButton(down)
        mouseDown = down;
        mouseMove();
    end

    function mouseMove(~, ~)
        q = fig.CurrentPoint; w = fig.Position(3) - 260; hgt = fig.Position(4);
        if q(1) > w
            mouseIn = [0 0];   % pointer is over the control panel
        else
            mouseIn = max(min([(q(1) - w/2)/(w/2), (q(2) - hgt/2)/(hgt/2)]*1.5, 1), -1);
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
% Controllable canonical realization of C(s). tfdata(...,'v') pads num and
% den with leading zeros to the same length (e.g. Kp + Kd*s gives
% den = [0 1]), so strip them first. An improper C(s), such as an ideal PD,
% cannot be simulated as is: roll-off poles 1/(s/100+1) are added.
num = num(find(num, 1):end); den = den(find(den, 1):end);
if isempty(num), num = 0; end
nExtra = numel(num) - numel(den);
if nExtra > 0
    warning('C(s) is improper: simulating C(s)/(s/100+1)^%d instead.', nExtra);
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

function html = localGamepadHTML()
% Reads the first connected gamepad with the browser Gamepad API and sends
% its state (both axes of the left stick) to MATLAB through uihtml Data.
html = [ ...
'<html><body style="margin:0;font:11px sans-serif;color:#888">' ...
'<script>' ...
'function setup(h){' ...
' var last="";' ...
' function poll(){' ...
'  var msg;' ...
'  try{' ...
'   var pads=navigator.getGamepads?navigator.getGamepads():[];var p=null;' ...
'   for(var i=0;i<pads.length;i++){if(pads[i]&&pads[i].connected){p=pads[i];break;}}' ...
'   if(p){var b=[];for(var j=0;j<p.buttons.length;j++){b.push(p.buttons[j].pressed?1:0);}' ...
'    var ax0=p.axes.length>0?Math.round(p.axes[0]*100)/100:0;' ...
'    var ax1=p.axes.length>1?Math.round(p.axes[1]*100)/100:0;' ...
'    msg={connected:1,id:p.id,x:ax0,y:ax1,buttons:b,error:""};}' ...
'   else{msg={connected:0,id:"",x:0,y:0,buttons:[],error:""};}' ...
'  }catch(e){msg={connected:0,id:"",x:0,y:0,buttons:[],error:String(e)};}' ...
'  var s=JSON.stringify(msg);' ...
'  if(s!==last){last=s;h.Data=msg;}' ...
' }' ...
' setInterval(poll,15);' ...
'}' ...
'</script></body></html>'];
end
