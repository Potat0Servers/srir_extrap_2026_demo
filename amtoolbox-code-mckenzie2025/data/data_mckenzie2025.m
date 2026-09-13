function data = data_mckenzie2025(flag)
% data_mckenzie2025 loads listening test stimuli and regression results
%                   from McKenzie and Brinkmann 2025.
%
%   Usage:      stimuli = data_mckenzie2025('stimuli');
%               regression = data_mckenzie2025('regression');
%
%   Output parameters:
%     stimuli    : Struct containing the stimuli used for developing
%                  `mckenzie2025(...)`. The struct contains the fields
%                  Mc18, Mc19a, Mc19b, Mc22, and Ll22 each containing
%                  data from the corresponding study (see Mckenzie and
%                  Brinkmann 2025 for details). Each of fields contains one
%                  or multiple subfields named according to the audio
%                  content, e.g., *stimuli.Mc18.noise* holding the actual
%                  data. The fields *reference* and *test* contain the
%                  reference and test stimuli at the sampling rate
%                  specified in the field *sampling_rate*. The subject
%                  averaged rating from the listening test are stored in
%                  the field *ratings*. See `demo_mckenzie2025(...)` and
%                  `exp_mckenzie2025(...)` for example usage.
%     regression : Contains results from the regression analysis between
%                  model predictions from `mckenzie2025(...)` and listening
%                  test ratings (see *stimuli* above). Contains one field
%                  per colouration model tested in McKenzie and Brinkmann
%                  2025 with subfields containing regression results for
%                  each stimulus pool obtained with Matlab's `fitlm` linear
%                  regression function. For each model, regression results
%                  are available per study (e.g. Mc18, see ablve), as well
%                  as for pooled data (as obtained from the raw models) and
%                  scaled and pooled data (as obtained if applying
%                  regression slopes and intercepts shown in McKenzie and
%                  Brinkmann 2025 Table 3 and shown in Fig. 2).
%
%   References: mckenzie2025
%
%   #Author: Fabian Brinkmann (2025): Co-developer.
%   #Author: Thomas McKenzie (2025): Co-developer.
%   #Requirements: MATLAB

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 

data = amt_load('mckenzie2025','data_mckenzie2025.mat');

if strcmpi(flag, 'stimuli')
    data = data.stimuli;
elseif strcmpi(flag, 'regression')
    data = data.regression;
else
    error(['the flag must be ''stimuli'' or ''regression'' but is ''' ...
           flag ''''])
end