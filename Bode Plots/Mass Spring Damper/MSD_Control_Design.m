%% Mass spring damper - Bode design: lag compensator
% Mass-spring-damper from Chapter 1. The input is the force u and the output
% is the position x of the mass. This is Example "Mass-spring-damper: lag
% compensation" of Chapter 8.
%
% Specifications: steady state error to a step of at most 5%, phase margin of
% at least 50 deg. We use a lag compensator
%
% $$C(s) = K_c\frac{Ts+1}{\beta Ts+1}, \qquad \beta > 1$$

clear all
close all

m = 1;              % mass [kg]
b = 8.8;            % damping [N s/m]
k = 40;             % stiffness [N/m]
s = tf('s');

G = 1/(m*s^2 + b*s + k);
%% Step 1: gain for the steady state specification
% G has no pole at the origin, so the error to a unit step is 1/(1+K_p) with
%
% $$K_p = \lim_{s\to 0} C(s) G(s) = K_c/40$$
%
% An error of 5% needs K_p = 19:

Kp = 1/0.05 - 1;
Kc = Kp*k           % = 760
%% Step 2: margins of the uncompensated system Kc*G
% The phase never reaches -180 deg (second order system), so the gain margin is 
% infinite. The phase margin is about 18.6 deg at 27.6 rad/s: the closed loop 
% overshoots by about 60%.

margin(Kc*G);
%% Step 3: lag compensator
% Find the frequency where the phase of Kc*G is -180 + 50 + 5 = -125 deg 
% (5 deg extra for the phase lag of the compensator at that frequency):

phaseDeg = @(w) angle(evalfr(G, 1j*w))*180/pi;
wc = fzero(@(w) phaseDeg(w) + 125, [1 30])     % about 10.1 rad/s
wc = 10;                                       % round it
%% 
% The lag must bring |Kc G| down to 1 (0 dB) at wc

beta = abs(evalfr(Kc*G, 1j*wc))                % about 7.14
%% 
% Put the zero of the lag one decade below wc, and the pole beta times lower

T = 10/wc                                      % zero at 1/T = 1 rad/s
%% Step 4: validate
% Rounded values: C(s) = 760 (s + 1)/(7.14 s + 1)

C = 760*(s + 1)/(7.14*s + 1);
margin(C*G);                                   % PM about 50.7 deg at 10 rad/s
%% 
% Compare the Bode plots of Kc*G and C*G

bode(Kc*G, C*G); grid on
legend('K_c G(s)', 'C(s) G(s)');
%% 
% and the closed loop step responses. C(0) = Kc, so the steady state error is 
% still 5%, but the overshoot drops from about 61% to about 8%. The closed loop 
% pole at -0.79, close to the lag zero at -1, gives a small slow tail.

step(feedback(Kc*G, 1), feedback(C*G, 1), 5);
legend('uncompensated', 'compensated');
pole(feedback(C*G, 1))
%% 
% To try this controller in MSD_Realtime_Demo (or in the browser version), type 
% this in its C(s) box
%
%   760*(s+1)/(7.14*s+1)

[numC, denC] = tfdata(C, 'v')
