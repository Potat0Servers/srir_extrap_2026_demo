function arrival_out = scale_srir_arrival(arrival_in, path_gain)
%SCALE_SRIR_ARRIVAL Apply one path-distance gain to an extracted arrival.

%% Check and apply the computed gain

if ~isfinite(path_gain)
    error('scale_srir_arrival:NonFiniteGain', 'The calculated path gain must be finite.');
end

arrival_out = arrival_in * path_gain;

end
