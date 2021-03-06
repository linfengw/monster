clear all 
close all
%% Get configuration
Config = MonsterConfig(); % Get template config parameters

% Make local changes
Config.SimulationPlot.runtimePlot = 0;
Config.Ue.number = 1;
Config.MacroEnb.number = 7;
Config.MicroEnb.number = 0;
Config.PicoEnb.number = 0;
Config.Channel.shadowingActive = 0;
Config.Channel.losMethod = 'NLOS';

%% Setup objects
simulation = Monster(Config);

%% Inspect Layout
H = simulation.Channel.plotSINR(simulation.Stations, simulation.Users(1), 10);