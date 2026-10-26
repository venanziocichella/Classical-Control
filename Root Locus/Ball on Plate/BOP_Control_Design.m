%% Ball on plate - Control Design
% Ball on plate from Chapter 1. A servo motor tilts the plate by the angle
% theta and the ball rolls. Each axis (x and y) is the same, so we design one
% controller and use it for both. The input is the servo angle command
% theta_ref and the output is the ball position x.

clear all
close all

c = 1.09;           % ball acceleration per servo angle [m/s^2/rad] (K_bb in the lab)
K = 1.53;           % servo gain [rad/(V s)]
tau = 0.0248;       % servo time constant [s]
Kp1 = 76.5;         % inner servo loop gain (P control of the servo angle)
s = tf('s');
%%
% Ball: x'' = c sin(theta), linearized X(s)/Theta(s) = c/s^2
%
% Servo with its own P loop: Theta(s)/Theta_ref(s) = Kp1 K/(tau s^2 + s + Kp1 K)

Gball = c/s^2;
Gservo = Kp1*K/(tau*s^2 + s + Kp1*K);
G = Gball*Gservo;
pole(Gservo)
%%
% The servo poles are fast compared to the ball, so G is almost c/s^2. Plot
% the root locus of G:

rlocus(G);
%%
% With C(s) = K the closed loop poles are on the imaginary axis (or in the
% RHP for large K): the ball oscillates and never settles. As for the satellite,
% we need a lead compensator
%
% $$C(s) = K\frac{s+a}{s/b+1}, \qquad b > a$$
%
% For example, let

C = (s+1)/(s/20+1);
rlocus(C*G);
%%
% With a gain of 3 the closed loop poles are all in the LHP

K = 3;
C = K*C;
pzplot(minreal(C*G/(1+C*G)));
%%
% Let's look at the step response (a command to move the ball by 1 m; the
% plate is smaller, but the system is linear)

step(minreal(C*G/(1+C*G)));
%%
% To try this controller in BOP_Realtime_Demo, type this in its C(s) box
%
%   3*(s+1)/(s/20+1)

[numC, denC] = tfdata(C, 'v')
