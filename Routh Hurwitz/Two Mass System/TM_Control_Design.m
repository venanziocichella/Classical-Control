%% Two-mass system - Routh-Hurwitz Control Design
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
% With these numbers
% 
% $$G(s) = \frac{s^2 + 0.5s + 1}{s^4 + 0.5s^3 + 3s^2 + s + 1}$$
%% P controller
% With C(s) = K the characteristic equation is 
% s^4 + 0.5s^3 + 3s^2 + s + 1 + K(s^2 + 0.5s + 1) = 0:
% 
% $$P(s) = s^4 + 0.5s^3 + (3 + K)s^2 + (1 + 0.5K)s + (1 + K)$$
% 
% Routh table:
% 
%   s^4 | 1                                    3 + K        1 + K
%   s^3 | 0.5                                  1 + 0.5K     0
%   s^2 | c11 = (0.5(3 + K) - (1 + 0.5K))/0.5 = 1    c12 = 1 + K
%   s^1 | c21 = (1 + 0.5K - 0.5(1 + K))/1 = 0.5
%   s^0 | c31 = 1 + K
% 
% The closed loop is stable for any K > -1.
%% 
% Stable, but not necessarily good! Routh-Hurwitz says nothing about damping. 
% With K = 10:

K = 10;
C = K;
pole(minreal(C*G/(1+C*G)))
step(minreal(C*G/(1+C*G)), 30);
%% 
% Two poles are almost on the imaginary axis (-0.002 +/- 3.5j): mass 1 
% oscillates for a long time. Also, the steady state error is 
% 1/(1 + K G(0)) = 1/11. Try C = 10 in TM_Realtime_Demo to see it. A good 
% controller for this system needs the root locus (see 
% Root Locus/Two Mass System), e.g., the PID
% 
%   C = 5*(s+1)^2/(s*(s/20+1));
% 
% which is the default in TM_Realtime_Demo.

[numC, denC] = tfdata(tf(C), 'v')
