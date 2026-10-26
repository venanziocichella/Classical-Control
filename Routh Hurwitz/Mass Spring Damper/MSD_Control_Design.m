%% Mass Spring Damper - Routh-Hurwitz Control Design
% Mass spring damper from Chapter 1, m y'' + b y' + k y = u.

clear all
close all

m = 1;
b = 8.8;
k = 40;
s = tf('s');

G = 1/(m*s^2+b*s+k);
%% P controller
% With C(s) = K the characteristic equation is
% 
% $$P(s) = s^2 + 8.8s + 40 + K$$
% 
% Stable for any K > -40. However, the steady state error to step inputs is 
% 1/(1 + K/40), so we need an integrator.
%% PI controller
% $$C(s) = K\frac{s+a}{s}$$
% 
% The characteristic equation is s(s^2 + 8.8s + 40) + K(s + a) = 0, i.e.,
% 
% $$P(s) = s^3 + 8.8s^2 + (40 + K)s + Ka$$
% 
% Routh table:
% 
%   s^3 | 1                              40 + K
%   s^2 | 8.8                            K*a
%   s^1 | c11 = (8.8(40 + K) - Ka)/8.8
%   s^0 | c21 = K*a
% 
% We need K*a > 0 and 8.8(40 + K) - Ka > 0, i.e., K(a - 8.8) < 352.
% 
% - If a <= 8.8 the closed loop is stable for any K > 0.
% - If a > 8.8 there is an upper limit, K < 352/(a - 8.8). For example, with 
% a = 20 we need 0 < K < 31.4:

a = 20;
pole(minreal(25*(s+a)/s*G/(1+25*(s+a)/s*G)))   % K = 25: stable
pole(minreal(35*(s+a)/s*G/(1+35*(s+a)/s*G)))   % K = 35: unstable
%% 
% We choose a = 3 (no upper limit) and K = 100:

a = 3;
K = 100;
C = K*(s + a)/s;
pole(minreal(C*G/(1+C*G)))
step(minreal(C*G/(1+C*G)));
%% 
% To try this controller in MSD_Realtime_Demo, type this in its C(s) box
% 
%   100*(1 + 3/s)

[numC, denC] = tfdata(C, 'v')
