clear all
close all

%% Parameters
s = tf('s');
J = 10.4;
l = 1.5;
L = 2;
m = 5;
M = 75;
g = 9.81;

%% System
G = 6/(6*m*l^2+2*M*L^2)/(s^2-3*g*(2*m*l+M*L)/(6*m*l^2+2*M*L^2));

C = 1;
rlocusplot(C*G)





%% Controller
C = 3000*(s+2)/(s+5);
[numC denC] = tfdata(C, 'v');
