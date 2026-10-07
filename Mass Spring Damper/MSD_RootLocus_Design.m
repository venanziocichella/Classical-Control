%% Mass Spring Damper - Controller Design with the Root Locus
% This script designs a position controller for the mass-spring-damper used in
% MSD_Realtime_Demo.m. With mass m, damping b and stiffness k, the transfer
% function from the applied force u to the position x is
%
% $$G(s) = \frac{1}{ms^2 + bs + k}$$
%
% The goal is to move the mass to a target position r quickly, with little
% overshoot and zero steady-state error.

%%
% Initialize the environment

clear all;
close all;
%%
% Define the Laplace variable and the system

s = tf('s');
m = 1;
b = 8.8;
k = 40;
G = 1/(m*s^2 + b*s + k);
%%
% The open-loop poles are at -4.4 +/- 4.54j (natural frequency 6.3 rad/s,
% damping ratio 0.7). The system is already stable, but a force u only moves
% the mass by u/k at steady state.

pole(G)
dcgain(G)
%%
% Plot root locus with C = K (proportional control)

C = 1;
figure;
rlocus(C*G);
sgrid(0.7, []);
title('Root Locus with C=K');
%%
% Increasing K moves the poles straight up: the real part stays at -4.4, so
% the response gets more oscillatory but not faster to settle. The closed loop is
%
% $$\frac{K}{s^2 + 8.8s + 40 + K}$$
%
% whose DC gain K/(40+K) is less than 1. Proportional control always leaves a
% steady-state error.

K = 10;
GCL = minreal(feedback(K*G, 1));
figure;
step(GCL);
title('Step Response for K=10');
%%

K = 200;
GCL = minreal(feedback(K*G, 1));
figure;
step(GCL);
title('Step Response for K=200');
%%
% Larger K means a smaller error, but more oscillation. To remove the error
% completely we need an integrator.
%%
% Design with a PI controller
%
% $$C(s) = k_p + \frac{k_i}{s} = K\frac{s+a}{s}$$
%
% We place the zero at a = 3, slightly to the right of the open-loop poles.

C = (s+3)/s;
figure;
rlocus(C*G);
sgrid(0.7, []);
title('Root Locus with PI Controller (zero at -3)');
%%
% The integrator pole at the origin moves left toward the zero at -3, while the
% complex pair moves up and becomes less damped. A small K gives a slow
% closed-loop pole near the origin, and a large K gives oscillations. Let's
% compare K = 10 and K = 100.

K = 10;
C = K*(s+3)/s;
GCL = minreal(feedback(C*G, 1));
pole(GCL)
figure;
step(GCL);
title('Step Response with PI Controller, K=10');
%%

K = 100;
C = K*(s+3)/s;
GCL = minreal(feedback(C*G, 1));
pole(GCL)
figure;
step(GCL);
title('Step Response with PI Controller, K=100');
%%
% Both reach the target (zero steady-state error). With K = 10 the slow pole
% near -0.67 makes the response creep toward the target. With K = 100 it is
% faster, but the complex poles have a damping ratio of about 0.3, so it
% overshoots.
%%
% Design with a PID controller. Two zeros let us shape the locus further. We
% place them at -4 and -6, and add a fast pole at -100 to make the controller
% proper (filtered derivative):
%
% $$C(s) = K\frac{(s+4)(s+6)}{s(s/100+1)}$$

C = (s+4)*(s+6)/(s*(s/100+1));
figure;
rlocus(C*G);
sgrid(0.7, []);
title('Root Locus with PID Controller (zeros at -4 and -6)');
%%
% Now the branches are pulled toward the zeros and far to the left. With
% K = 20 all closed-loop poles are real, so there is no overshoot. The slowest
% pole is near -2.9.

K = 20;
C = K*(s+4)*(s+6)/(s*(s/100+1));
GCL = minreal(feedback(C*G, 1));
pole(GCL)
figure;
step(GCL);
title('Step Response with PID Controller, K=20');
%%
% Finally, the response to a constant disturbance force d (for example a
% student pushing on the joystick) is G/(1+CG). The integrator brings the
% mass back to the target.

GD = minreal(G/(1 + C*G));
figure;
step(GD);
title('Response of x to a Step Disturbance Force');
%%
% To try these controllers in real time, open MSD_Realtime_Demo.m and set
%
%   C = 100*(s+3)/s;                          % PI from MSD_Control_Design.m
%   C = 20*(s+4)*(s+6)/(s*(s/100+1));         % PID from this script
