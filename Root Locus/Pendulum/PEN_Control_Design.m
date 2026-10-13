%% Damped pendulum - Control Design
% Damped pendulum from Chapter 1, linearized around the hanging position 
% (theta = 0). The input u is a torque scaled by the inertia and the output is 
% the angle theta.

clear all
close all

k = 1;              % viscous damping [1/s]
g = 9.8;            % gravity [m/s^2]
L = 1;              % length [m]
s = tf('s');

G = 1/(s^2 + k*s + g/L);
%% 
% Plot the root locus of G:

rlocus(G);
%% 
% The open loop poles are at -0.5 +/- 3.1j: the pendulum is stable, but very 
% lightly damped. With C(s) = K the poles move vertically, so the response 
% becomes even more oscillatory, and there is a steady state error:
% 
% $$\frac{1}{1+L(0)} = \frac{1}{1+K/9.8}$$

K = 20;
step(minreal(K*G/(1+K*G)));
%% 
% To have zero steady state error we need an integrator, and to damp the 
% oscillations we need zeros that attract the root locus to the left. Let's 
% try a PID controller with zeros at -2 and -3, and a fast pole at -100 that 
% makes it proper (filtered derivative):
% 
% $$C(s) = K\frac{(s+2)(s+3)}{s(s/100+1)}$$

C = (s+2)*(s+3)/(s*(s/100+1));
rlocus(C*G);
%% 
% With a gain of 10 the closed loop poles are at about -1.3, -5.2 +/- 5.1j, 
% and a fast one at -89.

K = 10;
C = K*C;
pzplot(minreal(C*G/(1+C*G)));
%% 
% The step response now has zero steady state error and little overshoot

step(minreal(C*G/(1+C*G)));
%% 
% To try this controller in PEN_Realtime_Demo, set
% 
%   C = 10*(s+2)*(s+3)/(s*(s/100+1));

[numC, denC] = tfdata(C, 'v')
