clear all
close all

% Define the system transfer function coefficients
s = tf('s');
CG = 1/((s-1)*(s+5)*(s+10));

% Create a figure
figure;
hold on
% Create a slider for gain K
slider = uicontrol('Style', 'slider', 'Min', 0.01, 'Max', 2000, 'Value', 0.01,...
    'Units', 'normalized', 'Position', [0.1 0.01 0.8 0.05],...
    'Callback', @(src, event) updatePlot(src, CG));

% Initial plot
updatePlot(slider, CG);

function updatePlot(slider, sys)
    % Get the current gain K from the slider
    K = slider.Value;

    % Clear the previous plot
    cla;

    % Create the root locus plot
    rlocus(sys);
    hold on;

    % Find the closed-loop poles
    poles = pole(feedback(sys * K, 1));

    % Plot the closed-loop poles
    plot(real(poles), imag(poles), 'ro', 'MarkerFaceColor', 'r');
    hold off;

    % Update the title with the current gain K
    title(['Root Locus Plot for K = ', num2str(K)]);

    % Set the axis limits and labels
    axis([-15 10 -12.5 12.5])
    xlabel('Real Axis');
    ylabel('Imaginary Axis');
end