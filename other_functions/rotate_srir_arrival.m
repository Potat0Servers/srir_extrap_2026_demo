function arrival_out = rotate_srir_arrival(arrival_in, doa_orig_deg, doa_tar_deg)
%ROTATE_SRIR_ARRIVAL Rotate one HOA arrival from its measured to target DoA.

%% Calculate and apply the wrapped rotation

doa_orig_deg = doa_orig_deg(:);
doa_tar_deg = doa_tar_deg(:);
rotation_deg = mod(doa_tar_deg - doa_orig_deg + 180, 360) - 180;
arrival_out = rotateHOA_N3D(arrival_in, rotation_deg(1), rotation_deg(2), 0);

end
