%% Car steering (lane change) - Routh-Hurwitz Control Design
% Car with front-wheel steering from Chapter 1. The input is the steering angle 
% phi and the output is the lateral position y of the front of the car. 
% Linearized around a straight path at constant speed v, the transfer function 
% is
% 
% $$G(s) = \frac{v (s + v/l)}{s^2}$$

clear all
close all

l = 1;              % wheelbase [m]
v = 1;              % forward speed [m/s]
s = tf('s');

G = v*(s + v/l)/s^2;
%% P controller
% With C(s) = K the characteristic equation is s^2 + K(s + 1) = 0, i.e.,
% 
% $$P(s) = s^2 + Ks + K$$
% 
%   s^2 | 1     K
%   s^1 | K     0
%   s^0 | K
% 
% Stable for any K > 0.
%% Driving in reverse
% In reverse (v = -1) the transfer function becomes G(s) = -(s - 1)/s^2, with 
% a zero in the RHP. With C(s) = K:
% 
% $$P(s) = s^2 - Ks + K$$
% 
%   s^2 | 1      K
%   s^1 | -K     0
%   s^0 | K
% 
% We would need -K > 0 and K > 0 at the same time: no K stabilizes the car in 
% reverse with a P controller.
%% 
% Back to forward driving. With K = 2 the closed loop poles are at -1 +/- j:

K = 2;
C = K;
pole(minreal(C*G/(1+C*G)))
step(minreal(C*G/(1+C*G)));
%% 
% To try this controller in CAR_Realtime_Demo, set
% 
%   C = 2;

[numC, denC] = tfdata(tf(C), 'v')
