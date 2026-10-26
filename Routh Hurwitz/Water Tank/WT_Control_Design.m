%% Water tank - Routh-Hurwitz Control Design
% Water tank from Chapter 1. The input is the inflow Q_in and the output is 
% the water level h. The outflow is proportional to the level, Q_out = k h.

clear all
close all

A = 10;             % cross-section [m^2]
k = 0.5;            % outflow coefficient [m^2/s]
s = tf('s');

G = 1/(A*s + k);
%% PI controller
% A P controller leaves a steady state error, so we use a PI controller
% 
% $$C(s) = K\frac{s+a}{s}$$
% 
% The characteristic equation is s(As + k) + K(s + a) = 0, i.e.,
% 
% $$P(s) = As^2 + (k + K)s + Ka$$
% 
% Routh table:
% 
%   s^2 | A          K*a
%   s^1 | k + K      0
%   s^0 | K*a
% 
% With a > 0, the closed loop is stable for any K > 0 (in fact for any 
% K > -k = -0.5).
%% 
% Let's pick a = 0.05 (the zero cancels the slow pole of the tank, -k/A) and 
% K = 5:

a = 0.05;
K = 5;
C = K*(s + a)/s;
pole(minreal(C*G/(1+C*G)))
step(minreal(C*G/(1+C*G)));
%% 
% To try this controller in WT_Realtime_Demo, type this in its C(s) box
% 
%   5*(1 + 0.05/s)

[numC, denC] = tfdata(C, 'v')
