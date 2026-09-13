function [hartestim,fs]  = sig_harte2009()
%SIG_HARTE2009 Tone burst stimuli from Harte et al. (2009)
%
%   Usage: [hartestim,fs] = sig_harte2009;
%
%   `[hartestim,fs]=sig_harte2009` returns the tone burst stimuli from
%   Harte et al. (2009) and the sampling frequency, `fs=48000`.
%
%   References: harte2009comparison

%   #Author: Clara Hollomey (2020)

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

% TODO: explain stimuli in description;

hartestim = amt_load('harte2009','stim.mat');
  
fs = 48e3;
  
