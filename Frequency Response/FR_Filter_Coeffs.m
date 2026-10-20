function [b, a, G] = FR_Filter_Coeffs(mode, fc, zeta, fs)
%FR_FILTER_COEFFS  Filter G(s) of the muffled-song demo and its discrete version.
%
%   [b, a, G] = FR_Filter_Coeffs(mode, fc, zeta, fs)
%     mode  'low'   G(s) = 1/(tau s + 1)                      (first-order low-pass)
%           'high'  G(s) = tau s/(tau s + 1)                  (first-order high-pass)
%           'res'   G(s) = wn^2/(s^2 + 2 zeta wn s + wn^2)    (second-order, resonant)
%     fc    corner (natural) frequency in Hz:  tau = 1/(2*pi*fc),  wn = 2*pi*fc
%     zeta  damping ratio (used by 'res' only)
%     fs    sampling rate in Hz
%   Returns the coefficients b, a of the discrete filter (for FILTER) and the
%   continuous-time G(s) as a function handle of s (for the Bode plot).
%
%   Discretization: Tustin (bilinear) transform with prewarping at fc, so
%   the digital filter has its corner exactly at fc, as G(s) does. This is
%   the same as c2d(G, 1/fs, c2dOptions('Method','tustin','PrewarpFrequency',2*pi*fc)).

tau = 1/(2*pi*fc); wn = 2*pi*fc;
K = tan(pi*fc/fs);                     % prewarped wn*T/2
switch mode
    case 'low'
        b = [K K]/(1 + K);
        a = [1 (K - 1)/(1 + K)];
        G = @(s) 1./(tau*s + 1);
    case 'high'
        b = [1 -1]/(1 + K);
        a = [1 (K - 1)/(1 + K)];
        G = @(s) tau*s./(tau*s + 1);
    case 'res'
        d = 1 + 2*zeta*K + K^2;
        b = K^2*[1 2 1]/d;
        a = [1, 2*(K^2 - 1)/d, (1 - 2*zeta*K + K^2)/d];
        G = @(s) wn^2./(s.^2 + 2*zeta*wn*s + wn^2);
    otherwise
        error('mode must be ''low'', ''high'' or ''res''');
end
end
