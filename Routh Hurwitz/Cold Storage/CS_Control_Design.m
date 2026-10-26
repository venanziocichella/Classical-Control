%% Cold storage unit - Routh-Hurwitz Control Design
% Cold storage unit from Chapter 1:
% 
% $$\frac{dT}{dt} = -h(T - T_a) - P$$
% 
% The input is the cooling power P and the output is the temperature T. With 
% h = 1, the transfer function from P to T is G(s) = -1/(s+1); the ambient 
% temperature acts as a constant disturbance.

clear all
close all

h = 1;              % heat transfer constant [1/s]
s = tf('s');

G = -1/(s + h);
%% Integral controller
% More cooling power lowers the temperature, so the controller has a negative 
% gain. With the integral controller
% 
% $$C(s) = -\frac{K}{s}$$
% 
% the characteristic equation is s(s + 1) + K = 0, i.e.,
% 
% $$P(s) = s^2 + s + K$$
% 
%   s^2 | 1     K
%   s^1 | 1     0
%   s^0 | K
% 
% Stable for any K > 0.
%% PI controller
% With
% 
% $$C(s) = -K\frac{s+a}{s}$$
% 
% we get s(s + 1) + K(s + a) = 0, i.e.,
% 
% $$P(s) = s^2 + (1 + K)s + Ka$$
% 
%   s^2 | 1         K*a
%   s^1 | 1 + K     0
%   s^0 | K*a
% 
% With a > 0, stable for any K > 0. Note what happens if we forget the minus 
% sign, C(s) = K(s+a)/s: then P(s) = s^2 + (1 - K)s - Ka, and the last entry 
% -Ka is negative for any K > 0: unstable.
%% 
% Let's pick a = 1 and K = 2:

C = -2*(s + 1)/s;
pole(minreal(C*G/(1+C*G)))
step(minreal(C*G/(1+C*G)));
%% 
% To try this controller in CS_Realtime_Demo, type this in its C(s) box
% 
%   -2*(s+1)/s

[numC, denC] = tfdata(C, 'v')
