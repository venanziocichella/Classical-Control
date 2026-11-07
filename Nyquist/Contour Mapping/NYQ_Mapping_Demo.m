function NYQ_Mapping_Demo
%NYQ_MAPPING_DEMO  Contour mapping through L(s): Cauchy's argument principle and Nyquist.
%
%   Run NYQ_Mapping_Demo. Left: the s-plane with the poles (x) and zeros (o)
%   of the mapping function L(s). Draw a curve or a closed contour on it with
%   the mouse. Right: the L-plane (axes L_x, L_y) with the image L(s) of the
%   contour, updated while you draw.
%
%   - Type L(s) in the box like C(s) in the other demos (numbers, s,
%     + - * / ^ and parentheses, e.g. (s+1)/((s+2)^2+1)).
%   - Tools: Draw (freehand; end the curve where you started to close it),
%     Move (drag the contour, a pole or a zero, or the empty plane to pan).
%     Nyquist contour: up the jw axis (indenting to the right of poles on
%     it) and back along a large clockwise semicircle.
%   - For a closed contour the demo counts the poles P of L inside and the
%     encirclements N of -1 by the image: Z = N + P zeros of 1 + kL inside.
%   - Play moves a point along the contour: the phasors from the poles and
%     zeros to the point, and the net turn of each one, are shown.
%   - Compressed scale: |L| > 1 is drawn at radius 1 + ln|L|, so the image
%     stays on the screen near a pole.
%   Mouse wheel: zoom. Keys: Space = play, N = Nyquist contour,
%   C = clear, F = fit.
%
%   Base MATLAB R2021a or newer, no toolboxes.

%% ===================== SETTINGS: EDIT HERE =====================
L0 = '50/((s+1)*(s+2)*(s+3))';   % L(s) shown at start, with the Nyquist contour
%% ===============================================================

%% ======================= Engine (no need to edit below) =======================
mapC = [122 63 176]/255; zeroC = [29 95 168]/255; poleC = [208 96 42]/255;
red = [180 56 42]/255; green = [47 125 50]/255; gray = [0.45 0.45 0.45]; light = [0.88 0.9 0.92];
Lsys = []; kGain = 1; clRoots = [];
cpts = []; cclosed = false; ckind = '';          % contour: complex column vector
tool = 'draw'; center = -1; scaleMode = 'linear';   % encirclements always counted around -1
sV = struct('cx', 0, 'cy', 0, 'half', 5); lV = struct('cx', 0, 'cy', 0, 'half', 2); lT = lV; lAuto = true;
img = []; dirty = true; tr = 0; playing = false; hoverS = NaN; dragS = []; dragL = []; typing = false;

fig = uifigure('Name', 'Nyquist: mapping contours through L(s)', 'Position', [40 40 1400 820], 'Color', 'w', ...
    'WindowButtonDownFcn', @mouseDown, 'WindowButtonMotionFcn', @mouseMove, 'WindowButtonUpFcn', @mouseUp, ...
    'WindowScrollWheelFcn', @wheel, 'WindowKeyPressFcn', @keyPress);
gl = uigridlayout(fig, [2 3]); gl.ColumnWidth = {'1x', '1x', 320}; gl.RowHeight = {'1x', 170};
axS = uiaxes(gl); axS.Layout.Row = 1; axS.Layout.Column = 1;
axL = uiaxes(gl); axL.Layout.Row = 1; axL.Layout.Column = 2;
axPh = uiaxes(gl); axPh.Layout.Row = 2; axPh.Layout.Column = [1 2];
for ax = [axS axL axPh]
    hold(ax, 'on'); ax.Toolbar.Visible = 'off'; disableDefaultInteractivity(ax);
    ax.TickLabelInterpreter = 'latex'; ax.FontSize = 11; box(ax, 'on');
end
for ax = [axS axL]
    ax.DataAspectRatio = [1 1 1]; grid(ax, 'on'); ax.XLimMode = 'manual'; ax.YLimMode = 'manual';
end
% s-plane
hRHP = patch(axS, [0 1e6 1e6 0], [-1e6 -1e6 1e6 1e6], [1 0.93 0.92], 'EdgeColor', 'none');
xline(axS, 0, 'Color', gray); yline(axS, 0, 'Color', gray);
hPhZ = plot(axS, NaN, NaN, '--', 'Color', zeroC, 'LineWidth', 1);
hPhP = plot(axS, NaN, NaN, '--', 'Color', poleC, 'LineWidth', 1);
hC = plot(axS, NaN, NaN, 'Color', mapC, 'LineWidth', 2.5);
hCA = patch(axS, NaN, NaN, mapC, 'EdgeColor', 'none');
hC0 = plot(axS, NaN, NaN, 'o', 'MarkerSize', 7, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', mapC, 'LineWidth', 1.5);
hZ = plot(axS, NaN, NaN, 'o', 'MarkerSize', 9, 'LineWidth', 2, 'Color', zeroC, 'MarkerFaceColor', 'w');
hP = plot(axS, NaN, NaN, 'x', 'MarkerSize', 11, 'LineWidth', 2.2, 'Color', poleC);
hTrS = plot(axS, NaN, NaN, 'o', 'MarkerSize', 9, 'MarkerFaceColor', red, 'MarkerEdgeColor', 'w');
hHov = plot(axS, NaN, NaN, 'o', 'MarkerSize', 6, 'Color', gray);
hHovTxt = text(axS, 0, 0, '', 'Units', 'normalized', 'Position', [0.02 0.03], 'FontSize', 11, 'Color', gray, 'FontName', 'FixedWidth');
title(axS, '$s$-plane', 'Interpreter', 'latex', 'FontSize', 15);
xlabel(axS, '$\sigma$', 'Interpreter', 'latex'); ylabel(axS, '$j\omega$', 'Interpreter', 'latex');
% L-plane
xline(axL, 0, 'Color', gray); yline(axL, 0, 'Color', gray);
hCirc = plot(axL, NaN, NaN, 'Color', light, 'LineWidth', 1);
hCircTxt = gobjects(1, 5);
for kc = 1:5, hCircTxt(kc) = text(axL, NaN, NaN, '', 'FontSize', 10, 'Color', gray, 'Clipping', 'on'); end
hUnit = plot(axL, NaN, NaN, '--', 'Color', gray, 'LineWidth', 1);
plot(axL, -1, 0, '+', 'MarkerSize', 12, 'LineWidth', 2, 'Color', red);
text(axL, -1, 0, '$-1$', 'Interpreter', 'latex', 'Color', red, 'VerticalAlignment', 'top', 'HorizontalAlignment', 'center', 'FontSize', 12, 'Clipping', 'on');
hI = plot(axL, NaN, NaN, 'Color', mapC, 'LineWidth', 2.5);
hIA = patch(axL, NaN, NaN, mapC, 'EdgeColor', 'none');
hI0 = plot(axL, NaN, NaN, 'o', 'MarkerSize', 7, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', mapC, 'LineWidth', 1.5);
hTrPart = plot(axL, NaN, NaN, 'Color', [red 0.35], 'LineWidth', 5);
hTrVec = plot(axL, NaN, NaN, 'k', 'LineWidth', 1.2);
hTrL = plot(axL, NaN, NaN, 'o', 'MarkerSize', 9, 'MarkerFaceColor', red, 'MarkerEdgeColor', 'w');
hHovL = plot(axL, NaN, NaN, 'o', 'MarkerSize', 6, 'Color', gray);
hLwarn = text(axL, 0, 0, '', 'Units', 'normalized', 'Position', [0.02 0.03], 'FontSize', 11, 'Color', red);
hLtitle = title(axL, '$L$-plane', 'Interpreter', 'latex', 'FontSize', 15);
xlabel(axL, '$L_x$', 'Interpreter', 'latex'); ylabel(axL, '$L_y$', 'Interpreter', 'latex');
% phase along the contour
hPhK = plot(axPh, NaN, NaN, '--', 'Color', light);
hPh = plot(axPh, NaN, NaN, 'Color', mapC, 'LineWidth', 2);
hPhDot = plot(axPh, NaN, NaN, 'o', 'MarkerSize', 8, 'MarkerFaceColor', red, 'MarkerEdgeColor', 'w');
axPh.XLim = [0 1]; axPh.XTick = [0 1]; axPh.XTickLabel = {'start', 'end'};
xlabel(axPh, 'position along the contour', 'Interpreter', 'latex');
hPhTitle = title(axPh, '', 'Interpreter', 'latex', 'FontSize', 13);
for h = [hRHP hPhZ hPhP hC hCA hC0 hZ hP hTrS hHov hCirc hUnit hI hIA hI0 hTrPart hTrVec hTrL hHovL hPhK hPh hPhDot]
    h.HitTest = 'off'; h.PickableParts = 'none';
end

% controls
pn = uigridlayout(gl, [26 1]); pn.Layout.Row = [1 2]; pn.Layout.Column = 3;
pn.RowHeight = repmat({'fit'}, 1, 26); pn.RowSpacing = 5; pn.Scrollable = 'on';
uilabel(pn, 'Text', 'Mapping function L(s)', 'FontWeight', 'bold', 'FontSize', 14);
g1 = uigridlayout(pn, [1 2]); g1.Padding = [0 0 0 0]; g1.ColumnWidth = {'1x', 'fit'};
edL = uieditfield(g1, 'text', 'Value', L0, 'ValueChangingFcn', @(~, ~) setTyping(true), ...
    'ValueChangedFcn', @(~, ~) applyText());
uibutton(g1, 'Text', 'Apply', 'ButtonPushedFcn', @(~, ~) applyText());
lblL = uilabel(pn, 'Text', '', 'WordWrap', 'on', 'FontName', 'monospaced');
lblK = uilabel(pn, 'Text', 'Gain k = 1 (the right plot shows k L(s))');
slK = uislider(pn, 'Limits', [-2 2], 'Value', 0, 'MajorTicks', -2:2, 'MajorTickLabels', {'0.01', '0.1', '1', '10', '100'}, 'MinorTicks', [], ...
    'ValueChangingFcn', @(~, ev) setK(10^ev.Value), 'ValueChangedFcn', @(src, ~) setK(10^src.Value));
uilabel(pn, 'Text', 'Contour', 'FontWeight', 'bold', 'FontSize', 14);
g2 = uigridlayout(pn, [1 2]); g2.Padding = [0 0 0 0]; g2.ColumnSpacing = 4;
names = {'draw', 'move'}; labels = {'Draw', 'Move'};
btTool = gobjects(1, 2);
for kt = 1:2
    btTool(kt) = uibutton(g2, 'state', 'Text', labels{kt}, 'ValueChangedFcn', @(~, ~) setTool(names{kt}));
end
g3 = uigridlayout(pn, [1 2]); g3.Padding = [0 0 0 0]; g3.ColumnSpacing = 4;
uibutton(g3, 'Text', 'Nyquist (N)', 'ButtonPushedFcn', @(~, ~) setNyquist());
uibutton(g3, 'Text', 'Clear (C)', 'ButtonPushedFcn', @(~, ~) clearC());
uilabel(pn, 'WordWrap', 'on', 'FontColor', gray, 'Text', ...
    'Draw: freehand; end where you started to close the curve. Move: drag the contour, a pole or a zero (L(s) follows), or the empty plane to pan. Wheel: zoom.');
uilabel(pn, 'Text', 'Encirclements of -1', 'FontWeight', 'bold', 'FontSize', 14);
lblCount = uilabel(pn, 'Text', '', 'WordWrap', 'on');
lblVerdict = uilabel(pn, 'Text', '', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'WordWrap', 'on');
uilabel(pn, 'Text', 'Moving point', 'FontWeight', 'bold', 'FontSize', 14);
btPlay = uibutton(pn, 'Text', 'Play (Space)', 'ButtonPushedFcn', @(~, ~) togglePlay());
slT = uislider(pn, 'Limits', [0 1], 'Value', 0, 'MajorTicks', [], 'MinorTicks', [], ...
    'ValueChangingFcn', @(~, ev) setTr(ev.Value), 'ValueChangedFcn', @(src, ~) setTr(src.Value));
lblTr = uilabel(pn, 'Text', '', 'WordWrap', 'on', 'FontName', 'monospaced');
uilabel(pn, 'Text', 'View', 'FontWeight', 'bold', 'FontSize', 14);
ddScale = uidropdown(pn, 'Items', {'linear |L|', 'compressed |L| (log)'}, 'ItemsData', {'linear', 'log'}, ...
    'ValueChangedFcn', @(src, ~) setScale(src.Value));
g4 = uigridlayout(pn, [1 2]); g4.Padding = [0 0 0 0]; g4.ColumnSpacing = 4;
uibutton(g4, 'Text', 'Fit s-plane (F)', 'ButtonPushedFcn', @(~, ~) fitS([]));
uibutton(g4, 'Text', 'Fit L-plane', 'ButtonPushedFcn', @(~, ~) setAuto(true));
cbAuto = uicheckbox(pn, 'Text', 'auto-fit the L-plane', 'Value', true, 'ValueChangedFcn', @(src, ~) setAuto(src.Value));
cbUnit = uicheckbox(pn, 'Text', 'unit circle |L| = 1', 'Value', false);

setTool('draw');
init();

%% Loop
tFrame = tic;
while isvalid(fig)
    dWall = min(toc(tFrame), 0.05); tFrame = tic;
    if dirty, compute(); end
    if playing && ~isempty(img)
        tr = tr + dWall/10;
        if tr >= 1, tr = 1; playing = false; btPlay.Text = 'Play (Space)'; end
        slT.Value = tr;
    end
    drawAll();
    drawnow
    pause(max(0.001, 1/30 - toc(tFrame)));
end

%% ======================= L(s) =======================
    function setL(num, den, txt)
        num = stripLead(num); den = stripLead(den);
        if all(den == 0), error('The denominator of L(s) is zero.'); end
        Lsys = struct('num', num, 'den', den, 'zeros', cleanRoots(roots(num)), 'poles', cleanRoots(roots(den)), 'K', num(1)/den(1));
        if nargin > 2, edL.Value = txt; end
        updateLabel(); updateCl();
    end
    function updateLabel()
        lblL.Text = {['L(s) = ' localTfString(Lsys.num, Lsys.den)], ['zeros (o): ' rootList(Lsys.zeros)], ['poles (x): ' rootList(Lsys.poles)]};
    end
    function updateCl()
        n = max(numel(Lsys.den), numel(Lsys.num));
        a = [zeros(1, n - numel(Lsys.den)) Lsys.den] + kGain*[zeros(1, n - numel(Lsys.num)) Lsys.num];
        clRoots = cleanRoots(roots(stripLead(a)));
        dirty = true;
    end
    function setK(k)
        kGain = k; slK.Value = log10(k);
        lblK.Text = sprintf('Gain k = %.3g (the right plot shows k L(s))', k);
        updateCl();
    end
    function applyText()
        typing = false;
        try
            [num, den] = localParseL(edL.Value);
            setL(num, den);
        catch err
            uialert(fig, err.message, 'L(s) not updated (using the previous one)');
        end
    end
    function setTyping(v), typing = v; end
    function rebuildFromRoots()
        z = Lsys.zeros; p = Lsys.poles; K = Lsys.K;
        setL(K*real(poly(z)), real(poly(p)), localFactorText(K, z, p));
        Lsys.zeros = z; Lsys.poles = p;
    end
    function v = Lof(s)
        v = kGain*polyval(Lsys.num, s)./polyval(Lsys.den, s);
    end
    function q = plotPt(v)
        q = v; q(~isfinite(v)) = NaN;
        if strcmp(scaleMode, 'log')
            r = abs(v); k = r > 1;
            q(k) = v(k)./r(k).*(1 + log(r(k)));
        end
    end

%% ======================= contours =======================
    function z = nyquistPts()
        mags = abs([Lsys.poles; Lsys.zeros]);
        big = max([1; mags]); R = 200*big;
        ax0 = sort(imag(Lsys.poles(abs(real(Lsys.poles)) < 1e-9*big)));
        if ~isempty(ax0), ax0 = ax0([true; diff(ax0(:)) > 1e-12]); end
        eps0 = 0.04*sV.half;
        if numel(ax0) > 1, eps0 = min(eps0, 0.3*min(diff(ax0))); end
        wl = max(2*sV.half, 2*big);
        wp = unique([wl*(0:300)/300, wl*(R/wl).^((1:150)/150)]);
        ws = [-fliplr(wp(2:end)), wp];
        axisPts = []; ip = 1;
        for w = ws
            while ip <= numel(ax0) && ax0(ip) + eps0 < w
                a = linspace(-pi/2, pi/2, 31);
                axisPts = [axisPts, 1i*ax0(ip) + eps0*exp(1i*a)]; %#ok<AGROW>
                ip = ip + 1;
            end
            if any(abs(w - ax0) <= eps0), continue; end
            axisPts(end + 1) = 1i*w; %#ok<AGROW>
        end
        a = pi/2 - pi*(1:119)/120;
        zz = [axisPts, R*exp(1i*a)].';
        i0 = find(imag(axisPts) > 0 | (imag(axisPts) == 0 & real(axisPts) >= 0), 1);
        z = zz([i0:end, 1:i0 - 1]);
    end
    function setContour(z, closed, kind)
        if numel(z) < 2, cpts = []; else, cpts = z(:); end
        cclosed = closed; ckind = kind; tr = 0; slT.Value = 0; dirty = true;
    end
    function setNyquist(), setContour(nyquistPts(), true, 'nyquist'); end
    function clearC(), setContour([], false, ''); playing = false; btPlay.Text = 'Play (Space)'; end
    function init()
        [num, den] = localParseL(L0); setL(num, den); setK(1);
        fitS([]); setNyquist();
    end
    function setTool(k)
        tool = k;
        for i = 1:2, btTool(i).Value = strcmp(names{i}, k); end
    end
    function setScale(v), scaleMode = v; setAuto(true); end
    function setAuto(v), lAuto = v; cbAuto.Value = v; dirty = true; end
    function setTr(v), tr = v; playing = false; btPlay.Text = 'Play (Space)'; end
    function togglePlay()
        if isempty(cpts), return; end
        playing = ~playing;
        if playing, btPlay.Text = 'Pause (Space)'; if tr >= 1, tr = 0; end
        else, btPlay.Text = 'Play (Space)'; end
    end

%% ======================= image of the contour =======================
    function compute()
        dirty = false;
        if isempty(cpts) || isempty(Lsys), img = []; updateCount(); return; end
        V = cpts; if cclosed, V = [V; V(1)]; end
        stepL = sV.half/120; capL = sV.half/40;
        seg = diff(V); len = abs(seg);
        if strcmp(ckind, 'nyquist'), n = ones(size(len)); else, n = min(60, max(1, ceil(len/stepL))); end
        S = zeros(sum(n) + 1, 1); T = S; k = 0; wsum = 0;
        for j = 1:numel(seg)
            f = (0:n(j) - 1)'/n(j);
            S(k + (1:n(j))) = V(j) + seg(j)*f;
            T(k + (1:n(j))) = wsum + min(len(j), capL)*f;
            k = k + n(j); wsum = wsum + min(len(j), capL);
        end
        S(end) = V(end); T(end) = wsum;
        Lv = Lof(S); Pp = plotPt(Lv);
        if lAuto, lT = robustView(Pp); half = lT.half; vc = lT.cx + 1i*lT.cy;
        else, half = lV.half; vc = lV.cx + 1i*lV.cy; end
        tolD = 0.012*half; jump = 0.25*half; farR = 20*half + abs(vc);
        % refine where the image moves fast (several passes of bisection)
        for pass = 1:14
            bad = badPairs(Lv, Pp, tolD, farR);
            if ~any(bad) || numel(S) > 60000, break; end
            kb = find(bad);
            Sm = (S(kb) + S(kb + 1))/2; Tm = (T(kb) + T(kb + 1))/2; Lm = Lof(Sm);
            [~, ord] = sort([(1:numel(S))'; kb + 0.5]);
            S = [S; Sm]; S = S(ord); T = [T; Tm]; T = T(ord);
            Lv = [Lv; Lm]; Lv = Lv(ord); Pp = plotPt(Lv);
        end
        bad = badPairs(Lv, Pp, tolD, farR);
        ff = isfinite(Pp(1:end - 1)) & isfinite(Pp(2:end));
        brk = [false; ~ff | (bad & abs(diff(Pp)) > jump)];
        T = T/max(wsum, eps);
        % poles / zeros on the contour
        nearTol = 0.006*sV.half; onC = {};
        zset = clRoots; zname = 'zero of 1 + kL at ';
        for r = Lsys.poles.', if distToPolyline(cpts, cclosed, r) < nearTol, onC{end + 1} = ['pole ' fmtC(r)]; end, end %#ok<AGROW>
        for r = zset.', if distToPolyline(cpts, cclosed, r) < nearTol, onC{end + 1} = [zname fmtC(r)]; end, end %#ok<AGROW>
        % unwrapped phase of L - c and net number of turns
        w = Lv - center; okW = all(isfinite(w)) && all(w ~= 0) && ~any(brk);
        d = wrapPi(diff(angle(w))); d(~isfinite(d)) = 0;
        ph = (angle(w(1)) + [0; cumsum(d)])*180/pi; ph(~isfinite(w)) = NaN;
        turns = (ph(end) - ph(1))/360;
        % phasor angle of each root along the contour
        rts = [Lsys.zeros; Lsys.poles]; isZ = [true(numel(Lsys.zeros), 1); false(numel(Lsys.poles), 1)];
        ang = unwrap(angle(S - rts.'));
        wind = [];
        if cclosed && okW && isempty(onC) && abs(turns - round(turns)) < 0.05, wind = round(turns); end
        img = struct('S', S, 'L', Lv, 'P', Pp, 'T', T, 'brk', brk, 'ph', ph, 'onC', {onC}, 'rts', rts, 'isZ', isZ, 'ang', ang, 'wind', wind);
        updateCount();
    end
    function bad = badPairs(Lv, Pp, tolD, farR)
        ff = isfinite(Pp(1:end - 1)) & isfinite(Pp(2:end));
        far = ff & abs(Pp(1:end - 1)) > farR & abs(Pp(2:end)) > farR;
        ang = abs(wrapPi(angle(Lv(2:end) - center) - angle(Lv(1:end - 1) - center)));
        bad = ~ff | (~far & abs(diff(Pp)) > tolD) | ang > 0.3;
    end
    function v = robustView(Pp)
        q = Pp(isfinite(Pp)); keep = [0; center];
        if ~isempty(q)
            m = sort(abs(q)); q90 = m(floor(0.9*(numel(m) - 1)) + 1);
            keep = [keep; q(abs(q) <= 2.5*q90 + 1e-12)];
        end
        x0 = min(real(keep)); x1 = max(real(keep)); y0 = min(imag(keep)); y1 = max(imag(keep));
        asp = aspectOf(axL);
        v.half = max(0.5, 1.15*max((y1 - y0)/2*min(asp, 1), (x1 - x0)/2/max(asp, 1)));
        v.cx = (x0 + x1)/2; v.cy = (y0 + y1)/2;
    end

%% ======================= counting =======================
    function updateCount()
        if isempty(img) || isempty(cpts)
            lblCount.Text = 'Draw a closed contour on the s-plane.'; lblVerdict.Text = ''; return
        end
        if ~cclosed
            lblCount.Text = 'An open curve maps to an open curve. End the curve where you started (or use the Nyquist contour) to count encirclements.';
            lblVerdict.Text = ''; return
        end
        cw = signedArea(cpts) < 0; sg = 1 - 2*cw;   % -1 for clockwise
        if cw, dirW = 'clockwise'; Nsym = 'N_cw'; else, dirW = 'counterclockwise'; Nsym = 'N_ccw'; end
        inside = @(rs) sum(arrayfun(@(r) sg*windingAround(cpts, r), rs));
        Pin = inside(Lsys.poles); Zcl = inside(clRoots);
        rows = {['Contour: closed, traced ' dirW iff(strcmp(ckind, 'nyquist'), ' (Nyquist contour).', '.')]};
        lblVerdict.Text = ''; lblVerdict.FontColor = green;
        if ~isempty(img.onC)
            rows{end + 1} = ['The contour passes through the ' strjoin(img.onC, ', ') ...
                '. The argument principle does not apply there: move the contour a little.'];
            lblCount.Text = rows; lblVerdict.Text = 'undefined'; lblVerdict.FontColor = red; return
        end
        if isempty(img.wind), N = []; else, N = sg*img.wind; end
        rows{end + 1} = sprintf('Poles of L(s) inside: P = %d.', Pin);
        if isempty(N), rows{end + 1} = 'Image: could not count.';
        else
            rows{end + 1} = sprintf('Image %s -1: %s = %d.', encText(img.wind), Nsym, N);
            rows{end + 1} = sprintf('Zeros of 1 + kL(s) inside: Z = %s + P = %d (roots of 1 + kL give %d).', Nsym, N + Pin, Zcl);
            if strcmp(ckind, 'nyquist') && cw
                if N + Pin == 0, lblVerdict.Text = 'Closed loop stable: Z = 0';
                else, lblVerdict.Text = sprintf('Closed loop unstable: Z = %d in the RHP', N + Pin); lblVerdict.FontColor = red; end
            else
                lblVerdict.Text = sprintf('Z = %s + P = %d', Nsym, N + Pin);
                if N + Pin ~= Zcl, lblVerdict.FontColor = red; end
            end
        end
        rows{end + 1} = ['Roots of 1 + kL(s): ' rootList(clRoots)];
        lblCount.Text = rows;
    end
    function s = encText(w)
        if w == 0
            s = 'does not encircle';
        elseif w > 0
            s = sprintf('encircles %dx counterclockwise', w);
        else
            s = sprintf('encircles %dx clockwise', -w);
        end
    end

%% ======================= views and mouse =======================
    function fitS(~)
        if isempty(Lsys), pts = 0; else, pts = [Lsys.poles; Lsys.zeros; 0]; end
        if ~isempty(cpts) && ~strcmp(ckind, 'nyquist'), pts = [pts; cpts]; end
        x0 = min(real(pts)); x1 = max(real(pts)); y0 = min(imag(pts)); y1 = max(imag(pts));
        asp = aspectOf(axS);
        sV.half = max(1.5, 1.3*max((y1 - y0)/2*min(asp, 1), (x1 - x0)/2/max(asp, 1)) + 0.5);
        sV.cx = (x0 + x1)/2; sV.cy = (y0 + y1)/2; dirty = true;
    end
    function a = aspectOf(ax)
        p = ax.InnerPosition; a = max(p(3), 1)/max(p(4), 1);
    end
    function applyView(ax, v)
        asp = aspectOf(ax);
        ax.XLim = v.cx + v.half*max(asp, 1)*[-1 1]; ax.YLim = v.cy + v.half/min(asp, 1)*[-1 1];
    end
    function u = pxSize(ax)
        p = ax.InnerPosition; u = max(diff(ax.XLim)/p(3), diff(ax.YLim)/p(4));
    end
    function [inside, z] = pointIn(ax)
        cp = ax.CurrentPoint; z = cp(1, 1) + 1i*cp(1, 2);
        inside = cp(1, 1) >= ax.XLim(1) && cp(1, 1) <= ax.XLim(2) && cp(1, 2) >= ax.YLim(1) && cp(1, 2) <= ax.YLim(2);
    end
    function mouseDown(~, ~)
        [inS, s] = pointIn(axS); [inL, zl] = pointIn(axL);
        if inL && ~inS, dragL = zl; return; end
        if ~inS, return; end
        u = pxSize(axS);
        switch tool
            case 'draw', dragS = struct('kind', 'draw', 'pts', s, 'c', s); setContour([s; s], false, 'free');
            otherwise
                [dz, iz] = min(abs(Lsys.zeros - s)); [dp, ip] = min(abs(Lsys.poles - s));
                if isempty(dz), dz = Inf; end
                if isempty(dp), dp = Inf; end
                if min(dz, dp) < 12*u
                    if dz <= dp, which = 'zeros'; i = iz; else, which = 'poles'; i = ip; end
                    rr = Lsys.(which); r = rr(i);
                    mate = find(abs(rr - conj(r)) < 1e-6*(1 + abs(r)) & (1:numel(rr))' ~= i, 1);
                    if imag(r) == 0, mate = []; end
                    dragS = struct('kind', 'root', 'pts', [], 'c', s, 'which', which, 'i', i, 'mate', mate, 'real', imag(r) == 0);
                elseif ~isempty(cpts) && (distToPolyline(cpts, cclosed, s) < 10*u || (cclosed && windingAround(cpts, s) ~= 0))
                    dragS = struct('kind', 'move', 'pts', [], 'c', s);
                else
                    dragS = struct('kind', 'pan', 'pts', [], 'c', s);
                end
        end
    end
    function mouseMove(~, ~)
        [inS, s] = pointIn(axS);
        if inS, hoverS = s; else, hoverS = NaN; end
        if ~isempty(dragL)
            [~, zl] = pointIn(axL); d = zl - dragL;
            lV.cx = lV.cx - real(d); lV.cy = lV.cy - imag(d); setAuto(false); applyView(axL, lV);
            [~, dragL] = pointIn(axL); return
        end
        if isempty(dragS), return; end
        u = pxSize(axS);
        switch dragS.kind
            case 'draw'
                if abs(s - dragS.pts(end)) >= 3*u, dragS.pts(end + 1, 1) = s; cpts = dragS.pts; cclosed = false; dirty = true; end
            case 'move'
                cpts = cpts + (s - dragS.c); dragS.c = s; dirty = true;
                if strcmp(ckind, 'nyquist'), ckind = 'free'; end
            case 'pan'
                sV.cx = sV.cx - real(s - dragS.c); sV.cy = sV.cy - imag(s - dragS.c); applyView(axS, sV); dirty = true;
                [~, dragS.c] = pointIn(axS);
            case 'root'
                snap = 6*u; v = s;
                if dragS.real || abs(imag(v)) < snap, v = real(v); end
                if abs(real(v)) < snap, v = 1i*imag(v); end
                rr = Lsys.(dragS.which);
                if dragS.real, rr(dragS.i) = v;
                elseif imag(v) == 0
                    rr(dragS.i) = real(v) + 0.5i*snap; if ~isempty(dragS.mate), rr(dragS.mate) = real(v) - 0.5i*snap; end
                else
                    rr(dragS.i) = v; if ~isempty(dragS.mate), rr(dragS.mate) = conj(v); end
                end
                Lsys.(dragS.which) = rr; rebuildFromRoots();
        end
    end
    function mouseUp(~, ~)
        if ~isempty(dragS) && strcmp(dragS.kind, 'draw')
            z = dragS.pts;
            if numel(z) < 3
                setContour([], false, '');
            elseif abs(z(end) - z(1)) < 12*pxSize(axS) && numel(z) > 8   % ends where it started: closed
                setContour(z(1:end - 1), true, 'free');
            else
                setContour(z, false, 'free');
            end
        end
        if ~isempty(dragL), dirty = true; end
        dragS = []; dragL = [];
    end
    function wheel(~, ev)
        f = exp(ev.VerticalScrollCount*0.15);
        [inS, s] = pointIn(axS); [inL, zl] = pointIn(axL);
        if inS
            sV.half = sV.half*f; sV.cx = real(s) + (sV.cx - real(s))*f; sV.cy = imag(s) + (sV.cy - imag(s))*f; dirty = true;
        elseif inL
            lV.half = lV.half*f; lV.cx = real(zl) + (lV.cx - real(zl))*f; lV.cy = imag(zl) + (lV.cy - imag(zl))*f; setAuto(false);
        end
    end
    function keyPress(~, ev)
        if typing, return; end
        switch ev.Key
            case 'space', togglePlay();
            case 'n', setNyquist();
            case {'c', 'delete', 'backspace'}, clearC();
            case 'f', fitS([]); setAuto(true);
        end
    end

%% ======================= drawing =======================
    function drawAll()
        applyView(axS, sV);
        if lAuto   % ease toward the fitted view
            a = 0.25; lV.cx = lV.cx + a*(lT.cx - lV.cx); lV.cy = lV.cy + a*(lT.cy - lV.cy); lV.half = lV.half*(lT.half/lV.half)^a;
        end
        applyView(axL, lV);
        set(hZ, 'XData', real(Lsys.zeros), 'YData', imag(Lsys.zeros)); set(hP, 'XData', real(Lsys.poles), 'YData', imag(Lsys.poles));
        % compressed-scale circles
        if strcmp(scaleMode, 'log')
            th = linspace(0, 2*pi, 200); X = []; Y = []; lbl = {'1', '10', '100', '10^3', '10^4'};
            for e = 0:4
                rc = 1 + e*log(10); X = [X rc*cos(th) NaN]; Y = [Y rc*sin(th) NaN]; %#ok<AGROW>
                set(hCircTxt(e + 1), 'Position', [0.71*rc, 0.71*rc, 0], 'String', ['|L|=' lbl{e + 1}]);
            end
            set(hCirc, 'XData', X, 'YData', Y); grid(axL, 'off'); axL.XTick = []; axL.YTick = [];
        else
            set(hCirc, 'XData', NaN, 'YData', NaN); set(hCircTxt, 'String', ''); grid(axL, 'on');
            axL.XTickMode = 'auto'; axL.YTickMode = 'auto';
        end
        if cbUnit.Value, th = linspace(0, 2*pi, 200); set(hUnit, 'XData', cos(th), 'YData', sin(th)); else, set(hUnit, 'XData', NaN, 'YData', NaN); end
        hLtitle.String = sprintf('$L$-plane: image %s$L(s)$%s', iff(kGain == 1, '', sprintf('%.3g ', kGain)), iff(strcmp(scaleMode, 'log'), ', compressed $|L|$', ''));
        if isempty(img) || isempty(cpts)
            set([hC hC0 hI hI0 hTrS hTrL hTrPart hTrVec hPhZ hPhP hPh hPhDot hPhK], 'XData', NaN, 'YData', NaN);
            set([hCA hIA], 'Vertices', [], 'Faces', []);
            if ~isempty(cpts), V = cpts; set(hC, 'XData', real(V), 'YData', imag(V)); end
            hPhTitle.String = 'Phase along the contour'; lblTr.Text = 'Draw a contour, then press Play.';
            hLwarn.String = ''; hoverDraw(); return
        end
        V = cpts; if cclosed, V = [V; V(1)]; end
        set(hC, 'XData', real(V), 'YData', imag(V));
        set(hC0, 'XData', real(img.S(1)), 'YData', imag(img.S(1)));
        arrowPatch(hCA, img.S, false(size(img.S)), sV.half, axS);
        Xi = interleaveBreaks(clampV(img.P), img.brk);   % NaN before a break lifts the pen
        set(hI, 'XData', real(Xi), 'YData', imag(Xi));
        set(hI0, 'XData', real(img.P(1)), 'YData', imag(img.P(1)));
        arrowPatch(hIA, img.P, img.brk, lV.half, axL);
        hLwarn.String = iff(any(img.brk), 'The image goes through infinity (pole on the contour).', '');
        % moving point
        ti = find(img.T <= tr, 1, 'last'); if isempty(ti), ti = 1; end
        s0 = img.S(ti); L0 = img.L(ti);
        set(hTrS, 'XData', real(s0), 'YData', imag(s0));
        zz = img.rts(img.isZ); pp = img.rts(~img.isZ);
        set(hPhZ, 'XData', reshape([real(zz) real(s0) + 0*zz NaN(size(zz))].', 1, []), 'YData', reshape([imag(zz) imag(s0) + 0*zz NaN(size(zz))].', 1, []));
        set(hPhP, 'XData', reshape([real(pp) real(s0) + 0*pp NaN(size(pp))].', 1, []), 'YData', reshape([imag(pp) imag(s0) + 0*pp NaN(size(pp))].', 1, []));
        q = clampV(img.P(ti));
        part = interleaveBreaks(clampV(img.P(1:ti)), img.brk(1:ti));
        set(hTrPart, 'XData', real(part), 'YData', imag(part));
        set(hTrL, 'XData', real(q), 'YData', imag(q)); set(hTrVec, 'XData', [center real(q)], 'YData', [0 imag(q)]);
        % readout
        lines = {['s = ' fmtC(s0)], ['L(s) = ' fmtC(L0)]};
        if isfinite(L0), lines{end + 1} = sprintf('|L| = %.4g,  angle L = %.1f deg', abs(L0), angle(L0)*180/pi); end
        if ~isempty(img.rts) && numel(img.rts) <= 10
            lines{end + 1} = 'Net turn of each phasor so far:'; tot = 0;
            for kr = 1:numel(img.rts)
                d = (img.ang(ti, kr) - img.ang(1, kr))*180/pi;
                if img.isZ(kr), tot = tot + d; nm = 'zero '; else, tot = tot - d; nm = 'pole '; end
                lines{end + 1} = sprintf('  %s%-12s %+5.0f deg', nm, fmtC(img.rts(kr)), d); %#ok<AGROW>
            end
            lines{end + 1} = sprintf('  angle L: zeros - poles = %+.0f deg', tot);
        end
        lblTr.Text = lines;
        % phase plot
        ph = img.ph; ph(img.brk) = NaN; fph = ph(isfinite(ph));
        if ~isempty(fph)
            p0 = fph(1); lo = min([fph; p0 - 90]); hi = max([fph; p0 + 90]); pad = 0.08*(hi - lo);
            axPh.YLim = [lo - pad, hi + pad];
            ks = ceil((lo - pad - p0)/360):floor((hi + pad - p0)/360);
            axPh.YTick = p0 + 360*ks;
            axPh.YTickLabel = arrayfun(@(k) iff(k == 0, 'start', sprintf('%+d deg', 360*k)), ks, 'UniformOutput', false);
            set(hPhK, 'XData', repmat([0 1 NaN], 1, numel(ks)), 'YData', reshape([p0 + 360*ks; p0 + 360*ks; NaN(size(ks))], 1, []));
            set(hPh, 'XData', img.T, 'YData', ph); set(hPhDot, 'XData', img.T(ti), 'YData', img.ph(ti));
            net = img.ph(end) - p0;
            nm = '$\angle(1+L(s))$';
            hPhTitle.String = sprintf('Phase %s along the contour (unwrapped): net change %+.0f$^\\circ$ (%+.0f turns, + = counterclockwise)', nm, net, net/360);
        end
        hoverDraw();
    end
    function hoverDraw()
        if isfinite(hoverS) && isempty(dragS)
            L1 = Lof(hoverS); q = plotPt(L1);
            set(hHov, 'XData', real(hoverS), 'YData', imag(hoverS)); set(hHovL, 'XData', real(q), 'YData', imag(q));
            hHovTxt.String = ['s = ' fmtC(hoverS) '  ->  L(s) = ' fmtC(L1)];
        else
            set([hHov hHovL], 'XData', NaN, 'YData', NaN); hHovTxt.String = '';
        end
    end
    function z = clampV(z)
        big = 1e3*(lV.half + abs(lV.cx + 1i*lV.cy));
        k = abs(z) > big; z(k) = z(k)./abs(z(k))*big;
    end
    function arrowPatch(h, Z, brk, half, ax)
        % direction marks at 1/8, 3/8, 5/8 and 7/8 of the way (Z in plot coordinates)
        u = pxSize(ax); Vt = []; F = [];
        for f = [0.125 0.375 0.625 0.875]
            i = find(img.T <= f, 1, 'last'); if isempty(i), continue; end
            j = i + 1;
            while j <= numel(Z) && isfinite(Z(j)) && abs(Z(j) - Z(i)) < 4*u, j = j + 1; end
            if j > numel(Z) || ~isfinite(Z(i)) || ~isfinite(Z(j)) || any(brk(i + 1:j)) || abs(Z(i)) > 50*half + abs(ax.XLim(1)) + abs(ax.XLim(2)), continue; end
            d = (Z(j) - Z(i))/abs(Z(j) - Z(i)); sz = 10*u;
            tri = Z(i) + sz*[d; -0.6*d + 0.6i*d; -0.6*d - 0.6i*d];
            F = [F; size(Vt, 1) + (1:3)]; Vt = [Vt; real(tri) imag(tri)]; %#ok<AGROW>
        end
        set(h, 'Vertices', Vt, 'Faces', F);
        if isempty(Vt), set(h, 'Vertices', [], 'Faces', []); end
    end
end

%% ======================= helpers =======================
function z = interleaveBreaks(z, brk)
% insert a NaN before each sample that starts a new piece of the curve
k = find(brk);
if isempty(k), return; end
[~, ord] = sort([(1:numel(z))'; k - 0.5]);
z = [z(:); NaN(numel(k), 1)]; z = z(ord);
end

function a = wrapPi(a)
a = a - 2*pi*round(a/(2*pi));
end

function w = windingAround(pts, q)
% signed number of turns of the closed polyline pts around q (counterclockwise > 0)
d = wrapPi(diff(angle([pts; pts(1)] - q)));
w = round(sum(d)/(2*pi));
end

function d = distToPolyline(pts, closed, q)
if closed, pts = [pts; pts(1)]; end
a = pts(1:end - 1); b = pts(2:end); ab = b - a;
t = real(conj(ab).*(q - a))./max(abs(ab).^2, realmin);
t = min(max(t, 0), 1);
d = min(abs(a + t.*ab - q));
end

function A = signedArea(z)
x = real(z); y = imag(z);
A = sum(x.*circshift(y, -1) - circshift(x, -1).*y)/2;
end

function r = cleanRoots(r)
r = r(:);
if isempty(r), return; end
tol = 1e-9*max(1, max(abs(r)));
r(abs(imag(r)) < tol) = real(r(abs(imag(r)) < tol));
re = real(r); re(abs(re) < tol) = 0; r = re + 1i*imag(r);
end

function p = stripLead(p)
k = find(p ~= 0, 1);
if isempty(k), p = 0; else, p = p(k:end); end
end

function s = iff(c, a, b)
if c, s = a; else, s = b; end
end

function s = fmtC(z)
if ~isfinite(z), s = 'inf'; return; end
tol = 1e-9*max(1, abs(z));
re = real(z); im = imag(z);
if abs(re) < tol, re = 0; end
if abs(im) < tol, im = 0; end
if im == 0
    s = sprintf('%.4g', re);
elseif re == 0
    s = sprintf('%.4gj', im);
elseif im > 0
    s = sprintf('%.4g + %.4gj', re, im);
else
    s = sprintf('%.4g - %.4gj', re, -im);
end
end

function s = rootList(r)
r = r(imag(r) >= 0);
if isempty(r), s = 'none'; return; end
[~, o] = sort(real(r)); r = r(o); c = cell(1, numel(r));
for k = 1:numel(r)
    if imag(r(k)) > 0, c{k} = sprintf('%.4g ± %.4gj', real(r(k)), imag(r(k))); else, c{k} = sprintf('%.4g', real(r(k))); end
end
s = strjoin(c, ',  ');
end

function str = localFactorText(K, zs, ps)
% L(s) as text from gain, zeros and poles, e.g. 2*(s-2)*((s-2)^2+4)/((s+4)*(s+1)*(s-3))
n = facs(zs); d = facs(ps);
str = strjoin(n, '*');
if K ~= 1 || isempty(str)
    if isempty(str), str = sprintf('%.4g', K); else, str = sprintf('%.4g*%s', K, str); end
end
if numel(d) > 1, str = [str '/(' strjoin(d, '*') ')']; elseif numel(d) == 1, str = [str '/' d{1}]; end
    function out = facs(rs)
        out = {}; used = false(size(rs));
        for i = 1:numel(rs)
            if used(i), continue; end
            used(i) = true; r = rs(i);
            if imag(r) == 0
                if real(r) == 0, out{end + 1} = 's'; %#ok<AGROW>
                else, out{end + 1} = sprintf('(s%+.4g)', -real(r)); end %#ok<AGROW>
                continue
            end
            j = find(~used & abs(rs - conj(r)) < 1e-9*(1 + abs(r)), 1);
            used(j) = true;
            if real(r) == 0, out{end + 1} = sprintf('(s^2+%.4g)', imag(r)^2); %#ok<AGROW>
            else, out{end + 1} = sprintf('((s%+.4g)^2+%.4g)', -real(r), imag(r)^2); end %#ok<AGROW>
        end
    end
end

function str = localTfString(num, den)
% num(s)/den(s) as text, e.g. '(s + 1) / (s^2 + 4 s + 5)'.
num = stripLead(num); den = stripLead(den);
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
n = numel(p) - 1; str = '';
for k = 1:numel(p)
    a = p(k); e = n - k + 1;
    if a == 0, continue; end
    if isempty(str)
        if a < 0, str = '-'; end
    elseif a < 0, str = [str ' - '];
    else, str = [str ' + '];
    end
    a = abs(a);
    if a ~= 1 || e == 0
        str = [str sprintf('%.4g', a)];
        if e > 0, str = [str ' ']; end
    end
    if e == 1, str = [str 's']; elseif e > 1, str = sprintf('%ss^%d', str, e); end
end
if isempty(str), str = '0'; end
end

%% ======================= L(s) parser =======================
% Same rules as the C(s) box of the other demos and the browser version:
% numbers, s, + - * / ^ and parentheses (.* ./ .^ accepted). No toolbox needed.
function [num, den] = localParseL(str)
help = 'Type L(s) with numbers, s, + - * / ^ and parentheses only, e.g. 10*(s+2)/(s*(s+5))';
str = strtrim(char(str));
if isempty(str), error(help); end
tk = regexp(str, '\s*(\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?|s|\.?[-+*/^()])', 'tokens');
if isempty(tk) || ~strcmp(regexprep(str, '\s', ''), strjoin(cellfun(@(c) c{1}, tk, 'UniformOutput', false), ''))
    error(help);
end
toks = cellfun(@(c) regexprep(c{1}, '^\.(?=[*/^])', ''), tk, 'UniformOutput', false);
[r, i] = pExpr(toks, 1, str);
if i <= numel(toks)
    if any(strcmp(toks{i}, {'s', '('})) || ~isnan(str2double(toks{i}))
        error('Use * between factors, e.g. 2*s or (s+1)*(s+2).');
    end
    pFail(str);
end
if all(r.d == 0), pFail(str); end
num = fliplr(r.n); den = fliplr(r.d);
end

function pFail(str)
error('Could not read L(s) = %s. Example: 10*(s+2)/(s*(s+5))', str);
end

function [a, i] = pExpr(t, i, str)
[a, i] = pTerm(t, i, str);
while i <= numel(t) && any(strcmp(t{i}, {'+', '-'}))
    op = t{i}; [b, i] = pTerm(t, i + 1, str);
    if op == '-', b.n = -b.n; end
    a = rAdd(a, b);
end
end

function [a, i] = pTerm(t, i, str)
[a, i] = pUnary(t, i, str);
while i <= numel(t) && any(strcmp(t{i}, {'*', '/'}))
    op = t{i}; [b, i] = pUnary(t, i + 1, str);
    if op == '*', a = rMul(a, b); else, a = rDiv(a, b); end
end
end

function [a, i] = pUnary(t, i, str)
if i <= numel(t) && strcmp(t{i}, '-'), [a, i] = pUnary(t, i + 1, str); a.n = -a.n; return; end
if i <= numel(t) && strcmp(t{i}, '+'), [a, i] = pUnary(t, i + 1, str); return; end
[a, i] = pPower(t, i, str);
end

function [a, i] = pPower(t, i, str)
[a, i] = pPrimary(t, i, str);
if i <= numel(t) && strcmp(t{i}, '^')
    [e, i] = pUnary(t, i + 1, str);   % as in MATLAB: 2^-1 is allowed, -s^2 is -(s^2)
    if numel(e.n) ~= 1 || numel(e.d) ~= 1, error('Exponents must be numbers, e.g. (s+1)^2.'); end
    k = e.n/e.d;
    if k ~= round(k), error('Exponents must be whole numbers, e.g. (s+1)^2.'); end
    if k < 0, a = rDiv(struct('n', 1, 'd', 1), a); k = -k; end
    r = struct('n', 1, 'd', 1);
    for j = 1:k, r = rMul(r, a); end
    a = r;
end
end

function [a, i] = pPrimary(t, i, str)
if i > numel(t), pFail(str); end
tk = t{i}; i = i + 1;
v = str2double(tk);
if ~isnan(v), a = struct('n', v, 'd', 1);
elseif strcmp(tk, 's'), a = struct('n', [0 1], 'd', 1);
elseif strcmp(tk, '(')
    [a, i] = pExpr(t, i, str);
    if i > numel(t) || ~strcmp(t{i}, ')'), pFail(str); end
    i = i + 1;
else
    pFail(str);
end
end

% rational functions, ascending powers; a constant denominator is folded in
function p = pTrim(p)
k = find(p ~= 0, 1, 'last');
if isempty(k), p = 0; else, p = p(1:k); end
end
function c = pAdd(a, b)
n = max(numel(a), numel(b)); c = [a zeros(1, n - numel(a))] + [b zeros(1, n - numel(b))]; c = pTrim(c);
end
function r = rNorm(r)
r.n = pTrim(r.n); r.d = pTrim(r.d);
if numel(r.d) == 1 && r.d ~= 0, r.n = r.n/r.d; r.d = 1; end
end
function r = rAdd(a, b)
if isequal(a.d, b.d), r = rNorm(struct('n', pAdd(a.n, b.n), 'd', a.d));
else, r = rNorm(struct('n', pAdd(conv(a.n, b.d), conv(b.n, a.d)), 'd', conv(a.d, b.d))); end
end
function r = rMul(a, b)
r = rNorm(struct('n', conv(a.n, b.n), 'd', conv(a.d, b.d)));
end
function r = rDiv(a, b)
if all(b.n == 0), error('Division by zero in L(s).'); end
r = rNorm(struct('n', conv(a.n, b.d), 'd', conv(a.d, b.n)));
end
