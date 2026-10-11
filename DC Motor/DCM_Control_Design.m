%% DC motor (servo) - Control Design
% DC motor from Chapter 1 with a negligible armature inductance. The input is 
% the armature voltage v and the output is the shaft angle theta. The values 
% are those of the ball-on-plate servo.

clear all
close all

K = 1.53;           % steady-state speed gain [rad/(V s)]
tau = 0.0248;       % time constant [s]
s = tf('s');

G = K/(s*(tau*s+1));
%% 
% Plot the root locus of G:

rlocus(G);
%% 
% The poles of G are at 0 and -1/tau = -40.3. With C(s) = Kp the two closed 
% loop poles move toward each other, meet at -20.2 and then move vertically. 
% Since G has a pole at the origin (type 1), the steady state error to step 
% inputs is zero for any Kp > 0.
% 
% Let's compare a few gains

Kp = 5;
step(minreal(Kp*G/(1+Kp*G)), 0.5);
hold on
Kp = 10;
step(minreal(Kp*G/(1+Kp*G)), 0.5);
Kp = 76.5;
step(minreal(Kp*G/(1+Kp*G)), 0.5);
legend('K_p = 5', 'K_p = 10', 'K_p = 76.5');
hold off
%% 
% Kp = 5 gives two real poles (no overshoot, but the slow pole is at -10). 
% Kp = 10 puts the poles at about -20.2 +/- 14.5j (damping ratio 0.8), which is 
% fast with almost no overshoot. Kp = 76.5 (the gain used in the lab to meet 
% the ramp specification) is much more oscillatory.

C = 10;
pzplot(minreal(C*G/(1+C*G)));
%% 
% To try this controller in DCM_Realtime_Demo, set
% 
%   C = 10;
