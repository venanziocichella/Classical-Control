%% Inverted pendulum - Routh-Hurwitz Control Design
% Inverted pendulum linearized around the upright position:
% theta'' = (g/L) theta + u.

clear all
close all

g = 9.8;
L = 1;
s = tf('s');

G = 1/(s^2-g/L); 
%% P controller
% With C(s) = K the characteristic equation is
% 
% $$P(s) = s^2 + K - 9.8$$
% 
% The coefficient of s is zero: no K makes the closed loop asymptotically 
% stable.
%% PD controller
% $$C(s) = K(1 + 0.1s)$$
% 
% $$P(s) = s^2 + 0.1Ks + K - 9.8$$
% 
%   s^2 | 1          K - 9.8
%   s^1 | 0.1K       0
%   s^0 | K - 9.8
% 
% Stable for K > 9.8. However, the steady state error to step inputs is not 
% zero, so we add an integrator.
%% PID controller
% $$C(s) = K\left(1 + 0.2s + \frac{0.05}{s}\right) = K\frac{0.2s^2 + s + 0.05}{s}$$
% 
% The characteristic equation is s(s^2 - 9.8) + K(0.2s^2 + s + 0.05) = 0, i.e.,
% 
% $$P(s) = s^3 + 0.2Ks^2 + (K - 9.8)s + 0.05K$$
% 
% Routh table:
% 
%   s^3 | 1                                     K - 9.8
%   s^2 | 0.2K                                  0.05K
%   s^1 | c11 = (0.2K(K - 9.8) - 0.05K)/(0.2K) = K - 10.05
%   s^0 | c21 = 0.05K
% 
% The closed loop is stable for K > 10.05. Let's check it:

pole(minreal(10*(1+0.2*s+0.05/s)*G/(1+10*(1+0.2*s+0.05/s)*G)))    % K = 10: unstable
pole(minreal(10.1*(1+0.2*s+0.05/s)*G/(1+10.1*(1+0.2*s+0.05/s)*G)))  % K = 10.1: stable
%% 
% We choose K = 11.8:

K = 11.8;
C = K*(1 + 0.2*s + 0.05/s);
step(minreal(C*G/(1+C*G)));
%% 
% The PID is not proper, so in the demo we add a fast pole at -100. It does 
% not change the result much:

C = C/(s/100+1);
pole(minreal(C*G/(1+C*G)))
%% 
% To try this controller in IP_Realtime_Demo, type this in its C(s) box
% 
%   11.8*(1 + 0.2*s + 0.05/s)/(s/100+1)

[numC, denC] = tfdata(C, 'v')
