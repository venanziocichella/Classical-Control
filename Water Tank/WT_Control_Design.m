%% Water tank - Control Design
% Water tank from Chapter 1. The input is the inflow Q_in and the output is 
% the water level h. The outflow is proportional to the level, Q_out = k h.

clear all
close all

A = 10;             % cross-section [m^2]
k = 0.5;            % outflow coefficient [m^2/s]
s = tf('s');

G = 1/(A*s + k);
%% 
% Plot the root locus of G:

rlocus(G);
%% 
% G has one pole at -k/A = -0.05, so the open loop tank is very slow (time 
% constant 20 s). With C(s) = K the closed loop pole moves to -(k + K)/A, so a 
% larger K makes the tank faster, but there is a steady state error:
% 
% $$\frac{1}{1+L(0)} = \frac{1}{1+K/k}$$

K = 5;
step(minreal(K*G/(1+K*G)));
%% 
% To remove the steady state error we add an integrator (PI controller)
% 
% $$C(s) = k_p + \frac{k_i}{s} = k_p \frac{s + k_i/k_p}{s}$$
% 
% A simple choice is to place the zero of the PI controller on top of the pole 
% of the tank, k_i/k_p = 0.05, so that the loop becomes L(s) = k_p/(A s):

C = (s + 0.05)/s;
rlocus(C*G);
%% 
% The closed loop pole is at -k_p/A. With k_p = 5 it is at -0.5 (time 
% constant 2 s, ten times faster than the open loop tank).

C = 5*C;
pzplot(minreal(C*G/(1+C*G)));
step(minreal(C*G/(1+C*G)));
%% 
% Note that the inflow cannot be negative: if the level is above the target 
% the controller can only close the valve and wait for the tank to drain.
% 
% To try this controller in WT_Realtime_Demo, set
% 
%   C = 5*(1 + 0.05/s);

[numC, denC] = tfdata(C, 'v')
