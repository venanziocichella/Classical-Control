%% Satellite attitude - Routh-Hurwitz Control Design
% Simplified satellite from Chapter 1: a rigid spacecraft rotating about one
% axis. The input is the torque u and the output is the orientation theta.

clear all
close all

I = 1;              % moment of inertia [kg m^2]
s = tf('s');

G = 1/(I*s^2);
%% P controller
% With C(s) = K the characteristic equation 1 + C(s)G(s) = 0 is
% 
% $$s^2 + K = 0$$
% 
% The coefficient of s is zero, so the closed loop is never asymptotically 
% stable (the satellite oscillates forever, for any K).
%% Lead compensator
% Let's add a zero and a pole:
% 
% $$C(s) = K\frac{s+1}{s+10}$$
% 
% The characteristic equation is s^2(s+10) + K(s+1) = 0, i.e.,
% 
% $$P(s) = s^3 + 10s^2 + Ks + K$$
% 
% Routh table:
% 
%   s^3 |  1                 K
%   s^2 | 10                 K
%   s^1 | c11 = (10K - K)/10 = 0.9K
%   s^0 | c21 = K
% 
% All the entries of the first column are positive if K > 0: the closed loop 
% is stable for any K > 0.
% 
% Note: if we swap the zero and the pole, C(s) = K(s+10)/(s+1), then 
% P(s) = s^3 + s^2 + Ks + 10K and c11 = K - 10K = -9K < 0 for any K > 0: 
% unstable for every K. The zero must be closer to the origin than the pole.
%% 
% Routh-Hurwitz tells us which K are stable, not which K is best. Let's pick

K = 20;
C = K*(s+1)/(s+10);
pole(minreal(C*G/(1+C*G)))
%% 
% and look at the step response (a command to rotate by 1 rad)

step(minreal(C*G/(1+C*G)));
%% 
% To try this controller in SAT_Realtime_Demo, type this in its C(s) box
% 
%   20*(s+1)/(s+10)

[numC, denC] = tfdata(C, 'v')
