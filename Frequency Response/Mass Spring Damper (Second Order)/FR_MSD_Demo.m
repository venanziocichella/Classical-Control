function FR_MSD_Demo
%FR_MSD_DEMO  Frequency response of a mass-spring-damper (second order, resonant low-pass).
%
%   Run FR_MSD_Demo. A sinusoidal force F(t) pushes the mass of
%       m x'' + c x' + k x = F
%   To compare input and output in the same units, the input is shown as
%   the static deflection F(t)/k (where the mass would sit if the force
%   changed very slowly, dashed ghost block). Then
%       G(s) = X(s)/(F(s)/k) = wn^2/(s^2 + 2 zeta wn s + wn^2),
%   wn = sqrt(k/m), zeta = c/(2 sqrt(k m)).
%   Slow forcing: the mass follows the ghost (|G| = 1, in phase).
%   Near wn: resonance, the motion is amplified (x 1/(2 zeta)) and lags by 90 deg.
%   Fast forcing: the mass barely moves and moves opposite to the force (-180 deg).
%
%   Keys: Space = pause, R = reset, Up/Down = change the input frequency.

%% ===================== SETTINGS: EDIT HERE =====================
m     = 1;      % mass [kg]
k     = 10;     % spring stiffness [N/m]   -> wn = sqrt(k/m) = 3.16 rad/s
zeta0 = 0.1;    % initial damping ratio
w0    = 1;      % initial input frequency [rad/s]
A0    = 0.15;   % input amplitude, F0/k [m]
%% ===============================================================
wn = sqrt(k/m);
figName = 'Frequency Response: mass-spring-damper (second order, resonant low-pass)';
wRange = [0.1 50]; wTicks = [0.1 1 10];
ARange = [0.05 0.3]; p0 = zeta0; pRange = [0.05 1];
uSym = '$F(t)/k$'; ySym = '$x(t)$'; uUnit = '(m)'; yUnit = '(m)';
uUnitPlain = '(F0/k, m)'; uText = 'force F(t)/k'; cornerSym = 'ωn';
helpText = ['Dashed block: where the mass would be if the force changed slowly (F/k). ' ...
            'Near ωn the spring and the mass trade energy: resonance.'];

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
    function M = makeModel(z)
        M.n = 2;                                   % state: [position; velocity]
        M.A = [0 1; -wn^2 -2*z*wn]; M.B = [0; wn^2]; M.C = [1 0]; M.D = 0;
        M.G = @(s) wn^2./(s.^2 + 2*z*wn*s + wn^2);
        M.wc = wn; M.settle = 4/(z*wn);
        M.title = sprintf('$G(s)=\\displaystyle\\frac{\\omega_n^2}{s^2+2\\zeta\\omega_n s+\\omega_n^2},\\ \\omega_n=%.3g,\\ \\zeta=%.2f$', wn, z);
        M.paramText = sprintf('Damping ratio  ζ = %.2f   (c = %.3g N·s/m)', z, 2*z*sqrt(k*m));
        if z < 1/sqrt(2)
            M.ampNote = sprintf('amplified ($|G|>1$) for $\\omega<\\omega_n\\sqrt{2-4\\zeta^2}=%.3g$ rad/s', wn*sqrt(2 - 4*z^2));
        else
            M.ampNote = 'never amplified for $\zeta\geq 1/\sqrt{2}$';
        end
        Mr = 1; if z < 1/sqrt(2), Mr = 1/(2*z*sqrt(1 - z^2)); end
        sc.S = 1.3/(ARange(2)*Mr);                 % drawing scale [units per m]
    end

    function setupScene()
        axA.XLim = [-3.3 3.3]; axA.YLim = [-1.3 1.5];
        patch(axA, [-3.3 -3 -3 -3.3], [-0.8 -0.8 1 1], [0.6 0.6 0.6], 'EdgeColor', 'none');
        plot(axA, [-3 3.3], [-0.8 -0.8], 'Color', [0.4 0.4 0.4], 'LineWidth', 2);
        sc.x0 = 0.2; sc.wB = 0.9; sc.hB = 0.9;     % rest position and size of the block
        plot(axA, sc.x0*[1 1], [-0.8 -1.0], 'k', 'LineWidth', 1);
        text(axA, sc.x0, -1.1, '$x=0$', 'Interpreter', 'latex', 'HorizontalAlignment', 'center', 'FontSize', 12);
        sc.ghost = plot(axA, NaN, NaN, '--', 'Color', gray, 'LineWidth', 1.5);
        sc.spring = plot(axA, NaN, NaN, 'Color', [0.2 0.2 0.2], 'LineWidth', 2);
        sc.damper = plot(axA, NaN, NaN, 'Color', [0.2 0.2 0.2], 'LineWidth', 2);
        sc.block = patch(axA, [0 1 1 0], [0 0 1 1], blue, 'EdgeColor', [0.15 0.15 0.15]);
        sc.mtxt = text(axA, 0, 0, '$m$', 'Interpreter', 'latex', 'Color', 'w', 'FontSize', 16, 'HorizontalAlignment', 'center');
        sc.arrow = plot(axA, NaN, NaN, 'Color', red, 'LineWidth', 4);
        sc.head = patch(axA, NaN, NaN, red, 'EdgeColor', 'none');
        sc.ftxt = text(axA, 0, 0, '$F(t)$', 'Interpreter', 'latex', 'Color', red, 'FontSize', 14, 'HorizontalAlignment', 'center');
        text(axA, -1.9, 0.62, '$k$', 'Interpreter', 'latex', 'FontSize', 14);
        text(axA, -1.9, -0.5, '$c$', 'Interpreter', 'latex', 'FontSize', 14);
    end

    function drawScene()
        xb = sc.x0 + sc.S*y; xl = xb - sc.wB/2; yb = -0.8;
        n = 10; xs = linspace(-3, xl, 2*n + 1);
        ys = 0.35 + 0.1*[0 repmat([1 -1], 1, n - 1) 1 0]; ys = ys(1:numel(xs));
        sc.spring.XData = xs; sc.spring.YData = ys;
        gap = xl + 3; yd = -0.3; hc = 0.09;
        c0 = -3 + 0.2*gap; c1 = -3 + 0.65*gap; pp = -3 + 0.5*gap;
        sc.damper.XData = [-3 c0 NaN c1 c0 c0 c1 NaN pp pp NaN pp xl];
        sc.damper.YData = [yd yd NaN yd+hc yd+hc yd-hc yd-hc NaN yd-0.8*hc yd+0.8*hc NaN yd yd];
        sc.block.XData = xl + [0 sc.wB sc.wB 0]; sc.block.YData = yb + [0 0 sc.hB sc.hB];
        sc.mtxt.Position = [xb, yb + sc.hB/2, 0];
        xg = sc.x0 + sc.S*u - sc.wB/2;
        sc.ghost.XData = xg + [0 sc.wB sc.wB 0 0]; sc.ghost.YData = yb + [0 0 sc.hB sc.hB 0];
        % force arrow on the right face, length proportional to F
        L = 1.1*u/ARange(2); ya = yb + sc.hB + 0.25;
        sc.arrow.XData = [xb xb + L]; sc.arrow.YData = [ya ya];
        s_ = sign(L) + (L == 0);
        sc.head.XData = xb + L + s_*[0.18 0 0]; sc.head.YData = ya + [0 0.12 -0.12];
        sc.ftxt.Position = [xb, ya + 0.25, 0];
        if abs(L) < 0.05, sc.head.XData = NaN(1, 3); end
    end

end

function s = fmtG(g)
s = sprintf('%.3g', g);
end
