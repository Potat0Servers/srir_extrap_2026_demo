% demo_mckenzie2025 shows example usage of the binaural colouration model.
%
%   `mckenzie2025(...)` is a model for predicting the colouration between
%   binaural signals. It mainly features a small peripheral model followed
%   by frequency smoothing and binaural weighting. This can be used for
%   binaural recordings as well as head-related impulse responses (HRIRs)
%   and binaural room impulse responses (BRIRs).
%
%   See also: |mckenzie2025| for for the full model documentation and
%             |exp_mckenzie2025| for creating the results from [1, Fig. 2].
%
%   References: mckenzie2025

%   #Author: Thomas McKenzie (2025): Co-developer.
%   #Author: Fabian Brinkmann (2025): Co-developer. 
%   #Requirements: MATLAB


% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

%% Load data --------------------------------------------------------------
close all; clear; clc

% load all stimuli from the five listening tests
stimuli = data_mckenzie2025('stimuli');

%% Run model with default parameters --------------------------------------
%  (this reproduces results from [mckenzie2025] for a single experiment and content)

% select experiment and audio content for which the binaural colouration
% is predicted. Must be on of the following:
% 'Mc18.noise', 'Mc19a.noise', 'Mc19a.trainstation', 'Mc19b.noise',
% 'Mc19a.percussion', 'Mc22.noise', 'Ll22.noise',  'Ll22.speech', 
% 'Ll22.rain'
experiment = stimuli.Ll22.noise;

% predict colouration
predictions = mckenzie2025(experiment.reference, experiment.test);

% simple plot of predicted versus rated colouration
figure;
plot(experiment.ratings, predictions, 'ko')
hold on
plot([0, 100], [0, 100], '--', 'Color', [.6, .6, .6])
axis equal
xlim([0, 100])
ylim([0, 100])
xlabel 'Perceived colouration'
ylabel 'Predicted colouration'
grid on


%% Run model with non-default parameters ----------------------------------

% change any parameter to run the model with non-default values
% (see documentation of mckenzie2025 for parameter information)
settings.w_ERB                 = 1;
settings.smGL1                 = 1;
settings.nOctSm                = 3;
settings.sm_xo_f               = 5000;
settings.bin_weight            = 'level';
settings.level_weight_doubling = 6;
settings.fs                    = 48000;
settings.nfft                  = size(experiment.reference, 1);
settings.minFreq               = 16;
settings.maxFreq               = 16000;

% predict colouration
predictions_custom = mckenzie2025( ...
    experiment.reference, experiment.test, settings);

% simple plot of predicted versus rated colouration
figure;
plot(experiment.ratings, predictions_custom, 'ko')
hold on
plot([0, 100], [0, 100], '--', 'Color', [.6, .6, .6])
axis equal
xlim([0, 100])
ylim([0, 100])
xlabel 'Perceived colouration'
ylabel 'Predicted colouration'
grid on
