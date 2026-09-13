function [pbc2, pbc2_raw, C, f] = mckenzie2025(reference, test, settings)
%mckenzie2025 predicts the binaural colouration between a set of reference
%             and test stimuli
%
%   Usage:      [pbc2] = mckenzie2025(reference, test);
%               [pbc2,pbc2_raw] = mckenzie2025(reference, test, settings);
%
%   Input parameters:
%     reference : Time-domain binaural signal(s) of the reference / target
%                 sound(s), according to the following matrix dimensions:
%                 [*time* *direction* *channel/ear*],
%                 i.e. [no. samples, no. signals, no. channels].
%     test      : Time-domain binaural signal(s) of the test sound(s). Must
%                 have the same dimensions as *reference* except for
%                 no. of samples, which can be different (see above).
%     settings  : Optional struct that contains any of the fields listed
%                 below. If a field is not given, the corresponding default
%                 value will be used.
%
%                 fs (default = 48000)
%                   The sampling rate in Hz.
%                 minFreq (default = 20)
%                   Minimum frequency (in Hz) for predicting the binaural
%                   colouration.
%                 maxFreq (default = 20000)
%                   Maximum frequency (in Hz) for predicting the binaural
%                   colouration.
%                 bin_weight (default = 'level')
%                   Method for combining left and right ear data: 'mean'
%                   takes the mean across ears, 'interaural' uses ITD/ILD,
%                   'level' uses max. level per ear. See [1, Section 2.2].
%                 level_weight_doubling (default = 6)
%                   Set the strength of the influence for level weighting
%                   in the binaural stage if
%                   `settings.bin_weight = 'level'`. See [1, Eq. 16].
%                 smGL1 (default = 0)
%                   Low frequency octave smoothing flag. `0` applies
%                   gradual low-frequency smoothing (linear increase from
%                   no smoothing to smoothed at cross-over frequency
%                   *settings.sm_xo_f*). `1` applies full low-frequency
%                   smoothing according to *settings.nOctSm*.
%                   See [1, Eq. (6)].
%                 nOctSm (default = 3)
%                   Width for octave smoothing (3 = 1/3 octave smoothing).
%                   See [1, Eq. (6)].
%                 sm_xo_f (default = 5000)
%                   Crossover frequency from low to high frequency
%                   smoothing (in Hz). See [1, Eq. (6)].
%                 w_ERB (default = 1.35)
%                   ERB influence factor - account for approx. logarithmic
%                   human sensitivity to frequencies but linear frequency
%                   spacing in FFTs. See [1, Eq. (7)].
%                 nfft (default = size(reference, 1))
%                   The block size of the FFT (in samples).
%
%   Output parameters:
%     pbc2     : Predicted colouration scaled to the range of
%                approximately 0-100 (0 denotes no colouration) and
%                averaged across frequencies and ears. One value per
%                stimulus. See [1, Eq. (20)].
%     pbc2_raw : Predicted colouration. As *pbc2* but without scaling.
%     C        : Predicted colouration per frequency bin without scaling
%                and averaging across ears. See [1, Eq. (18)].
%     f        : Frequencies (in Hz) at which *C* is computed.
%
%   `mckenzie2025(...)` is a model for predicting the colouration between
%   binaural signals. It mainly features a small peripheral model followed
%   by frequency smoothing and binaural weighting. This can be used for
%   binaural recordings as well as head-related impulse responses (HRIRs)
%   and binaural room impulse responses (BRIRs).
% 
%   See also: |demo_mckenzie2025| for example usage and |exp_mckenzie2025|
%             for creating the results from [1, Fig. 2].
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


%% Default optional input parameters

% Model settings - control the impact each perceptual modification makes
if nargin<3
    settings = struct();
end

if ~isfield(settings, 'w_ERB')
    settings.w_ERB      = 1.35;
end
if ~isfield(settings, 'smGL1')
    settings.smGL1       = 0;
end
if ~isfield(settings, 'nOctSm')
    settings.nOctSm      = 3;
end
if ~isfield(settings, 'sm_xo_f')
    settings.sm_xo_f     = 5000;
end
if ~isfield(settings, 'bin_weight')
    settings.bin_weight  = 'level';
end
if ~isfield(settings, 'level_weight_doubling')
    settings.level_weight_doubling = 6;
end
if ~isfield(settings, 'fs')
    settings.fs = 48000;
end
if ~isfield(settings, 'nfft')
    settings.nfft = size(reference,1);
end
if ~isfield(settings, 'minFreq')
    settings.minFreq = 20;
end
if ~isfield(settings, 'maxFreq')
    settings.maxFreq = 20000;
end
if ~isfield(settings, 'norm')
    settings.norm = false;
end

%% Check input parameters
if size(reference,3) ~= 2 || size(test,3) ~= 2 % if either input set is not binaural:
    error(['Error: signals must be binaural (stereo)! Reference signal set has ',num2str(size(reference,3)),' channel(s), test signal set has ',num2str(size(test,3)),' channel(s).' ])
end
if size(reference,2) ~= size(test,2) % if input sets are not same number of signals:
    error(['Error: not comparing same number of signals! Reference signal set has ',num2str(size(reference,2)),' signal(s), test signal set has ',num2str(size(test,2)),' signal(s).' ])
end

% Ensure both signal sets are the same size (e.g. for comparing dry to reverberant signals)
if size(reference,1) > size(test,1)
    test = [test; zeros(size(reference,1)-size(test,1),size(test,2),size(test,3))];
elseif size(test,1) > size(reference,1)
    reference = [reference; zeros(size(test,1)-size(reference,1),size(reference,2),size(reference,3))];
end

% FFT data
minfftBin = round(settings.minFreq/settings.fs*settings.nfft)+1;
maxfftBin = round(settings.maxFreq/settings.fs*settings.nfft)+1;
k = (0:settings.fs/settings.nfft:settings.fs-(settings.fs/settings.nfft))'; % frequency bin

% For ITD weightings: max ITD is 0.8ms, in line with literature (Kuhn 1977, Katz 2014, Hartmann 2014)
itd_ref = finddelay(reference(:,:,1),reference(:,:,2),round(0.8/1000*settings.fs))/settings.fs;
itd_test = finddelay(test(:,:,1),test(:,:,2),round(0.8/1000*settings.fs))/settings.fs;

%% Peripheral modeling

% Full-wave rectification
h_rec_ref = abs(reference);
h_rec_test = abs(test);

% Process FFT and convert to dB scale
L_ref = abs(fft(h_rec_ref, settings.nfft));
L_test = abs(fft(h_rec_test, settings.nfft));
L_ref = 20*log10(L_ref);
L_test = 20*log10(L_test);

% Truncate to specified frequency range
L_ref = L_ref(minfftBin:maxfftBin,:,:);
L_test = L_test(minfftBin:maxfftBin,:,:);
k = k(minfftBin:maxfftBin);

% Apply offset and level normalisation
% if true, normalise to mean dB value of datasets
if settings.norm
    norm = mean(L_ref(:))-mean(L_test(:));
    L_test = L_test + norm;
end

% Octave Smoothing (adapted from https://uk.mathworks.com/matlabcentral/fileexchange/19228-short-time-fft-with-octave-smooth)
xo_i_sm = find(k >= settings.sm_xo_f,1); % crossover index
% Calculate ramp between no smoothing and smoothing
lenL = size(L_ref(1:xo_i_sm,1,1),1);
lenH = size(L_ref(xo_i_sm+1:end,1,1),1);
% settings.smGL1 = 1 -> all frequencies smoothed,
%             0 -> low frequencies no smoothing (linear increase from no smoothing to smoothed at xover freq settings.sm_xo_f)
r_sm_lo = repmat(linspace(settings.smGL1,1,lenL)',1,size(L_ref,2),size(L_ref,3));
r_no_sm_lo = 1-r_sm_lo;
r_sm_hi = ones(lenH,size(L_ref,2),size(L_ref,3));
r_no_sm_hi = 0*r_sm_hi;

% Calculate smooth frequency responses
f_sm_1=1;
i=0;
clear fc;
while f_sm_1 < (settings.maxFreq)
    f_sm_1=f_sm_1*10^(3/(20*settings.nOctSm));
    i=i+1;
    % octave centre frequencies
    fc(i) = f_sm_1; %#ok<AGROW>
end
fe=zeros(size(fc));
for i=1:length(fc)
    fe(i)=10^(3/(40*settings.nOctSm))*fc(i); % octave edge frequencies
    fe_1=find(k>fe(i),1,'first');
    fe_2=find(k<fe(i),1,'last'); % closest frequency edges in the FFT frequencies
    if isempty(fe_2)==1; fe_2 = 1; end
    fe_0=find(k==fe(i));
    if isempty(fe_0)==0; fe(i)=fe_0; % if edge freq = a frequency in the FFT freqs
    else                             % if not:
        p=fe_1-fe(i);
        m=fe(i)-fe_2;
        if p<m; fe(i)=fe_1;     else; fe(i)=fe_2; end
    end
end;    assignin('base','a',fe);
L_ref_sm = zeros(size(L_ref));
L_test_sm = zeros(size(L_test));
for k2 = 1:size(L_ref,2)
    for k3 = 1:size(L_ref,3)
        L_ref_chan = squeeze(L_ref(:, k2, k3));
        L_test_chan = squeeze(L_test(:, k2, k3));
        L_ref_oct = zeros(length(fe)-1,1);
        L_test_oct = zeros(length(fe)-1,1);
        for i=1:length(fe)-1
            L_ref_oct(i,1:size(L_ref_chan,2))=mean(L_ref_chan(fe(i):fe(i+1),:));
            L_test_oct(i,1:size(L_test_chan,2))=mean(L_test_chan(fe(i):fe(i+1),:));
        end
        L_ref_sm(:,k2,k3) = interp1(fc(2:end),L_ref_oct,k,'makima');
        L_test_sm(:,k2,k3) = interp1(fc(2:end),L_test_oct,k,'makima');
    end
end
L_ref = L_ref_sm.*([r_sm_lo ; r_sm_hi]) + L_ref.*([r_no_sm_lo ; r_no_sm_hi]);
L_test = L_test_sm.*([r_sm_lo ; r_sm_hi]) + L_test.*([r_no_sm_lo ; r_no_sm_hi]);

% Equivalent rectangular bandwidth frequency bin weighting
f_ERB = (0.108.*k+24.7).^settings.w_ERB;
g_ERB = f_ERB(1)./f_ERB; % normalise values

%% Final colouration

g_l = zeros(size(L_ref,1),size(L_ref,2));
g_r = g_l;

if strcmp(settings.bin_weight, 'mean')
    g_l = 0.5*ones(size(L_ref,1),size(L_ref,2));
    g_r = g_l;
elseif strcmp(settings.bin_weight, 'interaural')
    % Binaural interaural weighting: ILD > 1.5kHz, ITD < 1.5kHz
    xo_f_binW = find(k>1500,1); % binaural weight crossover frequency

    % Interaural time difference weighting, based on wideband ITD
    itd_sens = 125; % For sensitivity - higher number is higher perceptual weight for earlier arriving ear. Value of 125 means 0.8ms ITD -> ipsilateral 2.33x contralateral
    g_itd_l = 0.5 + itd_sens*(itd_ref+itd_test);
    g_l(1:xo_f_binW,:) = repmat(g_itd_l,[length(1:xo_f_binW) 1]);
    g_r(1:xo_f_binW,:) = 1-repmat(g_itd_l,[length(1:xo_f_binW) 1]);

    % Interaural level difference weighting, based on ILD > 1.5kHz
    ild_L_ref = L_ref(xo_f_binW+1:end,:,1)-L_ref(xo_f_binW+1:end,:,2); % calculate separately for each frequency bin
    ild_L_test = L_test(xo_f_binW+1:end,:,1)-L_test(xo_f_binW+1:end,:,2);
    ild = (ild_L_ref+ild_L_test) / 2; % mean interaural level difference of A and B
    ild_amp_sens = 5; % sensitivity - lower number is higher perceptual weight for louder ear. Value of 5 means 10dB ILD -> ipsilateral 4x contralateral
    g_ild = 2.^(ild / ild_amp_sens); % amplitude weight
    g_ild_l = g_ild./(g_ild+1);
    g_l(xo_f_binW+1:end,:) = g_ild_l;
    g_r(xo_f_binW+1:end,:) = 1-g_ild_l;

elseif strcmp(settings.bin_weight, 'level')
    % get bin-wise maximum loudness per ear
    loudest = max(L_ref, L_test);
    % get loudness difference
    delta_loudest = loudest(:, :, 1) - loudest(:, :, 2);
    % derive weights for averaging left and right ear
    g_l = 2.^(delta_loudest/settings.level_weight_doubling) ./ ...
        (1 + 2.^(delta_loudest/settings.level_weight_doubling));
    g_r = 1 - g_l;
end

C = g_ERB .* abs(L_ref - L_test)./sum(g_ERB); % colouration per frequency bin, apply ERB weights

% Single value of colouration
pbc2_raw = sum(g_l .* C(:,:,1) + g_r .*C(:,:,2),1);
% apply regression coefficients
pbc2 = pbc2_raw * 15.192220974617410 - 0.115347283891013;

% frequency return parameter
f = k;

end
