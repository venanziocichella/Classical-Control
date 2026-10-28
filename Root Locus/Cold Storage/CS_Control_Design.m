%% Cold storage unit - Control Design
% Cold storage unit from Chapter 1:
% 
% $$\frac{dT}{dt} = -h(T - T_a) - P$$
% 
% where P >= 0 is the cooling power. More cooling lowers the temperature, so 
% by convention (and without loss of generality) we take as input u = -P. Then
% 
% $$\frac{dT}{dt} = -h(T - T_a) + u$$
% 
% and, with h = 1 and T_a = 15, the transfer function from u to T is 
% G(s) = 1/(s+1), with a positive gain. The ambient temperature acts as a 
% constant disturbance. The cooling power applied by the AC is P = -u.

clear all
close all

h = 1;              % heat transfer constant [1/s]
s = tf('s');

G = 1/(s + h);
%% 
% In Chapter 1 we used the integral controller
% 
% $$u(t) = \int_0^t (r - T(\tau))\,d\tau, \qquad C(s) = \frac{1}{s}$$
% 
% i.e., P(t) = -u(t) = \int_0^t (T(\tau) - r)\,d\tau.

C = 1/s;
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
% $$C(s) = K\frac{s+1}{s}$$
% 
% Then L(s) = K/s and the closed loop pole is at -K.

C = (s + 1)/s;
rlocus(C*G);
%% 
% With K = 2 the closed loop pole is at -2:

C = 2*C;
pzplot(minreal(C*G/(1+C*G)));
step(minreal(C*G/(1+C*G)));
%% 
% Note that the AC can only cool (P >= 0, i.e., u <= 0): it cannot heat the 
% room if the temperature drops below the target.
% 
% To try this controller in CS_Realtime_Demo, type this in its C(s) box
% 
%   2*(s+1)/s

[numC, denC] = tfdata(C, 'v')
