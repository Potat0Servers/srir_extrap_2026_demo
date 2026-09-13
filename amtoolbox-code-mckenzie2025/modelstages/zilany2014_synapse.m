function [ANresp,var_rate,psth] = zilany2014_synapse(vihc,fc,nrep,tdres,fiberType,noiseType,implnt)
%ZILANY2014_SYNAPSE Auditory nerve (AN) synapse model
%   Usage: [ANresp,var_rate, psth] = zilany2014_synapse(vihc,fc,nrep,tdres,fiberType,noiseType,implnt);
%
%   Input parameters:
%     vihc       : Output from inner hair cells (IHCs) in Volts
%     fc         : Center frequencies (Hz)
%     nrep       : Number of repetitions for the mean rate, rate variance 
%                  & psth calculation. Default is 1.
%     tdres      : simulation time resolution, fs_mod^(-1)
%     fiberType  : Type of the fiber based on spontaneous rate (SR) in spikes/s
%                  1: Low SR; 2: Medium SR (default); 3: High SR.
%     noiseType  : Fractional Gaussian noise will be different in every
%                  simulation (1), or will be always the same (0, default)
%     implnt     : 0...Use approxiate implementation of the power-law (default). 
%                  1...Use actual implementation of the power-law functions.
%
%   Output parameters:
%     ANresp     : AN response in terms of the estimated instantaneous mean 
%                  spiking rate (incl. refractoriness) in *nf* different AN 
%                  fibers spaced equally on the BM
%     var_rate   : var rate
%     psth       : Spike histogram
%
%   `zilany2014_synapse` returns modeled responses of one AN fibers to a specific inner haircell potential.
%
%   Please cite the references below if you use this model.
%
%
%   Demos: demo_zilany2014
%
%   References: zilany2009 zilany2014

%   #StatusDoc: Good
%   #StatusCode: Good
%   #Verification: Unknown
%   #Requirements: MATLAB MEX M-Signal
%   #Author: Muhammad Zilany 
%   #Author: Robert Baumgartner: adapted to the AMT
%   #Author: Clara Hollomey (2020): adapted to AMT 1.0
%   #Author: Piotr Majdak (2021): C1 and C2 outputs

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


      [ANresp,var_rate,psth] = comp_zilany2014_synapse(vihc(:)',fc,nrep,tdres,fiberType,noiseType,implnt);
      ANresp=ANresp';
      var_rate=var_rate';
      psth=psth';
    
end

