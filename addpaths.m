% Reset the MATLAB path and add the toolboxes used by the SRIR workflow.

rootDir = fileparts(mfilename('fullpath'));

restoredefaultpath;

addpath(genpath(fullfile(rootDir, 'Spherical-Array-Processing-master')));
addpath(genpath(fullfile(rootDir, 'Higher-Order-Ambisonics-master')));
addpath(genpath(fullfile(rootDir, 'amtoolbox-code-mckenzie2025')));
addpath(genpath(fullfile(rootDir, 'binaural-ambisonic-preprocessing-main')));
addpath(genpath(fullfile(rootDir, 'SOFAtoolbox')));
addpath(genpath(fullfile(rootDir, 'Spherical-Harmonic-Transform')));
addpath(fullfile(rootDir, 'SphFilterBank'));
addpath(fullfile(rootDir, 'SOFAfiles'));
addpath(fullfile(rootDir, 'other_functions'));
addpath(fullfile(rootDir, 'supplementary_functions'));
addpath(rootDir);

