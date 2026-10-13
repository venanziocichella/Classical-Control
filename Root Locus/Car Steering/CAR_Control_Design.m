%% Car steering (lane change) - Control Design
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
%% 
% Plot the root locus of G:

rlocus(G);
%% 
% G has two poles at the origin and a zero at -v/l = -1. The zero bends the 
% root locus into the LHP (the branches move on a circle around the zero), so 
% a simple proportional controller C(s) = K stabilizes the car. With K = 2 the 
% closed loop poles are at -1 +/- 1j:

K = 2;
C = K;
pzplot(minreal(C*G/(1+C*G)));
step(minreal(C*G/(1+C*G)));
%% 
% Since L(s) has two poles at the origin, the steady state error to a lane 
% change (step) is zero.
% 
% What happens when the car drives in reverse (v = -1)? Then 
% G(s) = -(s - 1)/s^2 has a zero in the RHP:

v = -1;
Grev = v*(s + v/l)/s^2;
rlocus(-Grev);
%% 
% Now the root locus of a proportional controller always has a branch in the 
% RHP. This is the non-minimum phase behavior we study in Chapter 12.
% 
% To try the forward controller in CAR_Realtime_Demo, set
% 
%   C = 2;
