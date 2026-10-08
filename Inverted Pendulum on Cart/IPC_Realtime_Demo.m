function IPC_Realtime_Demo
%IPC_REALTIME_DEMO  Real-time inverted pendulum on a cart: human vs. controller.
%
%   Run IPC_Realtime_Demo and try to keep the pendulum upright by pushing the
%   cart yourself, then hand it over to the controller designed in
%   IPC_Control_Design. The view follows the cart.
%
%   Inputs (HUMAN mode = your input is the force on the cart,
%           CONTROLLER mode = your input is a disturbance force):
%     Joystick/gamepad : left stick X axis. Press any button once so the
%                        browser engine detects it.
%                        Button 1 = switch Human/Controller, Button 2 = reset.
%     Mouse            : hold the left button on the window and move left/right.
%     Keyboard         : Left/Right arrows.
%   Keys: H = human, C = controller, R = reset, Space = pause.
%
%   Uses core MATLAB graphics (uifigure, uihtml, hgtransform) plus tf from
%   the Control System Toolbox. No Simulink is needed. The joystick is read
%   through the standard browser Gamepad API inside a uihtml component (R2019b or newer).

%% Parameters (edit freely, same values as IPC_Control_Design.m / Exercise 4.4)
M = 0.5;            % cart mass [kg]
m = 0.5;            % pendulum mass [kg]
l = 0.3;            % pivot to pendulum center of mass [m]
I = 0.006;          % pendulum inertia [kg m^2]
mu = 0.1;           % cart friction [N s/m]
g = 9.81;           % gravity [m/s^2]
theta0 = 2*pi/180;  % initial tilt after a reset [rad]
fallAngle = 80*pi/180;  % beyond this the pendulum counts as fallen [rad]
uHumanMax = 10;     % force at full stick / full mouse deflection [N]
uCtrlMax  = 30;     % controller saturation [N]
distScale = 0.3;    % your input is scaled by this in CONTROLLER mode (disturbance)

% Controller: write any proper transfer function in s.
% Error e = 0 - theta, force on the cart u = C(s) e.
s = tf('s');
C = -10*(6 + s + 8/s)/(s/100+1);   % PID from IPC_Control_Design.m
[numC, denC] = tfdata(C, 'v');

%% Plant, state x = [theta; theta'; cart position; cart velocity]
% theta is measured from the upward vertical, positive to the right:
%   (M+m) y'' + m l cos(theta) theta'' - m l sin(theta) theta'^2 + mu y' = u
%   (I+m l^2) theta'' + m l cos(theta) y'' - m g l sin(theta) = 0
% (linearization: G(s) as in IPC_Control_Design.m)
plant = @(x, u) cartPendulum(x, u, M, m, l, I, mu, g);

[Ac, Bc, Cc, Dc] = localTf2ss(numC, denC);
nc = size(Ac, 1);

%% State
x = [theta0; 0; 0; 0];   % [theta; theta_dot; y; y_dot]
xc = zeros(nc, 1); % controller states
mode = 'human';    % 'human' or 'controller'
paused = false;
fallen = false;
tUp = 0;           % time upright since last reset/mode change
bestHuman = 0;
keyIn = 0; mouseIn = 0; mouseDown = false;
lastButtons = [];
speed = 1;
dt = 1e-3;         % integration step [s]

%% UI
fig = uifigure('Name', 'Inverted Pendulum on a Cart: Human vs Controller', ...
    'Position', [100 100 1000 620], 'Color', 'w');
gl = uigridlayout(fig, [1 2]);
gl.ColumnWidth = {'1x', 260};

Lr = 2*l;          % drawn rod length [m] (center of mass at l)
W = 1.1;           % half width of the view [m]; the view follows the cart
wc = 0.3; hc = 0.12; rw = 0.03;   % cart width, height, wheel radius [m]
ax = uiaxes(gl);
axis(ax, 'equal'); hold(ax, 'on');
ax.XLim = [-W W]; ax.YLim = [-0.42 0.9];
ax.XTick = []; ax.YTick = []; ax.Box = 'on';
ax.Toolbar.Visible = 'off';
disableDefaultInteractivity(ax);
title(ax, '');

% Track with distance marks every 0.25 m (redrawn as the view moves)
track = plot(ax, [-W W], [0 0], 'Color', [0.4 0.4 0.4], 'LineWidth', 2);
ticks = plot(ax, NaN, NaN, 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
tickLbl = text(ax, 0, -0.1, '', 'HorizontalAlignment', 'center', ...
    'FontSize', 9, 'Color', [0.5 0.5 0.5]);
% Input gauge (moves with the view)
gaugeBg = plot(ax, [-1 1]*0.6, [-0.3 -0.3], 'Color', [0.85 0.85 0.85], 'LineWidth', 8);
gauge = plot(ax, [0 0], [-0.3 -0.3], 'LineWidth', 8, 'Color', [0 0.45 0.74]);
gaugeLbl = text(ax, -0.65, -0.3, 'force', 'HorizontalAlignment', 'right', 'FontSize', 10);
% Cart (moved by an hgtransform) with the pendulum on top (rotated)
trCart = hgtransform('Parent', ax);
th = linspace(0, 2*pi, 30);
patch('Parent', trCart, 'XData', [-1 1 1 -1]*wc/2, 'YData', [0 0 1 1]*hc + 2*rw, ...
    'FaceColor', [0.3 0.45 0.7], 'EdgeColor', [0.2 0.2 0.2]);
for xw = [-1 1]*wc/3
    patch('Parent', trCart, 'XData', xw + rw*cos(th), 'YData', rw + rw*sin(th), ...
        'FaceColor', [0.2 0.2 0.2], 'EdgeColor', 'none');
end
yp = 2*rw + hc;    % pivot height
trPend = hgtransform('Parent', trCart);
line('Parent', trPend, 'XData', [0 0], 'YData', [0 Lr], 'LineWidth', 6, 'Color', [0.2 0.2 0.2]);
patch('Parent', trPend, 'XData', 0.03*cos(th), 'YData', Lr + 0.03*sin(th), ...
    'FaceColor', [0.85 0.33 0.1], 'EdgeColor', 'none');
patch('Parent', trCart, 'XData', 0.015*cos(th), 'YData', yp + 0.015*sin(th), ...
    'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none');
msg = text(ax, 0, 0.82, '', 'HorizontalAlignment', 'center', 'FontSize', 18, ...
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
lblTime = uilabel(pn, 'Text', 'Time upright: 0.0 s', 'FontSize', 14);
lblBest = uilabel(pn, 'Text', 'Best human: 0.0 s', 'FontSize', 14);
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
        if abs(x(1)) > fallAngle
            fallen = true;
            if strcmp(mode, 'human'), bestHuman = max(bestHuman, tUp); end
        end
    end

    function [dx, dxc, u] = deriv(x, xc, human)
        e = -x(1);
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
        yc = x(3);
        if ~isfinite(yc), yc = 0; end
        % Move the view with the cart
        ax.XLim = yc + [-W W];
        track.XData = yc + [-W W];
        k = ceil((yc - W)/0.25):floor((yc + W)/0.25);
        tx = [k; k; nan(size(k))]*0.25;
        ty = repmat([0; -0.04; NaN], 1, numel(k));
        ticks.XData = tx(:); ticks.YData = ty(:);
        km = round(yc);   % label the nearest whole meter
        tickLbl.Position = [km -0.09 0];
        tickLbl.String = sprintf('%d m', km);
        trCart.Matrix = makehgtform('translate', [yc 0 0]);
        trPend.Matrix = makehgtform('translate', [0 yp 0]) * makehgtform('zrotate', -x(1));
        gaugeBg.XData = yc + [-1 1]*0.6;
        gaugeLbl.Position = [yc - 0.65 -0.3 0];
        msg.Position = [yc 0.82 0];
        gauge.XData = yc + [0 max(min(u/uHumanMax, 1.6), -1.6)]*0.6;
        if strcmp(mode, 'controller')
            gauge.Color = [0.47 0.67 0.19];
        else
            gauge.Color = [0 0.45 0.74];
        end
        if fallen
            if strcmp(mode, 'human')
                msg.String = sprintf('Fell after %.1f s!  Press R', tUp);
            else
                msg.String = 'Fell!  Press R';
            end
        elseif paused
            msg.String = 'Paused';
        elseif strcmp(mode, 'controller') && human ~= 0
            msg.String = 'Disturbance!';
        else
            msg.String = '';
        end
        lblTime.Text = sprintf('Time upright: %.1f s', tUp);
        lblBest.Text = sprintf('Best human: %.1f s', bestHuman);
    end

    function setJoyText(t)
        if ~strcmp(lblJoy.Text, t), lblJoy.Text = t; end
    end

    function setMode(m)
        if strcmp(mode, 'human') && ~fallen, bestHuman = max(bestHuman, tUp); end
        mode = m;
        btnHuman.Value = strcmp(m, 'human');
        btnCtrl.Value = strcmp(m, 'controller');
        xc = zeros(nc, 1);   % start the controller from rest
        tUp = 0;
    end

    function setSpeed(v)
        switch v
            case '0.5x',  speed = 0.5;
            case '0.25x', speed = 0.25;
            otherwise,    speed = 1;
        end
    end

    function reset()
        x = [theta0; 0; 0; 0];
        xc = zeros(nc, 1);
        fallen = false;
        tUp = 0;
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

function dx = cartPendulum(x, u, M, m, l, I, mu, g)
% Nonlinear cart-pendulum dynamics, x = [theta; theta'; y; y'].
c = cos(x(1)); sn = sin(x(1));
Mm = [M+m, m*l*c; m*l*c, I+m*l^2];
rhs = [u - mu*x(4) + m*l*sn*x(2)^2; m*g*l*sn];
a = Mm \ rhs;    % [y''; theta'']
dx = [x(2); a(2); x(4); a(1)];
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
