%% Cold storage unit - Routh-Hurwitz Control Design
% Cold storage unit from Chapter 1:
% 
% $$\frac{dT}{dt} = -h(T - T_a) - P$$
% 
% where P >= 0 is the cooling power. More cooling lowers the temperature, so 
% by convention (and without loss of generality) we take as input u = -P. Then
% 
% $$\frac{dT}{dt} = -h(T - T_a) + u$$
% 
% and, with h = 1, the transfer function from u to T is G(s) = 1/(s+1), with 
% a positive gain. The ambient temperature acts as a constant disturbance. The 
% cooling power applied by the AC is P = -u.

clear all
close all

h = 1;              % heat transfer constant [1/s]
s = tf('s');

G = 1/(s + h);
%% Integral controller
% With the integral controller
% 
% $$C(s) = \frac{K}{s}$$
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
% $$C(s) = K\frac{s+a}{s}$$
% 
% we get s(s + 1) + K(s + a) = 0, i.e.,
% 
% $$P(s) = s^2 + (1 + K)s + Ka$$
% 
%   s^2 | 1         K*a
%   s^1 | 1 + K     0
%   s^0 | K*a
% 
% With a > 0, stable for any K > 0.
%% 
% Let's pick a = 1 and K = 2:

C = 2*(s + 1)/s;
pole(minreal(C*G/(1+C*G)))
step(minreal(C*G/(1+C*G)));
%% 
% To try this controller in CS_Realtime_Demo, type this in its C(s) box
% 
%   2*(s+1)/s

[numC, denC] = tfdata(C, 'v')
