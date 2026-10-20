function [y, fs] = FR_Make_Jungle_Track(outFile)
%FR_MAKE_JUNGLE_TRACK  Synthesize an original drum'n'bass / reggae-jungle loop.
%
%   [y, fs] = FR_Make_Jungle_Track          returns the track (mono, 44.1 kHz)
%   FR_Make_Jungle_Track('jungle_loop.wav')  also writes it to a .wav file
%
%   The track is built from scratch (no samples), about 22 s long at 170 BPM,
%   and is designed to have energy at both ends of the audible spectrum so
%   that a low-pass or high-pass filter is easy to hear:
%     - sub-bass and a detuned "reese" bassline        (~35-110 Hz)
%     - kick drum                                       (~45-120 Hz)
%     - chopped breakbeat snare with ghost notes        (~200 Hz-8 kHz)
%     - offbeat reggae "skank" chord stabs              (~300 Hz-4 kHz)
%     - 16th-note hi-hats, ride and crash cymbals       (~5-16 kHz)
%     - a dub siren and an air-horn hit                 (~0.5-6 kHz)

fs = 44100;
bpm = 170;
step = 60/bpm/4;                 % one 16th note [s]
nBars = 16;
nSteps = 16*nBars;
N = round((nSteps*step + 1.5)*fs);   % + tail for the last crash
y = zeros(N, 1);
rng(3600);                       % reproducible noise

%% Drum sounds
kick  = drum_kick(fs);
snare = drum_snare(fs, 1.0);
ghost = 0.30*drum_snare(fs, 0.6);
hat   = drum_hat(fs, 0.035);
ohat  = drum_hat(fs, 0.22);
ride  = drum_ride(fs);
crash = drum_crash(fs);

% Chopped "amen-style" break, 16 steps per bar (1 = downbeat)
K  = [1 0 0 0  0 0 0 0  0 0 1 0  0 0 0 0];   % kick
Sn = [0 0 0 0  1 0 0 0  0 0 0 0  1 0 0 0];   % snare
G  = [0 0 0 1  0 0 0 1  0 1 0 0  0 0 0 1];   % ghost snares
Kv = [1 0 1 0  0 0 0 0  0 1 0 0  0 0 1 0];   % variation (every 4th bar)
Sv = [0 0 0 0  1 0 0 1  0 0 0 0  1 0 1 1];
for bar = 0:nBars-1
    if mod(bar, 4) == 3, k = Kv; sn = Sv; else, k = K; sn = Sn; end
    for st = 1:16
        t0 = (bar*16 + st - 1)*step;
        if k(st),  y = add(y, 1.00*kick, t0, fs); end
        if sn(st), y = add(y, 0.80*snare, t0, fs); end
        if G(st) && ~sn(st), y = add(y, ghost, t0, fs); end
        % hats on every 16th, accented on the 8ths; open hat before the snare
        if st == 12, y = add(y, 0.22*ohat, t0, fs);
        else, y = add(y, (0.10 + 0.08*(mod(st, 2) == 1))*hat, t0, fs); end
        if mod(st, 4) == 1 && bar >= 4, y = add(y, 0.10*ride, t0, fs); end
    end
    if mod(bar, 4) == 0, y = add(y, 0.30*crash, bar*16*step, fs); end
end

%% Bass: sub sine + detuned "reese" saws, half-time pattern (2 bars per root)
roots_ = [41.20 41.20 49.00 36.71 41.20 41.20 55.00 49.00];   % E1 E1 G1 D1 E1 E1 A1 G1 [Hz]
bass = zeros(N, 1);
for bar = 0:nBars-1
    f0 = roots_(mod(floor(bar/2), numel(roots_)) + 1);
    for st = 1:16
        % bass notes on 1, the "and" of 2, and 3 of each bar (tied, reggae feel)
        if ~any(st == [1 7 9 15]), continue; end
        len = 6*step; if st == 15 || st == 7, len = 2*step; end
        n0 = round((bar*16 + st - 1)*step*fs) + 1;
        n = (0:round(len*fs) - 1)';
        env = min(1, n/(0.004*fs)) .* exp(-n/(0.9*fs)) .* min(1, (numel(n) - n)/(0.01*fs));
        sub = sin(2*pi*f0*n/fs);                                    % pure sub at f0
        reese = saw(2*pi*f0*n/fs) + saw(2*pi*1.012*f0*n/fs);        % detuned saws, rich harmonics
        idx = n0 + n; idx = idx(idx <= N); m = numel(idx);
        bass(idx) = bass(idx) + env(1:m).*(0.55*sub(1:m) + 0.18*reese(1:m));
    end
end
bass = biquad(bass, 'low', 180, 0.7, fs);     % keep the bass in the bass range
y = y + bass;

%% Reggae "skank": offbeat chord stabs (E minor: E4 G4 B4 + octave)
chord = [329.63 392.00 493.88 659.26];
nS = round(0.12*fs); n = (0:nS-1)';
stab = zeros(nS, 1);
for f = chord, stab = stab + sign(sin(2*pi*f*n/fs)) .* 0.5 + sin(2*pi*2*f*n/fs).*0.3; end
stab = stab .* exp(-n/(0.035*fs));
stab = biquad(stab, 'high', 250, 0.7, fs);
stab = 0.24*stab/max(abs(stab));
for bar = 0:nBars-1
    for st = [3 7 11 15]
        y = add(y, stab, (bar*16 + st - 1)*step, fs);
    end
end

%% Dub siren (bars 7 and 15) and air horn (bar 11)
for bar = [7 15]
    nS = round(8*step*fs); n = (0:nS-1)';
    f = 900 + 500*sin(2*pi*6*n/fs) + 300*n/nS;                % wobbling pitch
    sir = sin(2*pi*cumsum(f)/fs) .* min(1, n/(0.02*fs)) .* exp(-n/(1.2*fs));
    y = add(y, 0.10*sir, bar*16*step, fs);
end
for k = 0:2
    nS = round(0.18*fs); n = (0:nS-1)';
    horn = zeros(nS, 1);
    for f = [466.16 587.33 698.46], horn = horn + saw(2*pi*f*n/fs); end
    horn = horn .* min(1, n/(0.005*fs)) .* exp(-n/(0.12*fs));
    y = add(y, 0.05*horn, (11*16 + 4*k)*step, fs);
end

%% Master: gentle soft clip and normalize to -1 dBFS
y = y(1:round(nSteps*step*fs));          % exact loop length (seamless looping)
y = tanh(1.2*y)/tanh(1.2);
y = 10^(-1/20) * y / max(abs(y));

if nargin > 0 && ~isempty(outFile)
    audiowrite(outFile, y, fs);
    fprintf('wrote %s (%.1f s, %d Hz)\n', outFile, numel(y)/fs, fs);
end
end

%% ---------------------------------------------------------------- sounds
function x = drum_kick(fs)
n = (0:round(0.35*fs) - 1)';
f = 45 + 75*exp(-n/(0.03*fs));                     % pitch drop 120 -> 45 Hz
x = sin(2*pi*cumsum(f)/fs) .* exp(-n/(0.12*fs));
click = randn(size(n)) .* exp(-n/(0.002*fs));
x = x + 0.3*biquad(click, 'high', 2000, 0.7, fs);
end

function x = drum_snare(fs, bright)
n = (0:round(0.25*fs) - 1)';
tone = sin(2*pi*190*n/fs) .* exp(-n/(0.04*fs));
nz = biquad(randn(size(n)), 'high', 1200, 0.7, fs) .* exp(-n/(0.07*fs));
x = 0.6*tone + bright*0.8*nz;
end

function x = drum_hat(fs, dec)
n = (0:round(5*dec*fs) - 1)';
x = biquad(randn(size(n)), 'high', 7000, 0.7, fs);
x = biquad(x, 'high', 7000, 0.7, fs) .* exp(-n/(dec*fs));
end

function x = drum_ride(fs)
n = (0:round(1.2*fs) - 1)';
x = zeros(size(n));
for f = [3150 4270 5530 6810 8370], x = x + sin(2*pi*f*n/fs + 2*pi*rand); end
x = (0.4*x/5 + 0.6*biquad(randn(size(n)), 'high', 5000, 0.7, fs)) .* exp(-n/(0.35*fs));
end

function x = drum_crash(fs)
n = (0:round(1.6*fs) - 1)';
x = biquad(randn(size(n)), 'high', 4000, 0.7, fs) .* exp(-n/(0.5*fs));
end

%% ---------------------------------------------------------------- tools
function s = saw(ph)
s = 2*mod(ph/(2*pi), 1) - 1;
end

function y = add(y, x, t0, fs)
n0 = round(t0*fs) + 1;
m = min(numel(x), numel(y) - n0 + 1);
if m > 0, y(n0:n0 + m - 1) = y(n0:n0 + m - 1) + x(1:m); end
end

function y = biquad(x, type, fc, Q, fs)
% Second-order low/high-pass (bilinear transform, prewarped at fc)
w0 = 2*pi*fc/fs; al = sin(w0)/(2*Q); c = cos(w0);
if strcmp(type, 'low'), b = [(1 - c)/2, 1 - c, (1 - c)/2];
else, b = [(1 + c)/2, -(1 + c), (1 + c)/2]; end
a = [1 + al, -2*c, 1 - al];
y = filter(b/a(1), a/a(1), x);
end
