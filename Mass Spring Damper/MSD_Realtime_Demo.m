function MSD_Realtime_Demo
%MSD_REALTIME_DEMO  Real-time mass-spring-damper: human vs. feedback controller.
%
%   Run MSD_Realtime_Demo and try to move the mass to the green target (it
%   jumps to a new position every few seconds), then hand the job over to the
%   controller designed in MSD_Control_Design / MSD_RootLocus_Design.
%
%   Inputs (HUMAN mode = your input is the force on the mass,
%           CONTROLLER mode = your input is a disturbance force):
%     Joystick/gamepad : left stick X axis. Press any button once so the
%                        browser engine detects it.
%                        Button 1 = switch Human/Controller, Button 2 = reset.
%     Mouse            : hold the left button on the window and move left/right.
%     Keyboard         : Left/Right arrows.
%   Keys: H = human, C = controller, R = reset, Space = pause.
%
%   Uses only core MATLAB (uifigure, uihtml). No Simulink or toolboxes are
%   needed. The joystick is read through the standard browser Gamepad API
%   inside a uihtml component (R2019b or newer).

%% Parameters (edit freely, same values as MSD_Control_Design.m)
m = 1;              % mass [kg]
b = 8.8;            % damping [N s/m]
k = 40;             % stiffness [N/m]
targets = [0.6 -0.4 1 0 -0.8 0.3];  % target positions, visited in order [m]
targetPeriod = 4;   % seconds before the target moves
tol = 0.05;         % "on target" band [m]
uHumanMax = 60;     % force at full stick / full mouse deflection [N]
uCtrlMax  = 300;    % controller saturation [N]
distScale = 0.5;    % your input is scaled by this in CONTROLLER mode (disturbance)

% Controller: write any proper transfer function in s.
% Error e = r - x (target minus position), force u = C(s) e.
% SimpleTF (in this folder) needs no toolbox; s = tf('s') works too.
s = SimpleTF.s;
C = 100*(1 + 3/s);                          % PI from MSD_Control_Design.m
% C = 20*(s+4)*(s+6)/(s*(s/100+1));         % PID from MSD_RootLocus_Design.m
[numC, denC] = tfdata(C, 'v');

%% Plant: m x'' + b x' + k x = u,  G(s) = 1/(m s^2 + b s + k)
plant = @(x, u) [x(2); (u - b*x(2) - k*x(1))/m];

[Ac, Bc, Cc, Dc] = localTf2ss(numC, denC);
nc = size(Ac, 1);

%% State
x = [0; 0];        % [position; velocity]
xc = zeros(nc, 1); % controller states
mode = 'human';    % 'human' or 'controller'
paused = false;
fallen = false;    % (never true here: the mass cannot fall)
tUp = 0;           % time since last reset/mode change
tOn = 0;           % time spent within tol of the target
bestHuman = 0;     % best human "on target" percentage
iTarget = 1; r = targets(1);
keyIn = 0; mouseIn = 0; mouseDown = false;
lastButtons = [];
speed = 1;
dt = 1e-3;         % integration step [s]

%% UI
fig = uifigure('Name', 'Mass Spring Damper: Human vs Controller', ...
    'Position', [100 100 1000 620], 'Color', 'w');
gl = uigridlayout(fig, [1 2]);
gl.ColumnWidth = {'1x', 260};

ax = uiaxes(gl);
axis(ax, 'equal'); hold(ax, 'on');
ax.XLim = [-2.1 1.9]; ax.YLim = [-1.0 1.0];
ax.XTick = -1.5:0.5:1.5; ax.YTick = []; ax.Box = 'on';
ax.Toolbar.Visible = 'off';
disableDefaultInteractivity(ax);
title(ax, '');
xw = -2;            % wall position [m]
wB = 0.4; hB = 0.7; % block size [m]

% Static scene: wall and floor
patch(ax, [-2.1 xw xw -2.1], [-0.25 -0.25 0.75 0.75], [0.6 0.6 0.6], 'EdgeColor', 'none');
plot(ax, [xw 1.9], [-0.25 -0.25], 'Color', [0.4 0.4 0.4], 'LineWidth', 2);
% Target marker
tgt = patch(ax, r + [-1 1 1 -1]*tol, [-0.25 -0.25 0.65 0.65], [0.47 0.67 0.19], ...
    'FaceAlpha', 0.25, 'EdgeColor', [0.47 0.67 0.19]);
% Spring, damper and block (updated every frame)
spring = plot(ax, 0, 0, 'Color', [0.2 0.2 0.2], 'LineWidth', 2);
damper = plot(ax, 0, 0, 'Color', [0.2 0.2 0.2], 'LineWidth', 2);
block = patch(ax, [0 1 1 0], [0 0 1 1], [0.85 0.33 0.1], 'EdgeColor', [0.3 0.3 0.3]);
% Input gauge
plot(ax, [-1 1], [-0.6 -0.6], 'Color', [0.85 0.85 0.85], 'LineWidth', 8);
gauge = plot(ax, [0 0], [-0.6 -0.6], 'LineWidth', 8, 'Color', [0 0.45 0.74]);
text(ax, -1.05, -0.6, 'force', 'HorizontalAlignment', 'right', 'FontSize', 10);
msg = text(ax, 0, 0.88, '', 'HorizontalAlignment', 'center', 'FontSize', 18, ...
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
    ['Mouse: hold left button and move left/right. ' ...
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
u = 0; carry = 0;
tFrame = tic;
while isvalid(fig)
    dWall = min(toc(tFrame), 0.1);   % wall time since last frame (capped)
    tFrame = tic;
    [joyIn, joyOK] = readJoystick();
    human = humanInput(joyIn, joyOK);
    if ~(paused || fallen)
        carry = carry + dWall*speed;  % plant time to simulate
        while carry >= dt && ~fallen
            [x, xc, u] = step(x, xc, human, dt);
            carry = carry - dt;
        end
    else
        carry = 0;
    end
    draw(u, human);
    drawnow limitrate
    pause(0.005);
end

%% Nested functions
    function [x, xc, u] = step(x, xc, human, h)
        % One RK4 step of length h (plant seconds) for plant + controller.
        f = @(x, xc) deriv(x, xc, human);
        [k1, c1] = f(x, xc);
        [k2, c2] = f(x + h/2*k1, xc + h/2*c1);
        [k3, c3] = f(x + h/2*k2, xc + h/2*c2);
        [k4, c4] = f(x + h*k3, xc + h*c3);
        x = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
        xc = xc + h/6*(c1 + 2*c2 + 2*c3 + c4);
        [~, ~, u] = f(x, xc);
        tUp = tUp + h;
        if abs(x(1) - r) < tol, tOn = tOn + h; end
        % move the target every targetPeriod seconds
        if floor(tUp/targetPeriod) ~= floor((tUp - h)/targetPeriod)
            iTarget = mod(iTarget, numel(targets)) + 1;
            r = targets(iTarget);
        end
    end

    function [dx, dxc, u] = deriv(x, xc, human)
        e = r - x(1);
        if strcmp(mode, 'controller')
            uc = Cc*xc + Dc*e;
            uc = max(min(uc, uCtrlMax), -uCtrlMax);
            dxc = Ac*xc + Bc*e;
            u = uc + distScale*human;   % human acts as a disturbance
        else
            dxc = zeros(nc, 1);
            u = human;
        end
        dx = plant(x, u);
    end

    function v = humanInput(joyIn, joyOK)
        src = ddInput.Value;
        switch src
            case 'Joystick', v = joyIn;
            case 'Mouse',    v = mouseIn*mouseDown;
            case 'Keyboard', v = keyIn;
            otherwise % Auto: whichever is active
                if keyIn ~= 0
                    v = keyIn;
                elseif mouseDown
                    v = mouseIn;
                elseif joyOK
                    v = joyIn;
                else
                    v = 0;
                end
        end
        v = uHumanMax*max(min(v, 1), -1);
    end

    function [v, ok] = readJoystick()
        v = 0; ok = false;
        d = hj.Data;
        if ~isstruct(d) || ~isfield(d, 'connected'), return; end
        if d.connected
            ok = true;
            v = double(d.x);
            if abs(v) < 0.08, v = 0; end  % dead zone
            setJoyText(['Joystick: ' char(d.id)]);
            btn = double(d.buttons(:)');
            if numel(lastButtons) == numel(btn)
                pressed = btn & ~lastButtons;
                if numel(pressed) >= 1 && pressed(1)
                    if strcmp(mode, 'human'), setMode('controller'); else, setMode('human'); end
                end
                if numel(pressed) >= 2 && pressed(2), reset(); end
            end
            lastButtons = btn;
        elseif isfield(d, 'error') && ~isempty(d.error)
            setJoyText(['Joystick unavailable: ' char(d.error)]);
        else
            setJoyText('Joystick: none detected (press any button)');
        end
    end

    function draw(u, human)
        p = x(1);
        xl = p - wB/2;                        % left face of the block
        % spring (zigzag) from the wall to the block, upper half
        n = 12; xs = linspace(xw, xl, 2*n + 1);
        ys = 0.3 + 0.08*[0 repmat([1 -1], 1, n-1) 1 0]; ys = ys(1:numel(xs));
        spring.XData = xs; spring.YData = ys;
        % damper (dashpot) from the wall to the block, lower half:
        % a cup attached to the wall and a piston attached to the block
        gap = xl - xw; yd = 0.05; hc = 0.07;
        c0 = xw + 0.15*gap; c1 = xw + 0.6*gap; pp = xw + 0.45*gap;
        damper.XData = [xw c0 NaN c1 c0 c0 c1 NaN pp pp NaN pp xl];
        damper.YData = [yd yd NaN yd+hc yd+hc yd-hc yd-hc NaN yd-0.8*hc yd+0.8*hc NaN yd yd];
        block.XData = xl + [0 wB wB 0];
        block.YData = -0.25 + [0 0 hB hB];
        tgt.XData = r + [-1 1 1 -1]*tol;
        gauge.XData = [0 max(min(u/uHumanMax, 1.6), -1.6)];
        if strcmp(mode, 'controller')
            gauge.Color = [0.47 0.67 0.19];
        else
            gauge.Color = [0 0.45 0.74];
        end
        if paused
            msg.String = 'Paused';
        elseif strcmp(mode, 'controller') && human ~= 0
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
        if strcmp(mode, 'human') && tUp > targetPeriod
            bestHuman = max(bestHuman, 100*tOn/tUp);
        end
        mode = newMode;
        btnHuman.Value = strcmp(newMode, 'human');
        btnCtrl.Value = strcmp(newMode, 'controller');
        xc = zeros(nc, 1);   % start the controller from rest
        tUp = 0; tOn = 0;
        iTarget = 1; r = targets(1);
    end

    function setSpeed(v)
        switch v
            case '0.5x',  speed = 0.5;
            case '0.25x', speed = 0.25;
            otherwise,    speed = 1;
        end
    end

    function reset()
        x = [0; 0];
        xc = zeros(nc, 1);
        tUp = 0; tOn = 0;
        iTarget = 1; r = targets(1);
    end

    function togglePause()
        paused = ~paused;
    end

    function keyPress(~, evt)
        switch evt.Key
            case 'leftarrow',  keyIn = -1;
            case 'rightarrow', keyIn = 1;
            case 'h', setMode('human');
            case 'c', setMode('controller');
            case 'r', reset();
            case 'space', togglePause();
        end
    end

    function keyRelease(~, evt)
        if any(strcmp(evt.Key, {'leftarrow', 'rightarrow'})), keyIn = 0; end
    end

    function mouseButton(down)
        mouseDown = down;
        mouseMove();
    end

    function mouseMove(~, ~)
        p = fig.CurrentPoint; w = fig.Position(3) - 260;  % width of the animation
        if p(1) > w
            mouseIn = 0;   % pointer is over the control panel
        else
            mouseIn = max(min((p(1) - w/2)/(w/2), 1), -1);
        end
    end
end

function [A, B, C, D] = localTf2ss(num, den)
% Controllable canonical realization of a proper transfer function
% (avoids needing the Control System Toolbox).
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

function html = localGamepadHTML()
% Reads the first connected gamepad with the browser Gamepad API and sends
% its state to MATLAB through the uihtml Data property.
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
'    msg={connected:1,id:p.id,x:p.axes.length?Math.round(p.axes[0]*100)/100:0,buttons:b,error:""};}' ...
'   else{msg={connected:0,id:"",x:0,buttons:[],error:""};}' ...
'  }catch(e){msg={connected:0,id:"",x:0,buttons:[],error:String(e)};}' ...
'  var s=JSON.stringify(msg);' ...
'  if(s!==last){last=s;h.Data=msg;}' ...
' }' ...
' setInterval(poll,15);' ...
'}' ...
'</script></body></html>'];
end
