function RL_Animation_Demo
%RL_ANIMATION_DEMO  Root locus animation: the closed-loop poles move as K varies.
%
%   Run RL_Animation_Demo. The open loop is L(s) = K*N(s)/D(s) and the
%   closed loop has poles at the roots of D(s) + K*N(s) = 0.
%   - Type only N(s)/D(s) in the box (K stays in front), like C(s) in the
%     other demos: numbers, s, + - * / ^ and parentheses, e.g.
%     (s+2)/(s*(s+1)*(s+5)).
%   - Slide K (or type it). The plot shows the root locus (K from 0 to inf),
%     the open-loop poles (x) and zeros (o), and the closed-loop poles for
%     the current K (red dots), which move along the locus.
%   - Play sweeps K from 0 to the max of the slider. Click or drag along the
%     locus to set K at that point.
%   - Drag the empty plane to pan, mouse wheel to zoom. Keys: Space = play,
%     F = fit.
%
%   Base MATLAB R2021a or newer, no toolboxes.

%% ===================== SETTINGS: EDIT HERE =====================
L0 = '1/((s-1)*(s+5)*(s+10))';   % N(s)/D(s) shown at start: L(s) = K*N(s)/D(s)
%% ===============================================================

%% ======================= Engine (no need to edit below) =======================
locC = [122 63 176]/255; zeroC = [29 95 168]/255; poleC = [208 96 42]/255;
red = [180 56 42]/255; green = [47 125 50]/255; amber = [154 107 0]/255; gray = [0.45 0.45 0.45];
DEC = 4;                         % log slider: Kmax*10^-DEC ... Kmax (position 0 is K = 0)
Lsys = []; K = 0; Kmax = 100; logScale = true; clPoles = [];
V = struct('cx', 0, 'cy', 0, 'half', 5);
playing = false; drag = ''; dragLast = []; typing = false; locS = []; locK = [];

fig = uifigure('Name', 'Root locus: closed-loop poles as K varies', 'Position', [40 40 1300 800], 'Color', 'w', ...
    'WindowButtonDownFcn', @mouseDown, 'WindowButtonMotionFcn', @mouseMove, 'WindowButtonUpFcn', @mouseUp, ...
    'WindowScrollWheelFcn', @wheel, 'WindowKeyPressFcn', @keyPress);
gl = uigridlayout(fig, [1 2]); gl.ColumnWidth = {'1x', 330};
ax = uiaxes(gl); ax.Layout.Row = 1; ax.Layout.Column = 1;
hold(ax, 'on'); ax.Toolbar.Visible = 'off'; disableDefaultInteractivity(ax);
ax.TickLabelInterpreter = 'latex'; ax.FontSize = 11; box(ax, 'on'); grid(ax, 'on');
ax.DataAspectRatio = [1 1 1]; ax.XLimMode = 'manual'; ax.YLimMode = 'manual';
hRHP = patch(ax, [0 1e6 1e6 0], [-1e6 -1e6 1e6 1e6], [1 0.93 0.92], 'EdgeColor', 'none');
xline(ax, 0, 'Color', gray); yline(ax, 0, 'Color', gray);
hLoc = plot(ax, NaN, NaN, 'Color', locC, 'LineWidth', 2);
hZ = plot(ax, NaN, NaN, 'o', 'MarkerSize', 9, 'LineWidth', 2, 'Color', zeroC, 'MarkerFaceColor', 'w');
hP = plot(ax, NaN, NaN, 'x', 'MarkerSize', 11, 'LineWidth', 2.2, 'Color', poleC);
hCL = plot(ax, NaN, NaN, 'o', 'MarkerSize', 10, 'MarkerFaceColor', red, 'MarkerEdgeColor', 'w', 'LineWidth', 1.5);
hTitle = title(ax, '', 'Interpreter', 'latex', 'FontSize', 15);
xlabel(ax, '$\sigma$', 'Interpreter', 'latex'); ylabel(ax, '$j\omega$', 'Interpreter', 'latex');
for h = [hRHP hLoc hZ hP hCL], h.HitTest = 'off'; h.PickableParts = 'none'; end

% controls
pn = uigridlayout(gl, [16 1]); pn.Layout.Row = 1; pn.Layout.Column = 2;
pn.RowHeight = repmat({'fit'}, 1, 16); pn.RowSpacing = 6; pn.Scrollable = 'on';
uilabel(pn, 'Text', 'Open loop', 'FontWeight', 'bold', 'FontSize', 14);
g1 = uigridlayout(pn, [1 3]); g1.Padding = [0 0 0 0]; g1.ColumnWidth = {'fit', '1x', 'fit'};
uilabel(g1, 'Text', 'L(s) = K *', 'FontName', 'monospaced');
edL = uieditfield(g1, 'text', 'Value', L0, 'ValueChangingFcn', @(~, ~) setTyping(true), ...
    'ValueChangedFcn', @(~, ~) applyText());
uibutton(g1, 'Text', 'Apply', 'ButtonPushedFcn', @(~, ~) applyText());
uilabel(pn, 'WordWrap', 'on', 'FontColor', gray, 'Text', ...
    'Type N(s)/D(s) only: K stays in front. Numbers, s, + - * / ^ and parentheses, e.g. (s+2)/(s*(s+1)*(s+5)).');
lblErr = uilabel(pn, 'Text', '', 'WordWrap', 'on', 'FontColor', red);
lblL = uilabel(pn, 'Text', '', 'WordWrap', 'on', 'FontName', 'monospaced');
uilabel(pn, 'Text', 'Gain K', 'FontWeight', 'bold', 'FontSize', 14);
slK = uislider(pn, 'Limits', [0 1], 'Value', 0, 'MajorTicks', [], 'MinorTicks', [], ...
    'ValueChangingFcn', @(~, ev) sliderMoved(ev.Value), 'ValueChangedFcn', @(src, ~) sliderMoved(src.Value));
g2 = uigridlayout(pn, [1 4]); g2.Padding = [0 0 0 0]; g2.ColumnWidth = {'fit', '1x', 'fit', '1x'};
uilabel(g2, 'Text', 'K =');
edK = uieditfield(g2, 'numeric', 'Limits', [0 Inf], 'ValueDisplayFormat', '%.4g', 'ValueChangedFcn', @(src, ~) typedK(src.Value));
uilabel(g2, 'Text', 'max');
edKmax = uieditfield(g2, 'numeric', 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', 'ValueDisplayFormat', '%.4g', ...
    'ValueChangedFcn', @(src, ~) typedKmax(src.Value));
g3 = uigridlayout(pn, [1 2]); g3.Padding = [0 0 0 0]; g3.ColumnSpacing = 4;
btPlay = uibutton(g3, 'Text', 'Play (Space)', 'ButtonPushedFcn', @(~, ~) togglePlay());
ddScale = uidropdown(g3, 'Items', {'log slider', 'linear slider'}, 'ItemsData', {'log', 'linear'}, ...
    'ValueChangedFcn', @(src, ~) setScale(src.Value));
uilabel(pn, 'WordWrap', 'on', 'FontColor', gray, 'Text', ...
    'Play sweeps K from 0 to max. You can also click or drag along the locus to set K there.');
g4 = uigridlayout(pn, [1 2]); g4.Padding = [0 0 0 0]; g4.ColumnWidth = {'fit', 'fit'};
uilabel(g4, 'Text', 'Closed-loop poles', 'FontWeight', 'bold', 'FontSize', 14);
lblBadge = uilabel(g4, 'Text', '', 'FontWeight', 'bold');
lblCL = uilabel(pn, 'Text', '', 'WordWrap', 'on', 'FontName', 'monospaced');
uibutton(pn, 'Text', 'Fit (F)', 'ButtonPushedFcn', @(~, ~) fitView());
uilabel(pn, 'WordWrap', 'on', 'FontColor', gray, 'Text', 'Drag the empty plane to pan, wheel to zoom.');

applyText();

%% Loop
tFrame = tic;
while isvalid(fig)
    dWall = min(toc(tFrame), 0.05); tFrame = tic;
    if playing
        pos = slK.Value + dWall/8;        % 8 s from K = 0 to Kmax
        if pos >= 1, pos = 1; stopPlay(); end
        slK.Value = pos; setK(posToK(pos), true);
    end
    applyView();
    drawnow
    pause(max(0.001, 1/30 - toc(tFrame)));
end

%% ======================= L(s) and K =======================
    function applyText()
        typing = false;
        try
            str = regexprep(char(edL.Value), '^\s*L\(s\)\s*=?\s*', '');
            str = regexprep(str, '^\s*K\s*\*?', '');
            [num, den] = localParseL(str);
            setL(num, den);
            lblErr.Text = '';
        catch err
            lblErr.Text = [err.message ' The previous L(s) is still in use.'];
        end
    end
    function setTyping(v), typing = v; end
    function setL(num, den)
        num = stripLead(num); den = stripLead(den);
        if all(num == 0), error('N(s) is zero: the open loop must not be zero.'); end
        if all(den == 0), error('The denominator of L(s) is zero.'); end
        if numel(num) > numel(den), error('L(s) has more zeros than poles (improper): the root locus needs deg N <= deg D.'); end
        if numel(den) < 2, error('L(s) has no poles: type N(s)/D(s) with a D(s) of degree 1 or more.'); end
        Lsys = struct('num', num, 'den', den, 'zeros', cleanRoots(roots(num)), 'poles', cleanRoots(roots(den)));
        Lsys.R = max([1; abs(Lsys.poles); abs(Lsys.zeros)]);
        lblL.Text = sprintf('L(s) = K * %s\nopen-loop zeros (o): %s\nopen-loop poles (x): %s', ...
            localTfString(num, den), rootList(Lsys.zeros), rootList(Lsys.poles));
        s0 = Lsys.R*exp(1.75i);           % default slider range: |D/N| on the scale of the poles and zeros
        setKmax(niceUp(abs(polyval(den, s0))/max(abs(polyval(num, s0)), 1e-12)));
        set(hZ, 'XData', real(Lsys.zeros), 'YData', imag(Lsys.zeros));
        set(hP, 'XData', real(Lsys.poles), 'YData', imag(Lsys.poles));
        fitView();
        setK(Kmax*10^(-DEC/2), false);    % start in the middle of the log slider
    end
    function setKmax(v)
        Kmax = v; edKmax.Value = v;
        if ~isempty(Lsys), computeLocus(); end
    end
    function k = posToK(p)
        if p <= 0, k = 0;
        elseif logScale, k = Kmax*10^(-DEC*(1 - p));
        else, k = Kmax*p;
        end
    end
    function p = kToPos(k)
        if k <= 0, p = 0;
        elseif logScale, p = min(1, max(1e-3, 1 + log10(k/Kmax)/DEC));
        else, p = min(1, k/Kmax);
        end
    end
    function sliderMoved(p), stopPlay(); setK(posToK(p), true); end
    function typedK(v)
        stopPlay();
        if v > Kmax, setKmax(niceUp(v)); end
        setK(v, false);
    end
    function typedKmax(v), setKmax(v); setK(min(K, v), false); end
    function setScale(v), logScale = strcmp(v, 'log'); slK.Value = kToPos(K); end
    function setK(k, fromSlider)
        K = max(0, k);
        if ~fromSlider, slK.Value = kToPos(K); end
        edK.Value = K;
        cp = charPoly(Lsys.den, Lsys.num, K);
        if abs(cp(1)) < 1e-12*max(abs(cp)), cp = cp(2:end); end
        clPoles = cleanRoots(roots(cp));
        set(hCL, 'XData', real(clPoles), 'YData', imag(clPoles));
        tol = 1e-9*max(1, abs(clPoles));
        if any(real(clPoles) > tol), lblBadge.Text = 'unstable'; lblBadge.FontColor = red;
        elseif any(abs(real(clPoles)) <= tol), lblBadge.Text = 'marginal'; lblBadge.FontColor = amber;
        else, lblBadge.Text = 'stable'; lblBadge.FontColor = green;
        end
        r = clPoles(imag(clPoles) >= 0); [~, o] = sort(real(r), 'descend'); r = r(o);
        rows = cell(1, numel(r));
        for k2 = 1:numel(r)
            if imag(r(k2)) > 0
                rows{k2} = sprintf('%.4g ± %.4gj  (zeta = %.3g, wn = %.4g)', real(r(k2)), imag(r(k2)), -real(r(k2))/abs(r(k2)), abs(r(k2)));
            else
                rows{k2} = sprintf('%.4g', real(r(k2)));
            end
        end
        lblCL.Text = [sprintf('K = %.4g\n', K) strjoin(rows, newline)];
        hTitle.String = sprintf('Root locus of $D(s) + K N(s) = 0$, \\ $K = %.4g$', K);
    end

%% ======================= locus =======================
    function computeLocus()
        num = Lsys.num; den = Lsys.den; n = numel(den) - 1;
        step = 0.01*Lsys.R;
        prev = Lsys.poles; prevK = 0;
        S = Lsys.poles.'; KK = 0;          % rows: K values, columns: branches
        k0 = Kmax*1e-7; k1 = Kmax*1e5; N = 700;
        for kk = k0*(k1/k0).^((0:N)/N)
            r = rootsAt(kk);
            if isempty(r), continue; end
            r = matchRoots(prev, r);
            jump = max(abs(r - prev)./max(1, abs(r)/Lsys.R));   % relative to the size of the root
            if jump > step                    % refine near break-away points
                m = min(64, ceil(jump/step)); ka = prevK; if ka == 0, ka = k0/10; end
                for j = 1:m - 1
                    kj = ka*(kk/ka)^(j/m); rj = rootsAt(kj);
                    if ~isempty(rj), rj = matchRoots(prev, rj); S(end + 1, :) = rj.'; KK(end + 1) = kj; prev = rj; prevK = kj; end %#ok<AGROW>
                end
                r = matchRoots(prev, r);
            end
            S(end + 1, :) = r.'; KK(end + 1) = kk; prev = r; prevK = kk; %#ok<AGROW>
        end
        locS = S; locK = KK(:);
        X = [real(S); NaN(1, n)]; Y = [imag(S); NaN(1, n)];
        set(hLoc, 'XData', X(:), 'YData', Y(:));
        function r = rootsAt(k)
            p = charPoly(den, num, k);
            if abs(p(1)) < 1e-12*max(abs(p)), r = []; return; end
            r = roots(p);
            if numel(r) ~= n, r = []; end
        end
    end

%% ======================= view and mouse =======================
    function fitView()
        pts = [0; Lsys.poles; Lsys.zeros];
        if ~isempty(locS)
            ok = locK <= Kmax; z = locS(ok, :); z = z(abs(z) < 50*Lsys.R); pts = [pts; z(:)];
        end
        x0 = min(real(pts)); x1 = max(real(pts)); ym = max(abs(imag(pts)));
        asp = aspectOf();
        V.half = max(1, 1.15*max([(x1 - x0)/2/max(asp, 1), ym*min(asp, 1)]) + 0.3);
        V.cx = (x0 + x1)/2; V.cy = 0;
    end
    function a = aspectOf()
        p = ax.InnerPosition; a = max(p(3), 1)/max(p(4), 1);
    end
    function applyView()
        asp = aspectOf();
        xl = V.cx + V.half*max(asp, 1)*[-1 1]; yl = V.cy + V.half/min(asp, 1)*[-1 1];
        if ~isequal(ax.XLim, xl) || ~isequal(ax.YLim, yl), ax.XLim = xl; ax.YLim = yl; end
    end
    function u = pxSize()
        p = ax.InnerPosition; u = max(diff(ax.XLim)/p(3), diff(ax.YLim)/p(4));
    end
    function [inside, z] = pointIn()
        cp = ax.CurrentPoint; z = cp(1, 1) + 1i*cp(1, 2);
        inside = cp(1, 1) >= ax.XLim(1) && cp(1, 1) <= ax.XLim(2) && cp(1, 2) >= ax.YLim(1) && cp(1, 2) <= ax.YLim(2);
    end
    function [d, k] = nearestLocus(z)
        [d, i] = min(abs(locS(:) - z)); [row, ~] = ind2sub(size(locS), i); k = locK(row);
    end
    function mouseDown(~, ~)
        [in, z] = pointIn();
        if ~in || isempty(locS), return; end
        [d, k] = nearestLocus(z);
        if d < 12*pxSize()
            stopPlay(); drag = 'k'; pickK(k);
        else
            drag = 'pan'; dragLast = z;
        end
    end
    function mouseMove(~, ~)
        if isempty(drag), return; end
        [~, z] = pointIn();
        if strcmp(drag, 'k')
            [~, k] = nearestLocus(z); pickK(k);
        else
            V.cx = V.cx - real(z - dragLast); V.cy = V.cy - imag(z - dragLast);
            applyView(); [~, dragLast] = pointIn();
        end
    end
    function mouseUp(~, ~), drag = ''; end
    function pickK(k)
        if k > Kmax, setKmax(niceUp(k)); end
        setK(k, false);
    end
    function wheel(~, ev)
        [in, z] = pointIn();
        if ~in, return; end
        f = exp(ev.VerticalScrollCount*0.15);
        V.half = V.half*f; V.cx = real(z) + (V.cx - real(z))*f; V.cy = imag(z) + (V.cy - imag(z))*f;
    end
    function keyPress(~, ev)
        if typing, return; end
        switch ev.Key
            case 'space', togglePlay();
            case 'f', fitView();
        end
    end
    function stopPlay(), playing = false; btPlay.Text = 'Play (Space)'; end
    function togglePlay()
        playing = ~playing;
        if playing
            btPlay.Text = 'Pause (Space)';
            if slK.Value >= 1, slK.Value = 0; setK(0, true); end
        else
            btPlay.Text = 'Play (Space)';
        end
    end
end

%% ======================= helpers =======================
function p = charPoly(den, num, k)
% den(s) + k num(s), descending
n = max(numel(den), numel(num));
p = [zeros(1, n - numel(den)) den] + k*[zeros(1, n - numel(num)) num];
end

function b = matchRoots(a, b)
% reorder the roots b to follow the previous roots a (greedy, nearest pairs first)
a = a(:); b = b(:); n = numel(a);
D = abs(a - b.'); out = zeros(n, 1);
for k = 1:n
    [~, i] = min(D(:)); [ia, ib] = ind2sub([n n], i);
    out(ia) = b(ib); D(ia, :) = Inf; D(:, ib) = Inf;
end
b = out;
end

function v = niceUp(v)
% 1, 2, 5 x 10^k at or above v
if ~(v > 0) || ~isfinite(v), v = 100; return; end
e = floor(log10(v)); m = v/10^e;
if m <= 1, m = 1; elseif m <= 2, m = 2; elseif m <= 5, m = 5; else, m = 10; end
v = m*10^e;
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

function s = rootList(r)
r = r(imag(r) >= 0);
if isempty(r), s = 'none'; return; end
[~, o] = sort(real(r)); r = r(o); c = cell(1, numel(r));
for k = 1:numel(r)
    if imag(r(k)) > 0, c{k} = sprintf('%.4g ± %.4gj', real(r(k)), imag(r(k))); else, c{k} = sprintf('%.4g', real(r(k))); end
end
s = strjoin(c, ',  ');
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
help = 'Type N(s)/D(s) with numbers, s, + - * / ^ and parentheses only, e.g. 10*(s+2)/(s*(s+5))';
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
error('Could not read N(s)/D(s) = %s. Example: (s+2)/(s*(s+5))', str);
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
