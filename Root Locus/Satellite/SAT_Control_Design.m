%% Satellite attitude - Control Design
% Simplified satellite from Chapter 1: a rigid spacecraft rotating about one
% axis. The input is the torque u and the output is the orientation theta.

clear all
close all

I = 1;              % moment of inertia [kg m^2]
s = tf('s');

G = 1/(I*s^2);
%% 
% Plot the root locus of G:

rlocus(G);
%% 
% With C(s) = K the closed loop poles are at +/- j*sqrt(K): the satellite 
% oscillates forever, for any K. We need a zero to pull the root locus into the 
% LHP. A PD controller would do it, but it is not proper, so we use a lead 
% compensator
% 
% $$C(s) = K\frac{s+a}{s+b}, \qquad b > a$$
% 
% For example, let

C = (s+1)/(s+10);
rlocus(C*G);
%% 
% With a gain of 20 the dominant closed loop poles are at about -1.1 +/- 1.1j

K = 20;
C = K*C;
pzplot(minreal(C*G/(1+C*G)));
%% 
% Let's look at the step response (a command to rotate by 1 rad)

step(minreal(C*G/(1+C*G)));
%% 
% G already has two poles at the origin, so the steady state error to step 
% inputs is zero. To try this controller in SAT_Realtime_Demo, type this in its C(s) box
% 
%   20*(s+1)/(s+10)

[numC, denC] = tfdata(C, 'v')
