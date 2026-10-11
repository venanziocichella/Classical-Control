%% Cold storage unit - Control Design
% Cold storage unit from Chapter 1:
% 
% $$\frac{dT}{dt} = -h(T - T_a) - P$$
% 
% The input is the cooling power P and the output is the temperature T. With 
% h = 1 and T_a = 15, the transfer function from P to T is G(s) = -1/(s+1); the 
% ambient temperature acts as a constant disturbance.

clear all
close all

h = 1;              % heat transfer constant [1/s]
s = tf('s');

G = -1/(s + h);
%% 
% Note the minus sign: more cooling power lowers the temperature. Therefore 
% our controller will have a negative gain.
% 
% In Chapter 1 we used the integral controller
% 
% $$P(t) = \int_0^t (T(\tau) - r)\,d\tau, \qquad C(s) = -\frac{1}{s}$$

C = -1/s;
rlocus(C*G);
%% 
% With gain 1 the closed loop poles are at -0.5 +/- 0.87j:

pzplot(minreal(C*G/(1+C*G)));
step(minreal(C*G/(1+C*G)));
%% 
% The integrator gives zero steady state error, even when the ambient 
% temperature changes. To make the response faster and remove the overshoot, 
% we use a PI controller whose zero cancels the pole of G:
% 
% $$C(s) = -K\frac{s+1}{s}$$
% 
% Then L(s) = K/s and the closed loop pole is at -K.

C = -(s + 1)/s;
rlocus(C*G);
%% 
% With K = 2 the closed loop pole is at -2:

C = 2*C;
pzplot(minreal(C*G/(1+C*G)));
step(minreal(C*G/(1+C*G)));
%% 
% Note that the AC can only cool (P >= 0): it cannot heat the room if the 
% temperature drops below the target.
% 
% To try this controller in CS_Realtime_Demo, set
% 
%   C = -2*(s+1)/s;

[numC, denC] = tfdata(C, 'v')
