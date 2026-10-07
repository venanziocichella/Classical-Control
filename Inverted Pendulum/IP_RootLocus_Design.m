%% Inverted Pendulum - Controller Design with the Root Locus
% This script designs a controller for the pendulum used in IP_Realtime_Demo.m.
% Linearizing theta'' = (g/L)*sin(theta) + u around the upright position gives
%
% $$G(s) = \frac{1}{s^2 - g/L}$$
%
% where theta is the angle from vertical and u is the control input.

%%
% Initialize the environment

clear all;
close all;
%%
% Define the Laplace variable and the system

s = tf('s');
g = 9.8;
L = 1;
G = 1/(s^2 - g/L);
%%
% The open-loop poles are at +/- sqrt(g/L) = +/- 3.13. The pole in the right
% half plane is why the pendulum falls over.

pole(G)
%%
% Plot root locus with C = K (proportional control)

C = 1;
figure;
rlocus(C*G);
title('Root Locus with C=K');
%%
% For small K one closed-loop pole stays in the right half plane. For large K
% the two poles meet at the origin and move up and down the imaginary axis.
% No proportional gain makes the pendulum stable: at best it oscillates
% forever. We need to pull the root locus to the left by adding a zero.
%%
% Design with a PD controller, C = kp + kd*s = kd*(s + kp/kd).
% The zero at -kp/kd = -2 attracts the root locus into the left half plane.

kp = 2;
kd = 1;
C = kp + kd*s;
figure;
rlocus(C*G);
title('Root Locus with PD Controller (zero at -2)');
%%
% The closed-loop characteristic equation is s^2 + K*s + (2K - 9.8) = 0,
% so we need K > 4.9 for stability. Let's try K = 10.

K = 10;
C = K*(kp + kd*s);
GCL = minreal(feedback(C*G, 1));
pole(GCL)
figure;
step(GCL);
title('Step Response with PD Controller, K=10');
%%
% The pendulum is now stable, but the system is still type 0, so a step in
% the reference leaves a steady-state error. The final value is
%
% $$\lim_{s \to 0} \frac{C(s)G(s)}{1+C(s)G(s)} = \frac{2K}{2K - 9.8}$$
%
% which is different from 1. A constant disturbance torque (for example a
% student pushing on the joystick) would also leave the pendulum tilted.

dcgain(GCL)
%%
% Design with a PID controller (the I is for zero steady-state error).
% We place the two controller zeros at -2 and -3:
%
% $$C(s) = K\frac{(s+2)(s+3)}{s}$$
%
% The integrator adds a pole at the origin, and the two zeros pull the
% branches into the left half plane.

C = (s+2)*(s+3)/s;
figure;
rlocus(C*G);
sgrid(0.7, []);
title('Root Locus with PID Controller (zeros at -2 and -3)');
%%
% The characteristic equation is s^3 + K s^2 + (5K - 9.8) s + 6K = 0. From
% the Routh array the loop is stable for K > 3.16. With K = 10 all closed-loop
% poles are well damped (damping ratio around 0.8, line drawn above).

K = 10;
C = K*(s+2)*(s+3)/s;
GCL = minreal(feedback(C*G, 1));
pole(GCL)
figure;
step(GCL);
title('Step Response with PID Controller, K=10');
%%
% The step response now goes to 1: zero steady-state error. The overshoot
% comes from the two controller zeros, not from poorly damped poles.
%%
% A pure PID is not proper (more zeros than poles), so it cannot be built as
% is. We add a fast pole at -100 that filters the derivative action. Being far
% to the left, it barely changes the root locus near the dominant poles.

C = K*(s+2)*(s+3)/(s*(s/100+1));
GCL = minreal(feedback(C*G, 1));
pole(GCL)
figure;
step(GCL);
title('Step Response with Filtered PID Controller');
%%
% Finally, let's look at how the controller rejects a disturbance d that enters
% together with u (for example a push from the joystick). The transfer
% function from d to theta is G/(1+CG):

GD = minreal(G/(1 + C*G));
figure;
step(GD);
title('Response of theta to a Step Disturbance');
%%
% Thanks to the integrator, the angle returns to zero even under a constant
% push.
%
% To try this controller in real time, open IP_Realtime_Demo.m and set
%
%   C = 10*(s+2)*(s+3)/(s*(s/100+1));
