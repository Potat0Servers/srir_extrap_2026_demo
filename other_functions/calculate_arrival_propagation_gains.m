function path_gains = calculate_arrival_propagation_gains(path_info)
%CALCULATE_ARRIVAL_PROPAGATION_GAINS Turn path-distance changes into gains.

%% Calculate distance-ratio gains

path_gains = path_info.dist.orig ./ path_info.dist.tar;

end
