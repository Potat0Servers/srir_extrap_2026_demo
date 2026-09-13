% Run coupled-room SRIR comparisons for selected receiver positions.





clearvars;
clc;
clear MAIN_coupled_room_srir_comparison;


%% Dataset setup

project_root = fileparts(mfilename('fullpath'));
dataset_directory = fullfile(project_root, 'SOFAfiles');
dataset_file = fullfile(dataset_directory, 'roomToHallway_srcRoom_noLOS.sofa');
dataset_url = 'https://zenodo.org/records/7848561/files/roomToHallway_srcRoom_noLOS.sofa?download=1';
if isfile(dataset_file)
    fprintf('Dataset is ready: %s\n', dataset_file);
else
    if ~isfolder(dataset_directory); mkdir(dataset_directory); end
    fprintf('Dataset is missing; downloading from Zenodo (~ 1GB).\n');
    websave(dataset_file, dataset_url);
    fprintf('Dataset download completed: %s\n', dataset_file);
end


%% Settings

% Run all experiments? 101 × 101 = 10201 in total.
run_all = false;

% Manually set orig and tar positions, in vector (e.g. [10 20] or 1:101).
orig_pos_vec = 30;
tar_pos_vec = 60;

% plot and print table?
plot_and_table = true;

% Save csv?
save_csv = false;

% CSV save location and file name
save_directory = fullfile(fileparts(mfilename('fullpath')), 'Results');
save_file_name = 'semi_full_experiment_18_08_2026.csv';

% Save SRIRs (original/baseline/proposed/target) as SOFA files?
save_srir = false;

% SRIR save location (root 'SRIR outputs' folder)
save_srir_directory = fullfile(fileparts(mfilename('fullpath')), 'SRIR outputs');



%% Run script

if run_all
    orig_pos_vec = 1:101;
    tar_pos_vec = 1:101;
    plot_and_table = false; % protection 
    save_srir = false;      % protection
end

for orig = orig_pos_vec
    for tar = tar_pos_vec
        fprintf("Running %d -> %d...\n", orig, tar);
        MAIN_coupled_room_srir_comparison( ...
            orig, ...
            tar, ...
            plot_and_table, ...
            save_csv, ...
            save_directory, ...
            save_file_name, ...
            save_srir, ...
            save_srir_directory);
    end
end

