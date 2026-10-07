function HA_Realtime_Demo
%HA_REALTIME_DEMO  Real-time highwire artist: human vs. feedback controller.
%
%   Run HA_Realtime_Demo and try to keep the artist on the wire yourself by
%   rotating the balancing pole, then hand it over to the controller designed
%   in HA_Control_Design.
%
%   Inputs (HUMAN mode = your input is the torque on the pole,
%           CONTROLLER mode = your input is a disturbance):
%     Joystick/gamepad : left stick X axis. Press any button once so the
%                        browser engine detects it.
%                        Button 1 = switch Human/Controller, Button 2 = reset.
%     Mouse            : hold the left button on the window and move left/right.
%     Keyboard         : Left/Right arrows.
%   Keys: H = human, C = controller, R = reset, Space = pause.
%
%   Uses only core MATLAB (uifigure, uihtml, hgtransform). No Simulink or
%   toolboxes are needed. The joystick is read through the standard browser
%   Gamepad API inside a uihtml component (R2019b or newer).

%% Parameters (edit freely, same values as HA_Control_Design.m)
J = 10.4;           % pole inertia [kg m^2]
l = 1.5;            % pole parameter [m]
L = 2;              % artist center of mass height [m]
m = 5;              % pole mass [kg]
M = 75;             % artist mass [kg]
g = 9.81;           % gravity [m/s^2]
theta0 = pi/1000;   % initial tilt after a reset [rad] (as in HA_sim.slx)
fallAngle = 45*pi/180;  % beyond this the artist falls off the wire [rad]
uHumanMax = 600;    % torque at full stick / full mouse deflection [N m]
uCtrlMax  = 3000;   % controller saturation [N m]
distScale = 0.3;    % your input is scaled by this in CONTROLLER mode (disturbance)

% Controller from HA_Control_Design.m:
%   C = 3000*(s+2)/(s+5),  [numC, denC] = tfdata(C, 'v')
numC = [3000 6000];
denC = [1 5];
% Error e = 0 - theta, pole torque u = C(s) e.

%% Plant (same equations as the HA_sim.slx subsystem), state x = [theta; theta'; psi; psi']
%   theta: artist tilt from vertical, psi: pole angle, u: torque on the pole
% (linearization: G(s) = 6/(6*m*l^2+2*M*L^2)/(s^2-3*g*(2*m*l+M*L)/(6*m*l^2+2*M*L^2)))
Dth = 6*m*l^2 + 2*M*L^2;
kg = 3*g*(2*m*l + M*L);
Dpsi = 2*J*(3*m*l^2 + M*L^2);
kpsi = 2*(3*J + 3*m*l^2 + M*L^2);
plant = @(x, u) [x(2); (kg*sin(x(1)) + 6*u)/Dth; x(4); (-kg*sin(x(1)) - kpsi*u)/Dpsi];

[Ac, Bc, Cc, Dc] = localTf2ss(numC, denC);
nc = size(Ac, 1);

%% State
x = [theta0; 0; 0; 0];   % [theta; theta_dot; psi; psi_dot]
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
fig = uifigure('Name', 'Highwire Artist: Human vs Controller', ...
    'Position', [100 100 1000 620], 'Color', 'w');
gl = uigridlayout(fig, [1 2]);
gl.ColumnWidth = {'1x', 260};

ax = uiaxes(gl);
axis(ax, 'equal'); hold(ax, 'on');
H = 2*L;            % drawn artist height [m]
hp = 2.5;           % height of the hands (pole center) [m]
ax.XLim = [-5 5]; ax.YLim = [-2.3 6];
ax.XTick = []; ax.YTick = []; ax.Box = 'on';
ax.Toolbar.Visible = 'off';
disableDefaultInteractivity(ax);
title(ax, '');

% Static scene: wire between two posts
plot(ax, [-5 5], [0 0], 'Color', [0.3 0.3 0.3], 'LineWidth', 1.5);
patch(ax, [-4.9 -4.6 -4.6 -4.9], [-2.3 -2.3 0.3 0.3], [0.6 0.45 0.3], 'EdgeColor', 'none');
patch(ax, [4.6 4.9 4.9 4.6], [-2.3 -2.3 0.3 0.3], [0.6 0.45 0.3], 'EdgeColor', 'none');
% Input gauge
plot(ax, [-3 3], [-1.6 -1.6], 'Color', [0.85 0.85 0.85], 'LineWidth', 8);
gauge = plot(ax, [0 0], [-1.6 -1.6], 'LineWidth', 8, 'Color', [0 0.45 0.74]);
text(ax, -3.2, -1.6, 'torque', 'HorizontalAlignment', 'right', 'FontSize', 10);
% Artist (drawn upright, rotated about the feet by theta)
tr = hgtransform('Parent', ax);
line('Parent', tr, 'XData', [-0.08 0 0.08], 'YData', [0 0.45*H 0], 'LineWidth', 4, 'Color', [0.2 0.2 0.2]);
line('Parent', tr, 'XData', [0 0], 'YData', [0.45*H 0.85*H], 'LineWidth', 6, 'Color', [0.85 0.33 0.1]);
line('Parent', tr, 'XData', [-0.45 0 0.45], 'YData', [hp 0.8*H hp], 'LineWidth', 3, 'Color', [0.2 0.2 0.2]);
th = linspace(0, 2*pi, 40);
patch('Parent', tr, 'XData', 0.25*cos(th), 'YData', 0.94*H + 0.25*sin(th), ...
    'FaceColor', [0.95 0.8 0.65], 'EdgeColor', [0.2 0.2 0.2]);
% Pole (absolute angle psi, centered at the hands)
trPole = hgtransform('Parent', ax);
line('Parent', trPole, 'XData', [-3 3], 'YData', [0 0], 'LineWidth', 4, 'Color', [0.4 0.25 0.1]);
patch('Parent', trPole, 'XData', [-3.2 -2.8 -2.8 -3.2], 'YData', [-0.15 -0.15 0.15 0.15], ...
    'FaceColor', [0.3 0.3 0.3], 'EdgeColor', 'none');
patch('Parent', trPole, 'XData', [2.8 3.2 3.2 2.8], 'YData', [-0.15 -0.15 0.15 0.15], ...
    'FaceColor', [0.3 0.3 0.3], 'EdgeColor', 'none');
msg = text(ax, 0, 5.6, '', 'HorizontalAlignment', 'center', 'FontSize', 18, ...
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
    'ValueChangedFcn', @(s,~) setSpeed(s.Value));
uibutton(pn, 'Text', 'Reset  (R)', 'ButtonPushedFcn', @(~,~) reset());
uibutton(pn, 'Text', 'Pause  (Space)', 'ButtonPushedFcn', @(~,~) togglePause());
lblTime = uilabel(pn, 'Text', 'Time on the wire: 0.0 s', 'FontSize', 14);
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
        tr.Matrix = makehgtform('zrotate', -x(1));
        trPole.Matrix = makehgtform('translate', [hp*sin(x(1)) hp*cos(x(1)) 0], 'zrotate', x(3));
        gauge.XData = [0 3*max(min(u/uHumanMax, 1.6), -1.6)];
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
        lblTime.Text = sprintf('Time on the wire: %.1f s', tUp);
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

    function setSpeed(s)
        switch s
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

function [A, B, C, D] = localTf2ss(num, den)
% Controllable canonical realization of a proper transfer function
% (avoids needing the Control System Toolbox).
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
