function [edcDb, timeVector, receiverIdx] = ...
    compute_omni_energy_decay_from_sofa(sofaObj, channelIdx)
%COMPUTE_OMNI_ENERGY_DECAY_FROM_SOFA Normalized EDCs for a SOFA channel.

if nargin < 2 || isempty(channelIdx)
    channelIdx = 1;
end

fs = sofaObj.Data.SamplingRate;
irData = sofaObj.Data.IR;

nReceivers = size(irData,1);
nChannels = size(irData,2);
nSamples = size(irData,3);

if channelIdx < 1 || channelIdx > nChannels || channelIdx ~= round(channelIdx)
    error('compute_omni_energy_decay_from_sofa:InvalidChannel', ...
        'channelIdx must be an integer between 1 and %d.', nChannels);
end

omniIR = squeeze(irData(:,channelIdx,:));
if nReceivers == 1
    omniIR = reshape(omniIR,1,nSamples);
end

edcDb = zeros(nReceivers, nSamples);
timeVector = [];
for receiverIdxCurrent = 1:nReceivers
    [~, edcDb(receiverIdxCurrent,:), timeVector] = ...
        compute_omni_energy_decay_from_ir( ...
            omniIR(receiverIdxCurrent,:), fs);
end

receiverIdx = (1:nReceivers).';
end
