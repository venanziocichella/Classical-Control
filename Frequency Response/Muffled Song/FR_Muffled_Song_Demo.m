function FR_Muffled_Song_Demo
%FR_MUFFLED_SONG_DEMO  Hear a Bode plot: play a song through G(s) in real time.
%
%   Run FR_Muffled_Song_Demo. A drum'n'bass / jungle track (synthesized by
%   FR_Make_Jungle_Track, or your own song) plays in a loop through
%       low-pass   G(s) = 1/(tau s + 1)
%       high-pass  G(s) = tau s/(tau s + 1)
%       resonant   G(s) = wn^2/(s^2 + 2 zeta wn s + wn^2)
%   Move the corner frequency fc = 1/(2 pi tau) and hear the highs (hats,
%   cymbals) disappear while the sub-bass stays: the song gets "muffled",
%   as if played behind a wall. The plots show |G(j w)| with the corner
%   marked and the live spectrum of the music before (gray) and after
%   (blue) the filter.
%
%   Keys: Space = play/pause, R = reset the song (back to the start), B = bypass (original),
%         Up/Down = move fc,
%         1/2/3 = low-pass / high-pass / resonant.
%
%   >>> TO USE YOUR OWN SONG, SET  songFile  IN THE BOX BELOW <<<

%% ===================== SETTINGS: EDIT HERE =====================
songFile = '';          % '' = synthesized jungle loop, or e.g. 'C:\music\mysong.mp3'
fc0      = 15000;       % initial corner frequency [Hz]
zeta0    = 0.1;         % initial damping ratio (resonant mode)
%% ===============================================================

here = fileparts(mfilename('fullpath'));
[song, fs, songName] = loadSong(songFile);

% Real-time audio needs the Audio Toolbox (audioDeviceWriter). Without it
% the demo re-filters the whole song when a control is released and plays
% it with audioplayer (works, but the sound changes only on release).
realtime = exist('audioDeviceWriter', 'class') == 8 && license('test', 'Audio_System_Toolbox');

% Palette and fonts as in the course figures (FigureScripts/matlab/me3600_plotstyle.m)
blue = [31 95 168]/255; red = [192 57 43]/255; gray = [0.6 0.6 0.6];

%% State
mode = 'low'; fcT = fc0; fcCur = fc0; zeta = zeta0;
bypass = false; vol = 0.8; playing = true; stopped = false;
frame = 1024; pos = 1;
[b, a] = FR_Filter_Coeffs(mode, fcCur, zeta, fs); zi = zeros(max(numel(a), numel(b)) - 1, 1);
wMix = 1; gLim = 1;                       % filtered/original mix and limiter gain
nfft = 4096; bufIn = zeros(nfft, 1); bufOut = bufIn;
win = 0.5 - 0.5*cos(2*pi*(0:nfft-1)'/nfft);
fAx = (0:nfft/2-1)'*fs/nfft; specIn = -100*ones(nfft/2, 1); specOut = specIn;
player = []; needRender = true; writer = []; yRender = []; yMix = []; inLoop = false;

%% UI
fig = uifigure('Name', 'Frequency Response: the muffled song', 'Position', [80 80 1180 700], ...
               'Color', 'w', 'WindowKeyPressFcn', @onKey, 'CloseRequestFcn', @onClose);
gl = uigridlayout(fig, [2 2]); gl.ColumnWidth = {'1x', 280}; gl.RowHeight = {'1x', '1x'};

axB = uiaxes(gl); axB.Layout.Row = 1; axB.Layout.Column = 1;
axS = uiaxes(gl); axS.Layout.Row = 2; axS.Layout.Column = 1;
for ax = [axB axS]
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    set(ax, 'XScale', 'log', 'XLim', [20 20000], 'XMinorGrid', 'on', 'FontSize', 13, ...
            'TickLabelInterpreter', 'latex', 'XTick', [20 50 100 200 500 1e3 2e3 5e3 1e4 2e4], ...
            'XTickLabel', {'20', '50', '100', '200', '500', '1k', '2k', '5k', '10k', '20k'});
    ax.Toolbar.Visible = 'off'; disableDefaultInteractivity(ax);
    xlabel(ax, 'Frequency $f$ (Hz)', 'Interpreter', 'latex');
end
fB = logspace(log10(10), log10(22000), 600);
hMag = plot(axB, fB, zeros(size(fB)), 'Color', blue, 'LineWidth', 2.5);
plot(axB, [20 20000], [-3 -3], ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 1);
hFc = plot(axB, [fc0 fc0], [-60 20], '--', 'Color', red, 'LineWidth', 1.5);
hFcTxt = text(axB, fc0, 12, '', 'Interpreter', 'latex', 'FontSize', 15, 'Color', red, ...
              'HorizontalAlignment', 'left');
hSlope = text(axB, 30, -45, '', 'Interpreter', 'latex', 'FontSize', 15, 'Color', [0.2 0.2 0.2]);
axB.YLim = [-60 20]; axB.YTick = -60:10:20;
ylabel(axB, '$|G(j\omega)|$ (dB)', 'Interpreter', 'latex');
hTitle = title(axB, '', 'Interpreter', 'latex', 'FontSize', 16);

hIn = plot(axS, fAx(2:end), specIn(2:end), 'Color', gray, 'LineWidth', 1);
hOut = plot(axS, fAx(2:end), specOut(2:end), 'Color', blue, 'LineWidth', 1.5);
hFc2 = plot(axS, [fc0 fc0], [-90 0], '--', 'Color', red, 'LineWidth', 1.5);
axS.YLim = [-90 0];
ylabel(axS, 'Music spectrum (dB)', 'Interpreter', 'latex');
legend(axS, [hIn hOut], {'original', 'after $G(s)$'}, 'Interpreter', 'latex', 'Location', 'southwest');

pn = uigridlayout(gl, [18 1]); pn.Layout.Row = [1 2]; pn.Layout.Column = 2;
pn.RowHeight = repmat({'fit'}, 1, 18); pn.RowSpacing = 6;
uilabel(pn, 'Text', 'Filter', 'FontWeight', 'bold', 'FontSize', 14);
ddMode = uidropdown(pn, 'Items', {'Low-pass   1/(τs+1)', 'High-pass   τs/(τs+1)', ...
                    'Resonant   ωn²/(s²+2ζωn s+ωn²)'}, ...
                    'ItemsData', {'low', 'high', 'res'}, 'Value', 'low', 'FontSize', 13, ...
                    'ValueChangedFcn', @(src, ~) setMode(src.Value));
uilabel(pn, 'Text', 'Corner frequency  fc = 1/(2πτ)', 'FontWeight', 'bold', 'FontSize', 14);
slFc = uislider(pn, 'Limits', log10([50 15000]), 'Value', log10(fc0), ...
                'MajorTicks', log10([50 100 200 500 1000 2000 5000 15000]), ...
                'MajorTickLabels', {'50', '100', '200', '500', '1k', '2k', '5k', '15k'}, ...
                'MinorTicks', [], 'ValueChangingFcn', @(~, ev) setFc(10^ev.Value, false), ...
                'ValueChangedFcn', @(src, ~) setFc(10^src.Value, true));
lblFc = uilabel(pn, 'Text', '', 'FontSize', 15);
gp = uigridlayout(pn, [1 4]); gp.Padding = [0 0 0 0]; gp.ColumnSpacing = 4;
for p = [15000 2000 500 150]
    uibutton(gp, 'Text', fmtHz(p), 'ButtonPushedFcn', @(~, ~) setFc(p, true));
end
lblZ = uilabel(pn, 'Text', '', 'FontWeight', 'bold', 'FontSize', 14);
slZ = uislider(pn, 'Limits', [0.02 1], 'Value', zeta0, 'Enable', 'off', ...
               'ValueChangingFcn', @(~, ev) setZeta(ev.Value, false), ...
               'ValueChangedFcn', @(src, ~) setZeta(src.Value, true));
cbBy = uicheckbox(pn, 'Text', 'Bypass: play the original  (B)', 'FontSize', 14, ...
                  'ValueChangedFcn', @(src, ~) setBypass(src.Value));
uilabel(pn, 'Text', 'Volume', 'FontWeight', 'bold', 'FontSize', 14);
uislider(pn, 'Limits', [0 1.5], 'Value', vol, 'MajorTicks', [0 0.5 1 1.5], ...
         'ValueChangingFcn', @(~, ev) setVol(ev.Value), 'ValueChangedFcn', @(src, ~) setVol(src.Value));
btPlay = uibutton(pn, 'Text', 'Pause  (Space)', 'FontSize', 14, 'ButtonPushedFcn', @(~, ~) togglePlay());
uibutton(pn, 'Text', 'Reset song  (R)', 'FontSize', 14, 'ButtonPushedFcn', @(~, ~) restartSong());
uibutton(pn, 'Text', 'Load song...', 'FontSize', 14, 'ButtonPushedFcn', @(~, ~) pickSong());
lblSong = uilabel(pn, 'Text', '', 'WordWrap', 'on', 'FontColor', [0.35 0.35 0.35]);
if realtime, msgAudio = 'Real-time audio (Audio Toolbox).';
else, msgAudio = 'No Audio Toolbox: the sound updates when you release a control.'; end
uilabel(pn, 'Text', msgAudio, 'WordWrap', 'on', 'FontColor', [0.35 0.35 0.35]);

refreshUI();

%% Audio engine
if realtime
    writer = audioDeviceWriter('SampleRate', fs, 'BufferSize', frame);
end
inLoop = true;
while ~stopped && isvalid(fig)
    if ~playing
        if ~realtime && ~isempty(player) && isplaying(player), pause(player); end
        pause(0.05); continue
    end
    if realtime
        % smooth the corner frequency (log scale) so moving the slider does not click
        fcNew = fcCur*(fcT/fcCur)^0.35;
        if abs(log(fcNew/fcCur)) > 1e-5
            fcCur = fcNew; [b, a] = FR_Filter_Coeffs(mode, fcCur, zeta, fs);
        end
        idx = mod(pos - 1 + (0:frame-1)', numel(song)) + 1; pos = idx(end) + 1;
        x = song(idx);
        [yf, zi] = filter(b, a, x, zi);
        w = linspace(wMix, ~bypass, frame)'; wMix = double(~bypass);   % crossfade bypass
        mix = w.*yf + (1 - w).*x;
        out = vol*mix;
        g = min(1, 0.98/max(max(abs(out)), eps));                      % peak limiter
        gNew = min(g, min(1, gLim*1.02));
        out = out.*linspace(gLim, gNew, frame)'; gLim = gNew;
        writer(out);
        bufIn = [bufIn(frame+1:end); x]; bufOut = [bufOut(frame+1:end); mix];
    else
        if needRender, render(); end
        if isempty(player), pause(0.05); continue; end
        if ~isplaying(player), resume(player); end
        k = player.CurrentSample;
        idx = mod(k - 1 + (-nfft+1:0)', numel(song)) + 1;
        bufIn = song(idx); bufOut = yMix(idx);
        pause(0.05);
    end
    updateSpectrum();
    drawnow limitrate;
end
inLoop = false;
cleanup();
if isvalid(fig), delete(fig); end

%% ------------------------------------------------------------ callbacks
    function setMode(m)
        mode = m; fcCur = fcT;
        [b, a] = FR_Filter_Coeffs(mode, fcCur, zeta, fs);
        zi = zeros(max(numel(a), numel(b)) - 1, 1);
        ddMode.Value = m; slZ.Enable = matlab.lang.OnOffSwitchState(strcmp(m, 'res'));
        needRender = true; refreshUI();
    end
    function setFc(f, released)
        fcT = min(max(f, 50), 15000); slFc.Value = log10(fcT);
        if released, needRender = true; end
        refreshUI();
    end
    function setZeta(z, released)
        zeta = z; [b, a] = FR_Filter_Coeffs(mode, fcCur, zeta, fs);
        if released, needRender = true; end
        refreshUI();
    end
    function setBypass(v)
        bypass = v; cbBy.Value = v; needRender = true; refreshUI();
    end
    function setVol(v)
        vol = v; needRender = true;
    end
    function restartSong()
        % back to the beginning of the song (filter settings are kept)
        pos = 1; zi = zeros(size(zi));
        specIn(:) = -100; specOut(:) = -100; bufIn(:) = 0; bufOut(:) = 0;
        if ~realtime && ~isempty(player)
            player.StopFcn = []; stop(player); player.StopFcn = @(~, ~) restart();
            if playing, play(player, 1); end
        end
    end
    function togglePlay()
        playing = ~playing;
        if playing, btPlay.Text = 'Pause  (Space)'; else, btPlay.Text = 'Play  (Space)'; end
    end
    function pickSong()
        [f, p] = uigetfile({'*.wav;*.mp3;*.m4a;*.flac;*.ogg;*.aiff', 'Audio files'}, 'Choose a song');
        if isequal(f, 0), return; end
        [s2, fs2, nm] = loadSong(fullfile(p, f));
        if fs2 ~= fs && realtime
            release(writer); writer = audioDeviceWriter('SampleRate', fs2, 'BufferSize', frame);
        end
        song = s2; fs = fs2; songName = nm; pos = 1;
        fAx = (0:nfft/2-1)'*fs/nfft; set([hIn hOut], 'XData', fAx(2:end));
        setMode(mode);
    end
    function onKey(~, ev)
        switch ev.Key
            case 'space', togglePlay();
            case 'r', restartSong();
            case 'b', setBypass(~bypass);
            case 'uparrow', setFc(fcT*2^(1/3), true);
            case 'downarrow', setFc(fcT/2^(1/3), true);
            case '1', setMode('low');
            case '2', setMode('high');
            case '3', setMode('res');
        end
    end
    function onClose(~, ~)
        % the audio loop notices this, releases the device and closes the window
        stopped = true;
        if ~inLoop, cleanup(); delete(fig); end
    end

%% ------------------------------------------------------------ helpers
    function refreshUI()
        [~, ~, G] = FR_Filter_Coeffs(mode, fcT, zeta, fs);
        set(hMag, 'YData', 20*log10(abs(G(1i*2*pi*fB))));
        set(hFc, 'XData', [fcT fcT]); set(hFc2, 'XData', [fcT fcT]);
        tau = 1/(2*pi*fcT);
        lblFc.Text = sprintf('fc = %s    τ = %s', fmtHz(fcT), fmtTau(tau));
        lblZ.Text = sprintf('Damping ratio  ζ = %.2f  (resonant)', zeta);
        switch mode
            case 'low'
                hTitle.String = '$G(s)=\displaystyle\frac{1}{\tau s+1}$';
                hFcTxt.String = sprintf('$f_c=%s$', texHz(fcT)); hSlope.String = '$-20$ dB/decade';
                hSlope.Position(1) = min(max(fcT*4, 400), 6000);
            case 'high'
                hTitle.String = '$G(s)=\displaystyle\frac{\tau s}{\tau s+1}$';
                hFcTxt.String = sprintf('$f_c=%s$', texHz(fcT)); hSlope.String = '$+20$ dB/decade';
                hSlope.Position(1) = 25;
            case 'res'
                hTitle.String = '$G(s)=\displaystyle\frac{\omega_n^2}{s^2+2\zeta\omega_n s+\omega_n^2}$';
                hFcTxt.String = sprintf('$f_n=%s$', texHz(fcT)); hSlope.String = '$-40$ dB/decade';
                hSlope.Position(1) = min(max(fcT*4, 400), 6000);
        end
        hFcTxt.Position(1) = fcT*1.08;
        if fcT > 5000, hFcTxt.HorizontalAlignment = 'right'; hFcTxt.Position(1) = fcT/1.08;
        else, hFcTxt.HorizontalAlignment = 'left'; end
        if bypass, set(hMag, 'LineStyle', ':'); else, set(hMag, 'LineStyle', '-'); end
        lblSong.Text = ['Song: ' songName];
    end
    function updateSpectrum()
        X = abs(fft(win.*bufIn))/(nfft/4); Y = abs(fft(win.*bufOut))/(nfft/4);
        sI = 20*log10(X(1:nfft/2) + 1e-6); sO = 20*log10(Y(1:nfft/2) + 1e-6);
        specIn = 0.7*specIn + 0.3*sI; specOut = 0.7*specOut + 0.3*sO;
        set(hIn, 'YData', smoothLog(specIn(2:end))); set(hOut, 'YData', smoothLog(specOut(2:end)));
    end
    function render()
        % offline path (no Audio Toolbox): filter the whole song, keep the position
        needRender = false; fcCur = fcT;
        [b, a] = FR_Filter_Coeffs(mode, fcCur, zeta, fs);
        if bypass, yMix = song; else, yMix = filter(b, a, song); end
        yRender = vol*yMix; pk = max(abs(yRender));
        if pk > 0.98, yRender = 0.98*yRender/pk; end
        k = 1; if ~isempty(player), k = player.CurrentSample; stop(player); end
        player = audioplayer(yRender, fs);
        player.StopFcn = @(~, ~) restart();
        play(player, max(1, min(k, numel(yRender))));
    end
    function restart()
        if ~stopped && playing && ~needRender && ~isempty(player) && isvalid(fig), play(player, 1); end
    end
    function cleanup()
        if ~isempty(writer), release(writer); writer = []; end
        if ~isempty(player), player.StopFcn = []; stop(player); end
    end

    function [y, fs, name] = loadSong(file)
        if isempty(file)
            file = fullfile(here, 'jungle_loop.wav');
            if ~exist(file, 'file'), FR_Make_Jungle_Track(file); end
            name = 'synthesized jungle loop (jungle_loop.wav)';
        else
            [~, n, e] = fileparts(file); name = [n e];
        end
        [y, fs] = audioread(file);
        y = mean(y, 2);                                   % mono
        y = 0.9*y/max(abs(y));
    end
end

function y = smoothLog(y)
% light smoothing of a spectrum so the plot is readable
y = movmean(y, 5);
end

function s = fmtHz(f)
if f >= 1000, s = sprintf('%.3g kHz', f/1000); else, s = sprintf('%.3g Hz', f); end
end

function s = texHz(f)
if f >= 1000, s = sprintf('%.3g\\,\\mathrm{kHz}', f/1000); else, s = sprintf('%.3g\\,\\mathrm{Hz}', f); end
end

function s = fmtTau(t)
if t >= 1e-3, s = sprintf('%.3g ms', 1e3*t); else, s = sprintf('%.3g µs', 1e6*t); end
end
