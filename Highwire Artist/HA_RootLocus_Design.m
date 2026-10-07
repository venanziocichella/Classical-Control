%% Highwire Artist - Controller Design with the Root Locus
% This script designs a controller for the highwire artist used in
% HA_Realtime_Demo.m. The artist (mass M, center of mass at height L) balances
% on the wire by applying a torque u to a pole (mass m, inertia J). Linearizing
% around the upright position, the transfer function from the torque u to the
% tilt angle theta is
%
% $$G(s) = \frac{6/(6ml^2+2ML^2)}{s^2 - 3g(2ml+ML)/(6ml^2+2ML^2)}$$

%%
% Initialize the environment

clear all;
close all;
%%
% Define the Laplace variable and the system

s = tf('s');
J = 10.4;
l = 1.5;
L = 2;
m = 5;
M = 75;
g = 9.81;
G = 6/(6*m*l^2+2*M*L^2)/(s^2-3*g*(2*m*l+M*L)/(6*m*l^2+2*M*L^2));
%%
% Like any inverted pendulum, the system has one pole in the right half plane
% (at about +2.7 rad/s). Note also the very small gain: a torque of about 800
% N m gives the same angular acceleration as 1 rad of tilt does through gravity.
% Expect large controller gains.

pole(G)
dcgain(G)
%%
% Plot root locus with C = K (proportional control)

C = 1;
figure;
rlocus(C*G);
title('Root Locus with C=K');
%%
% Proportional control cannot stabilize the artist. For small K one pole stays
% in the right half plane. For large K both poles end up on the imaginary
% axis, which means an undamped oscillation. We need a zero to bend the locus
% to the left.
%%
% Design with a PD controller: C = K*(s + 2), a zero at -2

C = s + 2;
figure;
rlocus(C*G);
title('Root Locus with PD Controller (zero at -2)');
%%
% The PD controller stabilizes the loop for K > 405. But a pure derivative
% amplifies noise and is not proper. In practice we use a lead compensator,
% a PD with a pole further to the left:
%
% $$C(s) = K\frac{s+2}{s+5}$$

C = (s+2)/(s+5);
figure;
rlocus(C*G);
sgrid(0.5, []);
title('Root Locus with Lead Compensator (zero at -2, pole at -5)');
%%
% With the lead pole at -5, the characteristic equation is
% s^3 + 5s^2 + (Kb - 7.28)s + (2Kb - 36.4) = 0 with b = 6/(6ml^2+2ML^2), so the
% loop is stable for K > 2024. On the root locus we pick K = 3000. That puts the
% complex poles near a damping ratio of 0.5 (line drawn above), with a slower
% real pole near -1.15.

K = 3000;
C = K*(s+2)/(s+5);
GCL = minreal(feedback(C*G, 1));
pole(GCL)
%%
% Let's look at how the artist reacts to a disturbance torque d (a gust of
% wind, or a student pushing on the joystick). The transfer function from d to
% theta is G/(1+CG):

GD = minreal(G/(1 + C*G));
figure;
step(GD);
title('Response of theta to a Step Disturbance Torque (lead)');
%%
% The artist stays up, but a constant push leaves a constant tilt, because
% the controller has no integrator.
%%
% Lead + integrator (zero steady-state tilt under a constant push).
% We add an integrator with a zero at -0.5 so it doesn't destabilize the loop:
%
% $$C(s) = K\frac{(s+2)(s+0.5)}{s(s+5)}$$

C = (s+2)*(s+0.5)/(s*(s+5));
figure;
rlocus(C*G);
sgrid(0.5, []);
title('Root Locus with Lead + Integrator');
%%
% Again with K = 3000:

K = 3000;
C = K*(s+2)*(s+0.5)/(s*(s+5));
GCL = minreal(feedback(C*G, 1));
pole(GCL)
GD = minreal(G/(1 + C*G));
figure;
step(GD);
title('Response of theta to a Step Disturbance Torque (lead + integrator)');
%%
% Now the tilt returns to zero. The price is a slower and more oscillatory
% transient. That trade-off is easy to see by moving K along the root locus.
%
% Note: these controllers only regulate the tilt theta. The pole angle psi is
% not controlled, so the pole keeps rotating while the artist rejects a push,
% both here and in the real-time demo.
%
% To try these controllers in real time, open HA_Realtime_Demo.m and set
%
%   C = 3000*(s+2)/(s+5);                    % lead
%   C = 3000*(s+2)*(s+0.5)/(s*(s+5));        % lead + integrator
