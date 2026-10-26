%% Two-mass system - Control Design
% Two-mass system from Chapter 1 (wall - k1 - m1 - k2 - m2 - b - wall). The 
% input is the force u on mass 1 and the output is the position x1 of mass 1. 
% The notes give no numbers for this example; here we choose
% m1 = m2 = 1, k1 = k2 = 1, b = 0.5.

clear all
close all

m1 = 1; m2 = 1; k1 = 1; k2 = 1; b = 0.5;
s = tf('s');

den = (m2*s^2 + b*s + k2)*(m1*s^2 + k1 + k2) - k2^2;
G = (m2*s^2 + b*s + k2)/den;      % X1(s)/U(s)
%% 
% Plot the root locus of G:

rlocus(G);
%% 
% G has two pairs of lightly damped poles (two vibration modes). With 
% C(s) = K the closed loop is stable but oscillatory, and it has a steady state 
% error. We add an integrator for zero steady state error, two zeros at -1 to 
% pull the root locus to the left, and a fast pole at -20 to make the 
% controller proper:
% 
% $$C(s) = K\frac{(s+1)^2}{s(s/20+1)}$$

C = (s+1)^2/(s*(s/20+1));
rlocus(C*G);
%% 
% With K = 5 the slowest closed loop poles are at about -0.24 +/- 0.91j and 
% -0.6:

K = 5;
C = K*C;
pzplot(minreal(C*G/(1+C*G)));
step(minreal(C*G/(1+C*G)));
%% 
% Controlling the position of mass 2 instead (X2/U = k2/den) is much harder: 
% the force acts on mass 1, and mass 2 only feels it through the spring. Try 
% rlocus(C*k2/den) to see why.
% 
% To try this controller in TM_Realtime_Demo, type this in its C(s) box
% 
%   5*(s+1)^2/(s*(s/20+1))

[numC, denC] = tfdata(C, 'v')
