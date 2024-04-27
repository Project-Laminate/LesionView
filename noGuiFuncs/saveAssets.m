function app = saveAssets(app)
app = updateLesionSize(app);


outputDir = fullfile(app.bidsDir,'derivatives','Assets',app.subject);
if ~isfolder(outputDir)
    mkdir(outputDir)
else
    delete(dir(fullfile(outputDir,'*'))); % clear all
end

%% Process and display each image

% Export only the new lesions that have passed the review
app = updateNewGoneLesionIndex(app);
app.newLesionIndexExport = [];
for ii = 1:numel(app.newLesionIndex)
    if strcmp(app.LesionReviewStates(app.newLesionIndex(ii),2), 'keep')
        app.newLesionIndexExport = [app.newLesionIndexExport; app.newLesionIndex(ii)];
    end
end
app.goneLesionIndexExport = [];
for ii = 1:numel(app.goneLesionIndex)
    if strcmp(app.LesionReviewStates(app.goneLesionIndex(ii),2), 'keep')
        app.goneLesionIndexExport = [app.goneLesionIndexExport; app.goneLesionIndex(ii)];
    end
end

for k = 1:2 %  loop through two images
    disp(['Saving to report: 3D view timepoint ' num2str(k) ' ...'])
    app.currentImageIndex = 3 - k;
    app.LesionVisibilitySwitch.Value = 'All';
    app = toggleT2Image(app); % update the visualization

    % update lesion color
    for ii = 1:numel(app.lesionPatches)
        patchInfo = app.lesionPatches{ii};
        if ~isempty(patchInfo)
            lesionPatch = patchInfo{1}; % The patch object
            if isvalid(lesionPatch)
                if sum(double(patchInfo{3} == app.newLesionIndexExport))>0
                    if app.currentImageIndex == 2
                        lesionPatch.FaceColor = [0 1 0]; % new lesion green
                        lesionPatch.FaceAlpha = 1;
                    else
                        lesionPatch.FaceAlpha = 0;
                    end
                elseif sum(double(patchInfo{3} == app.goneLesionIndexExport))>0
                    if app.currentImageIndex == 1
                        lesionPatch.FaceColor = app.blueColor; % disappearing lesion blue
                        lesionPatch.FaceAlpha = 1;
                    else
                        lesionPatch.FaceAlpha = 0;
                    end
                else
                    % draw the rest only if it's marked as keep
                    if strcmp(app.LesionReviewStates(patchInfo{3},patchInfo{2}), 'keep')
                        lesionPatch.FaceColor = [0.9 0.9 0.9]; % other lesion no color
                        lesionPatch.FaceAlpha = 0.5;
                        % don't draw deleted lesions
                    elseif  strcmp(app.LesionReviewStates(patchInfo{3},patchInfo{2}), 'delete')
                        lesionPatch.FaceAlpha = 0;
                    end
                end
            end
        end
    end

    % Temporarily export each frame to a PNG file for high-resolution capture
    view(app.LesionVisualizationAxes, [0 1 0]); % Set view
    tempFilename1 = sprintf('%s/3dSagittal_%d.png', outputDir, k);
    exportgraphics(app.LesionVisualizationAxes, tempFilename1, 'Resolution', 300);
    view(app.LesionVisualizationAxes, [1 0 0]); % Set view
    tempFilename1 = sprintf('%s/3dCoronal_%d.png', outputDir, k);
    exportgraphics(app.LesionVisualizationAxes, tempFilename1, 'Resolution', 300);
    view(app.LesionVisualizationAxes, [0 0 1]); % Set view to Axial
    tempFilename1 = sprintf('%s/3dAxial_%d.png', outputDir, k);
    exportgraphics(app.LesionVisualizationAxes, tempFilename1, 'Resolution', 300);
end


%% bar graph of lesion size change
app.fig = figure;
barPlotAxes = axes('Parent', app.fig, 'Position', [0.15, 0.5, 0.7, 0.15]);
hold(barPlotAxes, 'on');

% Define bar width
barWidth = 0.4;
% Create x values for baseline and follow-up groups
xBase = 1:size(app.sizeChange, 1); % Baseline lesions
xFollow = xBase + barWidth; % Follow-up lesions, plotted next to baseline

% Plot baseline bars in gray
bar(barPlotAxes, xBase, app.sizeChange(:, 1), barWidth, 'FaceColor', [0.8 0.8 0.8], 'EdgeColor', 'none');

% Plot follow-up bars, color by size change
for ii = 1:length(xBase)
    if app.sizeChange(ii, 3) > 0
        % Lesion size increased - color red
        followColor = [237 106 94]./255;
    else
        % Lesion size decreased or unchanged - color blue
        followColor = [83 131 236]./255;
    end
    bar(barPlotAxes, xFollow(ii), app.sizeChange(ii, 2), barWidth, 'FaceColor', followColor, 'EdgeColor', 'none');
end
% Customize the plot appearance
title(barPlotAxes, 'Size change between baseline and followup');
ylabel(barPlotAxes, 'Volume (ml)');
xlabel(barPlotAxes, 'Individual lesions sorted by size');
set(barPlotAxes, 'LineWidth', 2, 'FontSize', 15, 'FontWeight', 'bold', 'FontAngle', 'italic', 'TickDir', 'out', 'XTick', [], 'XTickLabel', []);

tempFilename1 = sprintf('%s/barLesionSize.png',outputDir);
exportgraphics(barPlotAxes, tempFilename1, 'Resolution', 300);

%% Draw the largest lesion on bottom of page 1


app.LesionVisibilitySwitch.Value = 'One';
app.NewLesionCheckBox.Value = 0;
app.DisappearingCheckBox.Value = 0;
app = checkWhichIndexList(app);

lesionExpo = [1; app.newLesionIndexExport; app.goneLesionIndexExport];

for whichLesion = 1:numel(lesionExpo)
    app.currentIndex = lesionExpo(whichLesion);

    for ii = 1:2 % overlay yes and no
        app.OverlayAlpha.Value = ii-1;

        for k = 1:2 % Assuming you want to loop through two images
            disp(['Saving to report: 2D view lesion ' num2str(app.currentIndex) ' timepoint ' num2str(3-k) ' - ' num2str(ii) '...'])
            app.currentImageIndex = 3 - k;

            app.x0.Value = app.lesionCenter(app.currentIndex,1);
            app.y0.Value = app.lesionCenter(app.currentIndex,2);
            app.z0.Value = app.lesionCenter(app.currentIndex,3);
            app = updateImage(app); % sometimes it's too slow

            % Temporarily export each frame to a PNG file for high-resolution capture
            if ismember(app.currentIndex,app.newLesionIndexExport)
                tempFilename1 = sprintf('%s/lesionNew%d_%d_%d.png',outputDir, app.currentIndex, app.currentImageIndex,app.OverlayAlpha.Value);
                exportgraphics(app.UIAxes, tempFilename1, 'Resolution', 300);
            elseif ismember(app.currentIndex,app.goneLesionIndexExport)
                tempFilename1 = sprintf('%s/lesionDisp%d_%d_%d.png',outputDir, app.currentIndex, app.currentImageIndex,app.OverlayAlpha.Value);
                exportgraphics(app.UIAxes, tempFilename1, 'Resolution', 300);
            else
                tempFilename1 = sprintf('%s/lesion%d_%d_%d.png',outputDir, app.currentIndex, app.currentImageIndex,app.OverlayAlpha.Value);
                exportgraphics(app.UIAxes, tempFilename1, 'Resolution', 300);
            end

        end
    end
end

tmp = round(app.sizeChange,3);
tmp(:,4) = round(tmp(:,3) ./ app.voxelSize);
tmp(:,5) = round(tmp(:,3)./tmp(:,1)*100);
writematrix(tmp, sprintf('%s/lesionSize.txt',outputDir));




end
