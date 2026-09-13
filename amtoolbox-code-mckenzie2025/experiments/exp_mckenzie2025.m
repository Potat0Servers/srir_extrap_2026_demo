function hFigureHandle = exp_mckenzie2025()
%exp_mckenzie2025() Reproduction of results from McKenzie & Brinkmann (2025)
%
%   Usage: hFigureHandle = exp_mckenzie();
%
%   Reproduces the results from Figure 2 in McKenzie & Brinkmann.
%
%   See also: |demo_mckenzie2025| for example usage and |mckenzie2025|
%             for the full model documentation.
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

% load listening test stimuli and regression results for other models
stimuli = data_mckenzie2025('stimuli');
regression = data_mckenzie2025('regression');

% get model predictions from mckenzie2025 ---------------------------------
experiments = fieldnames(stimuli);
predictions = [];

% get separate predictions per experiment and audio content
for ee = 1:length(experiments)
    contents = fieldnames(stimuli.(experiments{ee}));
    for cc = 1:length(contents)

        disp(['Predicting results for ' experiments{ee} ' (' contents{cc} ')'])

        current_predictions = mckenzie2025( ...
            stimuli.(experiments{ee}).(contents{cc}).reference, ...
            stimuli.(experiments{ee}).(contents{cc}).test);

        predictions = [predictions; current_predictions']; %#ok<AGROW>
    end
end

clear current_predictions

% regression analysis -----------------------------------------------------
% get ratings
ratings = [];
for ee = 1:length(experiments)
    contents = fieldnames(stimuli.(experiments{ee}));
    for cc = 1:length(contents)
        ratings = [ratings; ...
            stimuli.(experiments{ee}).(contents{cc}).ratings]; %#ok<AGROW>
    end
end

% run the regression for mckenzie2025
if exist('fitlm.m', 'file')
    regression.PBC_2_level.pooled_scaled = fitlm(predictions, ratings);
else
    disp(['Running the regression analysis requires fitlm from the ' ...
          'Statistics and Machine Learning Toolbox. Loading ' ...
          'pre-comuted results instead.'])
end

% plot results ------------------------------------------------------------

% nice model names for plotting
model_names = fieldnames(regression);
for mm = 1:length(model_names)
    name = model_names{mm};
    if strcmp('ERB', name)
        name = 'BSD$_\mathrm{\mathbf{A}}$';
    elseif strcmp('ISO532_1', name)
        name = 'ISO 532-1';
    elseif strcmp('ISO532_2', name)
        name = 'ISO 532-2';
    elseif strcmp('Moore04_sd', name)
        name = 'Moore04$_\mathrm{\mathbf{sd}}$';
    elseif strcmp('Moore04_sum', name)
        name = 'Moore04$_\mathrm{\mathbf{sum}}$';
    elseif strcmp('PBC_1', name)
        name = 'PBC-1';
    elseif strcmp('PBC_2_interaural', name)
        name = 'PBC-2$_\mathrm{\mathbf{interaural}}$';
    elseif strcmp('PBC_2_level', name)
        name = 'PBC-2$_\mathrm{\mathbf{level}}$';
    elseif strcmp('PBC_2_mean', name)
        name = 'PBC-2$_\mathrm{\mathbf{mean}}$';
    end
    model_names{mm} = name;
end

marker = {'o', 'x', 'square', 'diamond', '^'};
marker_size = [20 40 40 20 17]*.8;
font_size = 8.5;

model_order = [
    13, 11, 12, ...
    5, 6, 10, ...
    8, 9, 3, ...
    2, 7, 4];

% Setup the figure
fWidth = 18 * 1.2;
fHeight = 30 * 1.2;

hFigureHandle = figure;

% get screensize in centimeter
pixpercm = get(0,'ScreenPixelsPerInch')/2.54;
screen = get(0,'ScreenSize')/pixpercm;
% get position for figure
left   = max([(screen(3)-fWidth)/2 0]);
bottom = max([(screen(4)-fHeight)/2 0]);

set(hFigureHandle,'PaperUnits', 'centimeters');
set(hFigureHandle,'Units', 'centimeters');

% paper size for printing
set(hFigureHandle, 'PaperSize', [fWidth fHeight]);
% location on printed paper
set(hFigureHandle,'PaperPosition', [.1 .1 fWidth-.1 fHeight-.1]);
% location and size on screen
set(hFigureHandle,'Position', [left bottom fWidth fHeight]);

% set color
set(hFigureHandle, 'color', [1 1 1])

% margin (width, height)
margin_page = [.075, .06];
margin_plot = .03 * [1, fWidth/fHeight];

%height margin between scatter and residual plots
margin_1 = .005;

% scatter plot width and height
width_main = .26;
height_main = width_main * fWidth/fHeight;
% prediction error height
height_minor = height_main * .33;

% get number of ratings per dataset included in the pooled regression model
models = fieldnames(regression);
fields = fieldnames(regression.(models{1}));
n_ratings = [];
n_names = {};

for ff = 1:length(fields)
    if startsWith(fields{ff}, 'pooled')
        continue
    end

    n_ratings(end+1) = ...
        length(regression.(models{1}).(fields{ff}).Variables.x1); %#ok<SAGROW>
    n_names{end+1} = fields{ff}; %#ok<SAGROW>

end

n_end = cumsum(n_ratings);
n_start = n_end - n_ratings + 1;

for mm = 1:length(model_order)

    % current row and column
    % (counts start at 0, row count starts at bottom)
    row = ceil(mm / 3) - 1;
    col = mod(mm, 3);
    if col == 0
        col = 3;
    end
    col = col - 1;

    % get data from model
    predicted = regression.(models{model_order(mm)}).pooled_scaled.Variables.x1;
    rated = regression.(models{model_order(mm)}).pooled_scaled.Variables.y;
    residuals = -regression.(models{model_order(mm)}).pooled_scaled.Residuals.Raw;
    r_sq_adj = regression.(models{model_order(mm)}).pooled_scaled.Rsquared.Adjusted;

    % scatterplot: ratings vs. predictions -------------------------------
    subplot('position', [ ...
        margin_page(1) + col * (width_main + margin_plot(1)), ...
        margin_page(2) + row * (height_main + margin_plot(2)) + (row+1) * (height_minor + margin_1), ...
        width_main, ...
        height_main])
    hold on
    for nn = 1:length(n_ratings)
        scatter(rated(n_start(nn):n_end(nn)), ...
                predicted(n_start(nn):n_end(nn)), ...
                marker_size(nn), marker{nn})
        set(gca,'FontSize',font_size);
    end

    plot([0, 100], [0, 100], 'k')
    % build strings for model name, and statistics
    model = ['\textbf{' model_names{model_order(mm)} '}'];
    r_sq = ['$R^2_\mathrm{adj.}$=' num2str(round(r_sq_adj, 3))];
    mae = ['$\bar{|E|}$=' num2str(round(mean(abs(residuals)), 2))];
    maxae = ['$\mathrm{max}(|E|)$=' num2str(round(max(abs(residuals)), 2))];

    text(2.5, 97.5, {model r_sq mae maxae}, ...
           'HorizontalAlignment', 'left', 'VerticalAlignment','top', ...
           'Interpreter', 'latex', 'FontName', 'Arial','FontSize',font_size)
    set(gca,'FontSize',font_size)

    axis equal
    axis([0 100 0 100])
    set(gca, 'XTick', 0:20:100, 'XTickLabel', '', 'YTick', 0:20:100)
    if col ~= 0
        set(gca, 'YTickLabel', '')
    else
        ylabel('Predicted colouration')
    end
    grid on
    box on
    set(gca,'FontSize',font_size)

    % scatterplot: ratings vs. residuals ---------------------------------
    subplot('position', [ ...
        margin_page(1) + col * (width_main + margin_plot(1)), ...
        margin_page(2) + row * (height_main + margin_plot(2) + height_minor + margin_1), ...
        width_main, ...
        height_minor])
    hold on
    for nn = 1:length(n_ratings)
        scatter(rated(n_start(nn):n_end(nn)), ...
            residuals(n_start(nn):n_end(nn)), ...
            marker_size(nn),marker{nn})
        set(gca,'FontSize',font_size)
pbaspect([3.02 1 1])
    end
    plot([0, 100], [0, 0], 'k')
    axis([0 100 -50 50])
    set(gca, 'XTick', 0:20:100, 'YTick', -50:25:50, ...
        'YTickLabel', {'', -25 0 25 ''})
    if col ~= 0
        set(gca, 'YTickLabel', '')
    else
        ylabel('Pred. error')
    end
    if row ~= 0
        set(gca, 'XTickLabel', '')
    else
        xlabel('Perceived colouration')
    end
    grid on
    box on
end
set(gca,'FontSize',font_size)

% plot legend -------------------------------------------------------------
% fake suboplot to generate symbols
subplot('position', [0 0 0 0])
hold on
for nn = 1:length(n_names)
%     scatter(0, 0, markerSize(nn), marker{nn}, 'LineWidth', 1)
    scatter(0, 0, marker_size(nn), marker{nn})
set(gca,'FontSize',font_size)
end
axis([1, 2, 1, 2])
axis off
legend(n_names, 'position', [0 .003 1 .015], 'NumColumns', 5)

% force exportgraphics to use a little margin by plotting a white
% rectangle in top right corner
annotation('rectangle',[0 0 .925 .97],'Color','w');

set(gca,'FontSize',font_size)
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0 0 0.45 1]);

clear fields ff n_ratings n_names n_start n_end mm nn predicted rated ...
    models residuals r_sq_adj f_height f_width height_main height_minor ...
    margin_1 margin_h margin_w pdf width_main width_minor p reg_name ...
    reg_type row col mae maxae margin_page margin_plot marker r_sq ...
    pixpercm screen left bottom
