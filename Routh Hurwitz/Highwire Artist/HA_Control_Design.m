%% Highwire artist - Routh-Hurwitz Control Design
% Highwire artist balancing with a pole, linearized around the upright 
% position. The input is the torque on the pole and the output is the tilt 
% angle of the artist.

clear all
close all

s = tf('s');
J = 10.4;
l = 1.5;
L = 2;
m = 5;
M = 75;
g = 9.81;

a = 6/(6*m*l^2+2*M*L^2);
b = 3*g*(2*m*l+M*L)/(6*m*l^2+2*M*L^2);
G = a/(s^2 - b);
%% P controller
% With C(s) = K: P(s) = s^2 + aK - b. The coefficient of s is zero, so no K 
% makes the closed loop asymptotically stable.
%% Lead compensator
% $$C(s) = K\frac{s+2}{s+5}$$
% 
% The characteristic equation is (s + 5)(s^2 - b) + aK(s + 2) = 0, i.e.,
% 
% $$P(s) = s^3 + 5s^2 + (aK - b)s + (2aK - 5b)$$
% 
% Routh table:
% 
%   s^3 | 1                                   aK - b
%   s^2 | 5                                   2aK - 5b
%   s^1 | c11 = (5(aK - b) - (2aK - 5b))/5 = 3aK/5
%   s^0 | c21 = 2aK - 5b
% 
% We need K > 0 and 2aK - 5b > 0, i.e.,

Kmin = 5*b/(2*a)
%% 
% Let's check just below and above Kmin:

pole(minreal(2000*(s+2)/(s+5)*G/(1+2000*(s+2)/(s+5)*G)))   % unstable
pole(minreal(2100*(s+2)/(s+5)*G/(1+2100*(s+2)/(s+5)*G)))   % stable
%% 
% We choose K = 3000:

K = 3000;
C = K*(s+2)/(s+5);
pole(minreal(C*G/(1+C*G)))
step(minreal(C*G/(1+C*G)));
%% 
% To try this controller in HA_Realtime_Demo, type this in its C(s) box
% 
%   3000*(s+2)/(s+5)

[numC, denC] = tfdata(C, 'v')
