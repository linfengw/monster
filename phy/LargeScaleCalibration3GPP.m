clear all
close all

%% Construct antenna array per table 7.8-1
% 1 x 1 Panel with 10 x 1 antenna elements at 1 polarization spaced with
% 0.5lambda. Tilted at 102 degrees for UMa

% Sector 1
aaSector1 = AntennaArray([1, 1, 10, 1, 1], 30, 102);

% Sector 2
aaSector2 = AntennaArray([1, 1, 10, 1, 1], 150, 102);

% Sector 3
aaSector3 = AntennaArray([1, 1, 10, 1, 1], 270, 102);

% Visualize radiation pattern

elements = aaSector1.Panels{1};
elements{1}.plotPattern()

theta = -90:210;
phi = -180:180;
figure
plot(phi,elements{1}.get3DGain(90,phi))
xlabel('Elevation (degrees)')
ylabel('Antenna gain (dB)')

figure
plot(theta,elements{1}.get3DGain(theta,-30))
hold on
plot(theta,elements{1}.get3DGain(theta,0))
plot(theta,elements{1}.get3DGain(theta,60))
xlabel('Azimuth (degrees)')
ylabel('Antenna gain (dB)')