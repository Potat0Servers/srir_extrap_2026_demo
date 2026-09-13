function [edcLinear, edcDb, timeVector] = ...
    compute_omni_energy_decay_from_ir(omniIR, fs)
%COMPUTE_OMNI_ENERGY_DECAY_FROM_IR Compute the Schroeder EDC for one omni IR.
%
% Inputs:
%   omniIR  One real- or complex-valued impulse-response vector.
%   fs      Positive sampling rate in Hz.
%
% Outputs:
%   edcLinear   Backward-integrated squared magnitude, as a row vector.
%   edcDb       EDC independently normalized to 0 dB at its first sample.
%   timeVector  Time in seconds, as a row vector.

%% Calculate backward-integrated energy

omniIR = reshape(omniIR, 1, []);
edcLinear = flip(cumsum(flip(abs(omniIR).^2)));

%% Normalise the decay and build the time axis

edcReference = max(edcLinear(1), eps);
edcDb = 10 * log10(max(edcLinear ./ edcReference, eps));
timeVector = (0:numel(omniIR)-1) / fs;

end
