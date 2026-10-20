function FR_Servo_Demo
%FR_SERVO_DEMO  Frequency response of a DC-motor speed servo (first order, low-pass).
%
%   Run FR_Servo_Demo. The armature voltage is a sinusoid v(t) = A sin(w t)
%   and the output is the shaft speed w_m(t). With the electrical dynamics
%   neglected, the motor is the first-order system
%       G(s) = W_m(s)/V(s) = K/(tau s + 1)
%   with DC gain K [rad/s per V] and mechanical time constant tau [s].
%   Move the input frequency and watch the speed (blue) follow the voltage
%   (gray): at low frequency it is amplified (x K) and in phase; above the
%   corner 1/tau it gets smaller and smaller and lags by up to 90 degrees.
%   The disk shows the shaft angle, the bars show voltage and speed.
%
%   Keys: Space = pause, R = reset, Up/Down = change the input frequency.

%% ===================== SETTINGS: EDIT HERE =====================
K    = 5;       % DC gain of the motor [rad/s per V]
tau0 = 0.2;     % mechanical time constant [s]
w0   = 1;       % initial input frequency [rad/s]
A0   = 1;       % input amplitude [V]
%% ===============================================================
figName = 'Frequency Response: DC motor speed servo (first order, low-pass)';
wRange = [0.1 300]; wTicks = [0.1 1 10 100];
ARange = [0.2 2]; p0 = tau0; pRange = [0.05 1];
uSym = '$v(t)$'; ySym = '$\omega_m(t)$'; uUnit = '(V)'; yUnit = '(rad/s)';
uUnitPlain = '(V)'; uText = 'voltage v(t)'; cornerSym = '1/τ';
helpText = ['Low frequencies: speed = K·voltage (amplified, in phase). ' ...
            'High frequencies: the rotor inertia cannot follow (attenuated, lag -> -90°).'];

%% ======================= Engine (no need to edit below) =======================
M = makeModel(p0);
w = w0; Amp = A0; p = p0; speed = 1; paused = false;
x = zeros(M.n, 1); t = 0; ph = 0; u = 0; y = 0;
tChange = 0;                         % time of the last change (for "steady")
h = 1e-3; Ad = []; Bd = [];
nH = 6000; tH = nan(nH, 1); uH = tH; yH = tH; kH = 0; dec = 1; cnt = 0;
blue = [31 95 168]/255; red = [192 57 43]/255; gray = [0.55 0.55 0.55]; green = [46 139 87]/255;

fig = uifigure('Name', figName, 'Position', [60 60 1250 720], 'Color', 'w', ...
               'WindowKeyPressFcn', @keyPress);
gl = uigridlayout(fig, [2 3]); gl.ColumnWidth = {'1.15x', '1x', 300}; gl.RowHeight = {'1x', '1x'};
axA = uiaxes(gl); axA.Layout.Row = 1; axA.Layout.Column = 1;
axT = uiaxes(gl); axT.Layout.Row = 2; axT.Layout.Column = 1;
axM = uiaxes(gl); axM.Layout.Row = 1; axM.Layout.Column = 2;
axP = uiaxes(gl); axP.Layout.Row = 2; axP.Layout.Column = 2;
for ax = [axA axT axM axP]
    hold(ax, 'on'); ax.Toolbar.Visible = 'off'; disableDefaultInteractivity(ax);
    ax.TickLabelInterpreter = 'latex'; ax.FontSize = 12;
end
% animation
axis(axA, 'equal'); axA.XTick = []; axA.YTick = []; axA.Box = 'on';
sc = struct(); setupScene();
% time plot
grid(axT, 'on'); box(axT, 'on');
hU = plot(axT, NaN, NaN, 'Color', gray, 'LineWidth', 1.5);
hY = plot(axT, NaN, NaN, 'Color', blue, 'LineWidth', 2);
hShift = plot(axT, NaN, NaN, 'Color', red, 'LineWidth', 1.2);
hShiftTxt = text(axT, NaN, NaN, '', 'Interpreter', 'latex', 'Color', red, 'FontSize', 13, ...
                 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
xlabel(axT, 'time $t$ (s)', 'Interpreter', 'latex');
ylabel(axT, ['input ' uSym ',\ output ' ySym], 'Interpreter', 'latex');
legend(axT, [hU hY], {['input ' uSym ' ' uUnit], ['output ' ySym ' ' yUnit]}, ...
       'Interpreter', 'latex', 'Location', 'northwest', 'AutoUpdate', 'off');
% Bode plot
wB = logspace(log10(wRange(1)), log10(wRange(2)), 600);
for ax = [axM axP]
    set(ax, 'XScale', 'log', 'XLim', wRange, 'XMinorGrid', 'on'); grid(ax, 'on'); box(ax, 'on');
end
hMag = plot(axM, wB, wB, 'Color', blue, 'LineWidth', 2.5);
yline(axM, 0, '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 1);
hCornM = xline(axM, 1, '--', 'Color', gray, 'LineWidth', 1.2);
hDotM = plot(axM, 1, 0, 'o', 'MarkerSize', 10, 'MarkerFaceColor', red, 'MarkerEdgeColor', 'w');
hAmpTxt = text(axM, wRange(1)*1.3, 1, '', 'Interpreter', 'latex', 'FontSize', 12, 'Color', [0.3 0.3 0.3]);
ylabel(axM, '$|G(j\omega)|$ (dB)', 'Interpreter', 'latex');
hTitle = title(axM, '', 'Interpreter', 'latex', 'FontSize', 15);
hPh = plot(axP, wB, wB, 'Color', blue, 'LineWidth', 2.5);
hCornP = xline(axP, 1, '--', 'Color', gray, 'LineWidth', 1.2);
hDotP = plot(axP, 1, 0, 'o', 'MarkerSize', 10, 'MarkerFaceColor', red, 'MarkerEdgeColor', 'w');
xlabel(axP, 'frequency $\omega$ (rad/s)', 'Interpreter', 'latex');
ylabel(axP, '$\angle G(j\omega)$ (deg)', 'Interpreter', 'latex');

% controls
pn = uigridlayout(gl, [20 1]); pn.Layout.Row = [1 2]; pn.Layout.Column = 3;
pn.RowHeight = repmat({'fit'}, 1, 20); pn.RowSpacing = 5;
uilabel(pn, 'Text', ['Input  ' uText ' = A sin(ωt)'], 'FontWeight', 'bold', 'FontSize', 14);
slW = uislider(pn, 'Limits', log10(wRange), 'Value', log10(w0), 'MinorTicks', [], ...
               'MajorTicks', log10(wTicks), 'MajorTickLabels', compose('%g', wTicks), ...
               'ValueChangingFcn', @(~, ev) setW(10^ev.Value), 'ValueChangedFcn', @(src, ~) setW(10^src.Value));
lblW = uilabel(pn, 'Text', '', 'FontSize', 14);
gp = uigridlayout(pn, [1 3]); gp.Padding = [0 0 0 0]; gp.ColumnSpacing = 4;
btPre = gobjects(1, 3); fac = [0.1 1 10];
for iPre = 1:3
    btPre(iPre) = uibutton(gp, 'Text', '', 'ButtonPushedFcn', @(~, ~) setW(fac(iPre)*M.wc));
end
uilabel(pn, 'Text', ['Amplitude  A  ' uUnitPlain], 'FontWeight', 'bold', 'FontSize', 14);
uislider(pn, 'Limits', ARange, 'Value', A0, 'ValueChangedFcn', @(src, ~) setA(src.Value), ...
         'ValueChangingFcn', @(~, ev) setA(ev.Value));
lblP = uilabel(pn, 'Text', '', 'FontWeight', 'bold', 'FontSize', 14, 'WordWrap', 'on');
uislider(pn, 'Limits', pRange, 'Value', p0, 'ValueChangedFcn', @(src, ~) setP(src.Value), ...
         'ValueChangingFcn', @(~, ev) setP(ev.Value));
uilabel(pn, 'Text', 'Speed', 'FontWeight', 'bold', 'FontSize', 14);
uidropdown(pn, 'Items', {'0.1x (slow motion)', '0.25x', '0.5x', '1x (real time)', '2x', '5x', '10x'}, ...
           'Value', '1x (real time)', 'ValueChangedFcn', @(src, ~) setSpeed(src.Value));
gb = uigridlayout(pn, [1 2]); gb.Padding = [0 0 0 0]; gb.ColumnSpacing = 4;
btPause = uibutton(gb, 'Text', 'Pause (Space)', 'ButtonPushedFcn', @(~, ~) togglePause());
uibutton(gb, 'Text', 'Reset (R)', 'ButtonPushedFcn', @(~, ~) reset());
lblVerdict = uilabel(pn, 'Text', '', 'FontSize', 22, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
lblTheory = uilabel(pn, 'Text', '', 'FontSize', 14, 'WordWrap', 'on');
lblMeas = uilabel(pn, 'Text', '', 'FontSize', 14, 'WordWrap', 'on');
lblT = uilabel(pn, 'Text', '', 'FontColor', [0.4 0.4 0.4]);
uilabel(pn, 'Text', helpText, 'WordWrap', 'on', 'FontColor', [0.4 0.4 0.4]);

setP(p0); setW(w0);

%% Real-time loop
tFrame = tic; carry = 0;
while isvalid(fig)
    dWall = min(toc(tFrame), 0.05); tFrame = tic;
    if ~paused
        carry = carry + dWall*speed;
        while carry >= h
            stepSim(); carry = carry - h;
        end
    else
        carry = 0;
    end
    drawAll();
    drawnow
    pause(max(0.001, 1/40 - toc(tFrame)));
end

%% Engine functions
    function stepSim()
        ph = ph + w*h;                       % phase accumulator: no jump when w changes
        u = Amp*sin(ph);
        x = Ad*x + Bd*u; t = t + h;
        y = M.C*x + M.D*u;
        cnt = cnt + 1;
        if cnt >= dec
            cnt = 0;
            if kH == nH, tH = circshift(tH, -1); uH = circshift(uH, -1); yH = circshift(yH, -1);
            else, kH = kH + 1; end
            tH(kH) = t; uH(kH) = u; yH(kH) = y;
        end
    end

    function rediscretize()
        T = 2*pi/w;
        h = min(2e-3, T/400);
        nx = M.n; E = expm([M.A M.B; zeros(1, nx + 1)]*h);   % exact ZOH discretization
        Ad = E(1:nx, 1:nx); Bd = E(1:nx, nx + 1);
        win = winLen();
        dec = max(1, round(win/(nH*0.8)/h));
    end

    function L = winLen()
        L = min(max(4*2*pi/w, 2), 80);
    end

    function drawAll()
        drawScene();
        % time plot
        win = winLen(); i = 1:kH;
        hU.XData = tH(i); hU.YData = uH(i); hY.XData = tH(i); hY.YData = yH(i);
        axT.XLim = [max(0, t - win), max(win, t)];
        yMax = max([Amp, abs(yH(tH > t - win))']);
        axT.YLim = 1.25*yMax*[-1 1];
        lblT.Text = sprintf('t = %.1f s', t);
        % steady-state measurement: least-squares sine fit over whole periods
        T = 2*pi/w; settled = false;
        if t - tChange > max(M.settle, 0) + 2*T
            % steady when the fits over the last two periods agree (transient gone)
            [r1, p1, cu] = fitPeriod(t - T, t); [r2, p2] = fitPeriod(t - 2*T, t - T);
            settled = abs(r1 - r2) < 0.01*r1 + 1e-9 && abs(mod(p1 - p2 + 180, 360) - 180) < 1;
            ratio = r1; phi = p1;
        end
        if settled
            lblMeas.Text = sprintf('Measured (simulation): ratio %s, phase %+.1f°', fmtG(ratio), phi);
            % mark the time shift between an input peak and the next output peak
            dt = -phi/360*T;                                  % output lags by dt (lead if < 0)
            tPk = (pi/2 - atan2(cu(2), cu(1)))/w;             % input peak times: tPk + k T
            nPk = floor((t - tPk - max(dt, 0) - 0.05*T)/T);
            t1 = tPk + nPk*T; t2 = t1 + dt; yTop = 1.1*yMax;
            hShift.XData = [t1 t1 NaN t2 t2 NaN t1 t2]; hShift.YData = [-yMax yTop NaN -yMax yTop NaN yTop yTop];
            hShiftTxt.Position = [(t1 + t2)/2, yTop, 0];
            hShiftTxt.String = sprintf('$\\Delta t = %.3g$ s', abs(dt));
        else
            lblMeas.Text = 'Measured (simulation): settling ... (wait for the transient to die out)';
            hShift.XData = NaN; hShift.YData = NaN; hShiftTxt.String = '';
        end
    end

    function [ratio, phi, cu] = fitPeriod(ta, tb)
        % least-squares fit of a sin(wt) + b cos(wt) + c to input and output on [ta, tb]
        % (a sin + b cos = sqrt(a^2 + b^2) sin(wt + atan2(b, a)))
        sel = tH > ta & tH <= tb & ~isnan(tH);
        X = [sin(w*tH(sel)) cos(w*tH(sel)) ones(nnz(sel), 1)];
        cu = X\uH(sel); cy = X\yH(sel);
        ratio = hypot(cy(1), cy(2))/hypot(cu(1), cu(2));
        phi = wrapPh((atan2(cy(2), cy(1)) - atan2(cu(2), cu(1)))*180/pi);
    end

    function setW(wn_)
        w = min(max(wn_, wRange(1)), wRange(2)); slW.Value = log10(w);
        tChange = t; rediscretize(); refresh();
    end
    function setA(a)
        Amp = a; tChange = t; refresh();
    end
    function setP(v)
        p = v; M = makeModel(p); tChange = t; rediscretize();
        wc = M.wc;
        for k2 = 1:3, btPre(k2).Text = sprintf('%g×%s', fac(k2), cornerSym); end
        set(hMag, 'YData', 20*log10(abs(M.G(1i*wB))));
        set(hPh, 'YData', wrapPh(angle(M.G(1i*wB))*180/pi, true));
        hCornM.Value = wc; hCornP.Value = wc;
        mg = 20*log10(abs(M.G(1i*wB)));
        axM.YLim = [max(min(mg) - 5, -60), max(max(mg) + 8, 10)];
        pg = wrapPh(angle(M.G(1i*wB))*180/pi, true);
        axP.YLim = [floor(min(pg)/45)*45 - 10, ceil(max(pg)/45)*45 + 10]; axP.YTick = -180:45:180;
        hTitle.String = M.title;
        lblP.Text = M.paramText;
        refresh();
    end
    function refresh()
        g = M.G(1i*w); mag = abs(g); phi = wrapPh(angle(g)*180/pi);
        lblW.Text = sprintf('ω = %.3g rad/s   (f = %.3g Hz, period %.3g s)', w, w/(2*pi), 2*pi/w);
        lblTheory.Text = sprintf('Theory: |G(jω)| = %s = %.1f dB,  ∠G(jω) = %+.1f°', fmtG(mag), 20*log10(mag), phi);
        if mag > 1.02
            lblVerdict.Text = sprintf('AMPLIFIED  ×%.3g', mag); lblVerdict.FontColor = red;
        elseif mag < 0.98
            lblVerdict.Text = sprintf('ATTENUATED  ×%.3g', mag); lblVerdict.FontColor = blue;
        else
            lblVerdict.Text = 'PASSES  ×1'; lblVerdict.FontColor = green;
        end
        set(hDotM, 'XData', w, 'YData', 20*log10(mag)); set(hDotP, 'XData', w, 'YData', wrapPh(angle(g)*180/pi, true));
        hAmpTxt.String = M.ampNote;
        yl = axM.YLim; m0 = 20*log10(abs(M.G(1i*wRange(1))));
        if m0 > mean(yl), yN = yl(1) + 0.1*diff(yl); else, yN = yl(2) - 0.1*diff(yl); end   % away from the curve
        hAmpTxt.Position = [wRange(1)*1.3, yN, 0];
    end
    function setSpeed(v)
        speed = sscanf(v, '%f');
    end
    function togglePause()
        paused = ~paused;
        if paused, btPause.Text = 'Play (Space)'; else, btPause.Text = 'Pause (Space)'; end
    end
    function reset()
        x = zeros(M.n, 1); t = 0; ph = 0; tChange = 0; kH = 0; tH(:) = NaN; uH(:) = NaN; yH(:) = NaN;
    end
    function keyPress(~, ev)
        switch ev.Key
            case 'space', togglePause();
            case 'r', reset();
            case 'uparrow', setW(w*2^(1/3));
            case 'downarrow', setW(w/2^(1/3));
        end
    end
    function v = wrapPh(v, unwrapIt)
        % phase in degrees in (-270, 90] (so -180 does not jump to +180)
        if nargin > 1 && unwrapIt
            v = unwrap(v*pi/180)*180/pi;
            v = v - 360*round((v(1) - wrapPh(v(1)))/360);
        else
            v = mod(v + 270, 360) - 270;
        end
    end


%% ======================= Model and animation =======================
    function M = makeModel(tau)
        M.n = 2;                                   % state: [speed; angle]
        M.A = [-1/tau 0; 1 0]; M.B = [K/tau; 0]; M.C = [1 0]; M.D = 0;
        M.G = @(s) K./(tau*s + 1);
        M.wc = 1/tau; M.settle = 5*tau;
        M.title = sprintf('$G(s)=\\displaystyle\\frac{%g}{%g\\,s+1}$', K, tau);
        M.paramText = sprintf('Time constant  τ = %.3g s   (corner 1/τ = %.3g rad/s)', tau, 1/tau);
        M.ampNote = sprintf('amplified ($|G|>1$) for $\\omega<\\sqrt{K^2-1}/\\tau=%.3g$ rad/s', sqrt(K^2 - 1)/tau);
    end

    function setupScene()
        axA.XLim = [-3.2 3.2]; axA.YLim = [-1.75 1.75];
        th = linspace(0, 2*pi, 100);
        % voltage gauge (left) and speed gauge (right)
        for xg = [-2.7 2.75]
            patch(axA, xg + [-0.18 0.18 0.18 -0.18], [-1.3 -1.3 1.3 1.3], [0.95 0.95 0.95], 'EdgeColor', [0.6 0.6 0.6]);
            plot(axA, xg + [-0.25 0.25], [0 0], 'k', 'LineWidth', 1);
        end
        sc.vBar = patch(axA, [0 0 0 0], [0 0 0 0], gray, 'EdgeColor', 'none');
        sc.wBar = patch(axA, [0 0 0 0], [0 0 0 0], blue, 'EdgeColor', 'none');
        text(axA, -2.7, -1.5, 'voltage $v$', 'Interpreter', 'latex', 'HorizontalAlignment', 'center', 'FontSize', 13);
        text(axA, 2.75, -1.5, 'speed $\omega_m$', 'Interpreter', 'latex', 'HorizontalAlignment', 'center', 'FontSize', 13);
        % motor body, shaft and disk
        patch(axA, [-2.1 -0.7 -0.7 -2.1], [-0.55 -0.55 0.55 0.55], [0.45 0.47 0.5], 'EdgeColor', [0.2 0.2 0.2]);
        text(axA, -1.4, 0, 'DC motor', 'Color', 'w', 'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
        plot(axA, [-0.7 0.6], [0 0], 'Color', [0.3 0.3 0.3], 'LineWidth', 6);
        sc.c = [1.15 0]; sc.R = 1.05;
        patch(axA, sc.c(1) + sc.R*cos(th), sc.c(2) + sc.R*sin(th), [0.85 0.88 0.93], 'EdgeColor', [0.2 0.2 0.2], 'LineWidth', 1.5);
        sc.spokes = plot(axA, NaN, NaN, 'Color', [0.35 0.35 0.35], 'LineWidth', 2);
        sc.needle = plot(axA, NaN, NaN, 'Color', red, 'LineWidth', 4);
    end

    function drawScene()
        hv = 1.2*u/ARange(2); hw = 1.2*y/(K*ARange(2));
        sc.vBar.XData = -2.7 + [-0.15 0.15 0.15 -0.15]; sc.vBar.YData = [0 0 hv hv];
        sc.wBar.XData = 2.75 + [-0.15 0.15 0.15 -0.15]; sc.wBar.YData = [0 0 hw hw];
        th = x(2) + [0 2*pi/3 4*pi/3];
        X = [sc.c(1) + 0*th; sc.c(1) + sc.R*cos(th); nan(1, 3)]; Y = [0*th; sc.R*sin(th); nan(1, 3)];
        sc.spokes.XData = X(:); sc.spokes.YData = Y(:);
        sc.needle.XData = sc.c(1) + [0 0.95*sc.R*cos(x(2))]; sc.needle.YData = [0 0.95*sc.R*sin(x(2))];
    end

end

function s = fmtG(g)
s = sprintf('%.3g', g);
end
