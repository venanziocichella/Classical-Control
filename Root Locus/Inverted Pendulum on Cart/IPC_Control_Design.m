%% Control design for inverted pendulum on a cart
% Model from Exercise 4.4: a pendulum (mass m, inertia I, distance l from the
% pivot to its center of mass) is hinged on a cart of mass M. The input u is
% the horizontal force on the cart, the output theta is the pendulum angle
% from the upward vertical, and mu is the cart friction coefficient.

clear all
close all

M = 0.5;     % cart mass [kg]
m = 0.5;     % pendulum mass [kg]
l = 0.3;     % pivot to pendulum center of mass [m]
I = 0.006;   % pendulum inertia [kg m^2]
mu = 0.1;    % cart friction [N s/m]
g = 9.81;    % gravity [m/s^2]
s = tf('s');

q = (M+m)*(I+m*l^2) - (m*l)^2;
G = -(m*l/q)*s/(s^3 + mu*(I+m*l^2)/q*s^2 - (M+m)*m*g*l/q*s - mu*m*g*l/q);
%%
% The poles of G are

pole(G)
%%
% One pole is in the RHP, so the system is not input/output stable. The step
% response confirms it:

step(G, 1);
%%
% Note also the zero at the origin, and the minus sign: pushing the cart to
% the right makes the pendulum fall to the left. Therefore, our controller will
% have a negative gain.
%% PD Controller Design
% Let's try with a PD controller with a negative gain
%
% $$C(s) = -(k_p + k_d s)$$

kp = 6; kd = 1;
C = -(kp + kd*s)/(s/100+1);
rlocus(C*G);
%%
% The zero of G at the origin attracts one of the closed loop poles: for any
% gain, a pole remains near the origin, in the RHP. For example, with K = 10

K = 10;
pole(minreal(K*C*G/(1+K*C*G)))
%%
% To cancel the zero at the origin, we need a pole at the origin, i.e., an
% integrator.
%% PID Controller Design
% The PID controller is given by
%
% $$C(s) = -\left(k_p+k_ds+\frac{k_i}{s}\right) = -k_d \frac{s^2+as+b}{s}$$
%
% with
%
% $$a = \frac{k_p}{k_d} , \qquad b = \frac{k_i}{k_d} $$
%
% For example, let

kp = 6; kd = 1; ki = 8;
C = -(kp + kd*s + ki/s)/(s/100+1);
rlocus(C*G);
%%
% Now all the branches can be brought to the LHP. With a gain of 10 the
% dominant closed loop poles are at about -2.7 +/- 1.2j.

C = 10*C;
pzplot(minreal(C*G/(1+C*G)));
%%
% Finally, let's see how the pendulum reacts to a push (a step disturbance
% force on the cart). The transfer function from the disturbance to theta is
% G/(1+CG):

step(minreal(G/(1+C*G)), 5);
%%
% For a 1 N push the pendulum tilts by less than one degree and returns upright. Note that
% we only control theta: the cart position is not controlled, so the cart
% keeps moving after a push.

[numC, denC] = tfdata(C, 'v')
