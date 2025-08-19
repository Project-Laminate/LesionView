classdef lesionView_converted < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        LeftPanel                matlab.ui.container.Panel
        LesionReviewButtonGroup  matlab.ui.container.ButtonGroup
        UpdateButton             matlab.ui.control.Button
        LesionEditButtonGroup    matlab.ui.container.ButtonGroup
        ResetButton              matlab.ui.control.ToggleButton
        Clone2Button             matlab.ui.control.ToggleButton
        Clone1Button             matlab.ui.control.ToggleButton
        MergeButton              matlab.ui.control.ToggleButton
        TextArea                 matlab.ui.control.TextArea
        DeleteButton             matlab.ui.control.ToggleButton
        DraftButton              matlab.ui.control.ToggleButton
        KeepButton               matlab.ui.control.ToggleButton
        LesionIndexSpinner       matlab.ui.control.Spinner
        LesionVisibilitySwitch   matlab.ui.control.Switch
        XButton                  matlab.ui.control.Button
        YButton                  matlab.ui.control.Button
        ZButton                  matlab.ui.control.Button
        RButton                  matlab.ui.control.Button
        DisappearingCheckBox     matlab.ui.control.CheckBox
        NewLesionCheckBox        matlab.ui.control.CheckBox
        EnlargingCheckBox        matlab.ui.control.CheckBox
        goToLastLes              matlab.ui.control.Button
        goToFirstLes             matlab.ui.control.Button
        OverlayAlpha             matlab.ui.control.Slider
        LoadBIDSButton           matlab.ui.control.Button
        ExportNIfTIButton        matlab.ui.control.Button
        ProgressTextArea         matlab.ui.control.TextArea
        ButtonGroup              matlab.ui.container.ButtonGroup
        PlayButton               matlab.ui.control.ToggleButton
        Button_2                 matlab.ui.control.ToggleButton
        Button                   matlab.ui.control.ToggleButton
        y0                       matlab.ui.control.Spinner
        z0                       matlab.ui.control.Spinner
        x0                       matlab.ui.control.Spinner
        progressBarFront         matlab.ui.control.TextArea
        PleasewaitLabel          matlab.ui.control.Label
        ExportPDFButton          matlab.ui.control.Button
        LesionVisualizationAxes  matlab.ui.control.UIAxes
        UIAxes                   matlab.ui.control.UIAxes
    end


    properties (Access = private)

        % General properties
        subject = 'sub - xxx'; % e.g. sub-001 - Identifier for the subject
        bidsDir
        lesionDerivDir
        voxelSize = 0.7*0.7*0.7./1000; % Voxel size for the images, adjust based on your data
        FlairInfo % metadata - Information about the T2 flair images (used for saving or processing)
        fileStatus = [false,false,false,false,false]; % whether each files are loaded
        allowKey = 0;
        tmpworkdir;
        firstSesName;
        lastSesName;
        

        % Image data properties
        FlairTP1 % 3D matrix - T2 flair image at time point 1
        FlairTP2 % 3D matrix - T2 flair image at time point 2
        Lesion1 % 3D matrix - Lesion image at time point 1
        Lesion2 % 3D matrix - Lesion image at time point 2
        brainMask % 3D matrix - Brain mask image for overlay or masking purposes
        tmpLesionNameClean1
        tmpLesionNameDraft1
        tmpLesionNameClean2
        tmpLesionNameDraft2

        % Image analyses properties
        L1 % 3D matrix - Processed lesion image with lables at time point 1 for analysis
        L2 % 3D matrix - Processed lesion image with lables at time point 2 for analysis
        L1backUp % 3D matrix - backup of L1
        L2backUp % 3D matrix - backup of L2
        whichT2 % 3D matrix - The variable to hold the currently selected 3D T2 image data
        whichLes % 3D matrix - The variable to hold the currently selected lesion data
        sizeChange % numLes by 3 - [size1, size2, size2-size1] - To store the results of lesion size change analysis
        lesionCenter % numLes by 3 - [x, y, z] - Center coordinates of lesions, used for visualization adjustments

        % Indexing
        currentIndex = 1 % scaler - Index of the currently selected lesion for processing
        currentImageIndex = 1 % 1 or 2 - Indicates the current image being displayed (1 for FlairTP1, 2 for FlairTP2)
        lesionIndex % numLes by 1 - Array of unique indices for each lesion
        newLesionIndex % numNewLes by 1 - of new lesions in time point 2 that didn't exist in time point 1
        goneLesionIndex % numGoneLes by 1 - of lesions in time point 1 that didn't exist in time point 2
        enlargeLesionIndex % numLargeLes by 1 - of lesions in time point 2 that are larger than in time point 1
        whichIndex % which index list are currently being use, i.e, are we viewing all lesions or only new lesion etc
        largestLesion = 1

        newLesionIndexExport % same with newLesionIndex but must pass the review process as 'keep'
        goneLesionIndexExport % same with goneLesionIndex but must pass the review process as 'keep'
        enlargeLesionIndexExport % same with enlargeLesionIndex but must pass the review process as 'keep'

        % Visualization and UI elements
        lesionPatches % numLes*2 by 1 cells - each cell is 1 by 3 cells - patch, timepoint, index - Stores patch objects for visualizing lesions
        brainMaskPatch % Stores patch objects for visualizing the brain mask
        sizeZoom double = 26; % Zoom window size for detailed lesion viewing
        ImageSwitchTimer % Timer for auto-switching between images
        rotationTimer % Timer for rotating the 3D visualization
        hLes % Placeholder for lesion visualization handles
        fig % Main figure for export
        progressBarLength
        blueColor = [0,120,255]./255;


        % Lesion processing and review properties
        Lesion1Clean % 3D matrix - Cleaned lesion image at time point 1
        Lesion1Draft % 3D matrix - Draft lesion image at time point 1
        Lesion2Clean % 3D matrix - Cleaned lesion image at time point 2
        Lesion2Draft % 3D matrix - Draft lesion image at time point 2
        newLesionMask % % 3D matrix - Cleaned lesion image at time point 2 (color coded 1 2 3)
        LesionReviewStates % numLes by 2 time points - Stores the review state ('keep', 'draft', 'delete') for each lesion
        LesionEditStates % numLes by 2 time points - Stores the edit state ('merge', 'clone1', 'clone2','reset') for each lesion
    end


    methods (Access = private)

        function updateImage(app)

            % this function prepares the 2D view

            % the figure has 6 sections ( 2 rows by 3 cols)
            % bottom 1 by 3 are sagittal coronal and axial views
            % top 1 by 3 are the zoomed in version of the bottom row

            % This way we make one big figure instead of handling 6
            % different axes, which I thought would be more painful

            % Extract slices for the bottom row images
            img21 = squeeze(app.whichT2(app.x0.Value,:,:))'; % sagittal
            img22 = squeeze(app.whichT2(:,app.y0.Value,:))'; % coronal
            img23 = squeeze(app.whichT2(:,:,app.z0.Value)); % axial

            % Combine them horizontally
            botrow = [img21 img22 img23];

            % Calculate padding because the images are wider than a square
            padding = (size(botrow,2) - size(botrow,1)*3) / 2;

            % Extract and resize the zoomed-in images for the top row
            % sagittal view is bounded by y/z
            % coronal view is bounded by x/z
            % axial view is bounded by x/y

            img11 = imresize(img21(max(1, app.z0.Value - app.sizeZoom):min(end, app.z0.Value + app.sizeZoom), max(1, app.y0.Value - app.sizeZoom):min(end, app.y0.Value + app.sizeZoom)), [size(botrow,1) size(botrow,1)], 'nearest');
            img12 = imresize(img22(max(1, app.z0.Value - app.sizeZoom):min(end, app.z0.Value + app.sizeZoom), max(1, app.x0.Value - app.sizeZoom):min(end, app.x0.Value + app.sizeZoom)), [size(botrow,1) size(botrow,1)], 'nearest');
            img13 = imresize(img23(max(1, app.x0.Value - app.sizeZoom):min(end, app.x0.Value + app.sizeZoom), max(1, app.y0.Value - app.sizeZoom):min(end, app.y0.Value + app.sizeZoom)), [size(botrow,1) size(botrow,1)], 'nearest');

            % Combine the top row images with padding
            toprow = [zeros(size(botrow,1), floor(padding)-20), img11, zeros(size(botrow,1), 20), img12, zeros(size(botrow,1), 20), img13, zeros(size(botrow,1), ceil(padding)-20)];

            % Combine top and bottom rows
            img = [toprow; botrow];

            % Display the combined image in UIAxes
            if ~isempty(app.FlairTP1) && ~isempty(app.FlairTP2)
                imshow(img,'DisplayRange', [50 250], 'Parent', app.UIAxes); % adjust color range when Flair is loaded 
            else
                imshow(img, 'Parent', app.UIAxes);
            end

            hold(app.UIAxes, 'on'); % Keep the original image, allowing overlays to be added

            % Prepare lesion overlays
            if app.currentImageIndex == 1
                if ~isempty(app.L1)
                    currentLesionMask = flip(app.L1, 2);
                    currentLesionMask = flip(currentLesionMask, 3);
                    currentLesionMask(ismember(currentLesionMask,app.lesionIndex(app.LesionReviewStates(:,1)=="delete"))) = 0;
                else
                    currentLesionMask = app.whichLes;
                end

            else
                if ~isempty(app.L2)
                    currentLesionMask = flip(app.L2, 2);
                    currentLesionMask = flip(currentLesionMask, 3);
                    currentLesionMask(ismember(currentLesionMask,app.lesionIndex(app.LesionReviewStates(:,2)=="delete"))) = 0;

                else
                    currentLesionMask = app.whichLes;
                end
            end


            if strcmp(app.LesionVisibilitySwitch.Value, 'All')
                currentLesionMask(currentLesionMask>0.5) = 1;
            else % For "One" state, only the selected lesion is fully visible
                currentLesionMask(currentLesionMask~=app.currentIndex) = 0;
            end


            les21 = mat2gray(squeeze(currentLesionMask(app.x0.Value,:,:)))';
            les22 = mat2gray(squeeze(currentLesionMask(:,app.y0.Value,:)))';
            les23 = mat2gray(squeeze(currentLesionMask(:,:,app.z0.Value)));


            % Combine lesion overlays horizontally for the bottom row
            botles = [les21 les22 les23];

            % Resize and prepare lesion overlays for the top row
            les11 = imresize(les21(app.z0.Value - app.sizeZoom:app.z0.Value + app.sizeZoom, app.y0.Value - app.sizeZoom:app.y0.Value + app.sizeZoom), [size(botrow,1) size(botrow,1)], 'nearest');
            les12 = imresize(les22(app.z0.Value - app.sizeZoom:app.z0.Value + app.sizeZoom, app.x0.Value - app.sizeZoom:app.x0.Value + app.sizeZoom), [size(botrow,1) size(botrow,1)], 'nearest');
            les13 = imresize(les23(app.x0.Value - app.sizeZoom:app.x0.Value + app.sizeZoom, app.y0.Value - app.sizeZoom:app.y0.Value + app.sizeZoom), [size(botrow,1) size(botrow,1)], 'nearest');
            toples = [zeros(size(botrow,1), padding-20) les11 zeros(size(botrow,1), 20) les12 zeros(size(botrow,1), 20) les13 zeros(size(botrow,1), padding-20)];

            % Combine top and bottom lesion overlays
            img1 = [toples; botles];
            img1 = double(img1>0.5);
            img1 = bwperim(img1, 8);

            img1 = imdilate(bwperim(img1, 8), strel('disk', 1));

            tmpImg = zeros(size(img1, 1), size(img1, 2), 3); % Initialize RGB image
            if app.currentImageIndex == 1
                tmpImg = double(img1) .* reshape(app.blueColor, [1, 1, 3]);
            else
                tmpImg(:,:,2) = img1; % Green channel
            end

            app.hLes = imshow(tmpImg, 'Parent', app.UIAxes);


            set(app.hLes, 'AlphaData',double(img1) * app.OverlayAlpha.Value);


            startXImg22 = size(img21, 2) + 1;
            startXImg23 = startXImg22 + size(img22, 2);
            startY = size(img21, 1) + 1;

            % Define the zoom area for each image based on the spinner values
            zoomAreaSize = 2 * app.sizeZoom; % The size of the zoomed area

            % Drawing rectangle for img21 (no adjustment needed for startX)
            rectangle('Position', [app.y0.Value - app.sizeZoom, startY + app.z0.Value - app.sizeZoom, zoomAreaSize, zoomAreaSize], 'EdgeColor', 'w', 'LineWidth', 1, 'Parent', app.UIAxes);

            % Drawing rectangle for img22 (adjust startX for img22)
            rectangle('Position', [startXImg22 + app.x0.Value - app.sizeZoom, startY + app.z0.Value - app.sizeZoom, zoomAreaSize, zoomAreaSize], 'EdgeColor', 'w', 'LineWidth', 1, 'Parent', app.UIAxes);

            % Drawing rectangle for img23 (adjust startX for img23)
            rectangle('Position', [startXImg23 + app.y0.Value - app.sizeZoom, startY + app.x0.Value - app.sizeZoom, zoomAreaSize, zoomAreaSize], 'EdgeColor', 'w', 'LineWidth', 1, 'Parent', app.UIAxes);

            timePointText = sprintf('Time %d', app.currentImageIndex); % Convert index to text

            text(app.UIAxes, 0.95, 0.15, timePointText, 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', 'white', 'FontSize', 15, 'FontWeight', 'bold');
            text(app.UIAxes, 0.82, 0.15, 'L', 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', [0.5 0.5 0.5], 'FontSize', 15, 'FontWeight', 'bold','FontAngle','italic');
            text(app.UIAxes, 0.62, 0.28, 'L', 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', [0.5 0.5 0.5], 'FontSize', 15, 'FontWeight', 'bold','FontAngle','italic');

            hold(app.UIAxes, 'off'); % Release the hold to prevent further overlays on top

        end


        function toggleT2Image(app)

            % Toggles between T2 Flair images from baseline and followup
            % Updates the currently displayed T2 Flair and lesion images

            if app.currentImageIndex == 1 % if current time is baseline
                app.currentImageIndex = 2; % we switch to followup
                if isempty(app.FlairTP2) % if followup T2 flair is not loaded
                    app.whichT2 = rand(260, 311, 260); % we assign some random number
                else % if followup T2 flair is loaded
                    app.whichT2 = app.FlairTP2; % switch to followup T2 flair
                end

            else % if current time is followup
                app.currentImageIndex = 1; % switch to baseline
                if isempty(app.FlairTP1) % if baseline T2 flair is not loaded
                    app.whichT2 = rand(260, 311, 260);  % assign some random number
                else  % if baseline T2 flair is loaded
                    app.whichT2 = app.FlairTP1; % Set to baseline T2 flair
                end

            end

            updateImage(app); % Refresh the T2 flair image display

            updateLesionVisibility(app);

        end


        function analyzeLesions(app)
            close all;
            % This function analyzes lesions across two time points to identify new,
            % continuing, and merged lesions. It labels each lesion, matches lesions
            % across time points, calculates their volumes, and updates the UI
            % components accordingly.

            % Label the lesions in each time point image using a binary threshold of 0.8
            % and a connectivity of 26.
            [app.L1, ~] = bwlabeln(app.Lesion1 > 0.8, 26);
            [app.L2, ~] = bwlabeln(app.Lesion2 > 0.8, 26);

            % Initialize arrays to store new indices for matched lesions across time points
            lesion1index = nonzeros(unique(app.L1));
            lesion2index = nonzeros(unique(app.L2));
            lesion1indexNew = zeros(size(lesion1index));
            lesion2indexNew = zeros(size(lesion2index));

            updateProgress(app,['Matching lesions across two time points ...']);

            % Loop through each lesion index in time point 1 and match with lesions in time point 2
            % this is stupid
            for i1 = 1:numel(lesion1index)

                updateProgressBar(app, 100/3+round(i1 / numel(lesion1index) * 100/3));
                updateProgress(app,sprintf('Matching lesions across two time points ... %d out of %d done',i1,numel(lesion1index)));

                for i2 = 1:numel(lesion2index)
                    % Check if lesions overlap between time points
                    match = (app.L1 == i1) & (app.L2 == i2);
                    if sum(match(:)) > 0
                        % Assign matching lesions the same new index
                        if lesion2indexNew(i2) == 0
                            lesion2indexNew(i2) = i1;
                        else
                            % Handle merged lesions by assigning them the index of the merging lesion
                            lesion1indexNew(i1) = lesion2indexNew(i2);
                        end
                    end
                end
            end


            lesion1indexNew(lesion1indexNew==0) = lesion1index(lesion1indexNew==0);
            lesion2indexNew(lesion2indexNew==0) = max(lesion1index)+1:max(lesion1index)+sum(lesion2indexNew==0);

            valueToIndex = containers.Map(unique([lesion1indexNew;lesion2indexNew]), 1:numel(unique([lesion1indexNew;lesion2indexNew])));
            lesion1indexNew = arrayfun(@(x) valueToIndex(x),lesion1indexNew);
            lesion2indexNew = arrayfun(@(x) valueToIndex(x),lesion2indexNew);

            [~, loc] = ismember(app.L1, lesion1index);
            loc(loc > 0) = lesion1indexNew(loc(loc > 0));
            app.L1(loc > 0) = loc(loc > 0);
            [~, loc] = ismember(app.L2, lesion2index);
            loc(loc > 0) = lesion2indexNew(loc(loc > 0));
            app.L2(loc > 0) = loc(loc > 0);

            updateProgress(app,'Sorting lesions by size ...')
            newlist = unique([lesion1indexNew; lesion2indexNew]);
            lesionVol = zeros(nnz(newlist), 1);
            for ii = 1:nnz(newlist)
                lesionVol(ii) = max([nnz(app.L1 == ii) nnz(app.L2 == ii)]); % Number of voxels in the ith lesion
            end

            [~,newlistOrder] = sort(lesionVol,'descend');

            [~, loc] = ismember(app.L1, newlistOrder);
            loc(loc > 0) = newlist(loc(loc > 0));
            app.L1(loc > 0) = loc(loc > 0);

            [~, loc] = ismember(app.L2, newlistOrder);
            loc(loc > 0) = newlist(loc(loc > 0));
            app.L2(loc > 0) = loc(loc > 0);

            % remove any lesion size less than xxx
            app.L1(ismember(app.L1, find(sort(lesionVol,'descend')<3))) = 0;
            app.L2(ismember(app.L2, find(sort(lesionVol,'descend')<3))) = 0;

            updateProgress(app,'Calculating lesion centers ...')

            % Calculate the center of each lesion for visualization
            app.lesionIndex = nonzeros(unique([app.L1; app.L2])); % Combined list of unique lesion indices
            app.lesionCenter = zeros(numel(app.lesionIndex), 3);
            % Note: Image orientation adjustments might be necessary for correct visualization
            tmpL1 = flip(app.L1, 2);
            tmpL1 = flip(tmpL1, 3);
            tmpL2 = flip(app.L2, 2);
            tmpL2 = flip(tmpL2, 3);

            % Initialize the matrix to store size changes across two time points
            app.sizeChange = zeros(numel(app.lesionIndex), 3);

            for ii = 1:numel(app.lesionIndex)
                % Generate binary matrices for each lesion by comparing with their indices
                binaryMat = tmpL1 == app.lesionIndex(ii);
                % Count the number of true values (lesion volume) in time point 1
                app.sizeChange(ii, 1) = sum(binaryMat(:));
                % Repeat for time point 2
                tmp2 = tmpL2 == app.lesionIndex(ii);
                app.sizeChange(ii, 2) = sum(tmp2(:));
                % If a lesion is not present in time point 1, use its presence in time point 2
                if sum(binaryMat(:)) < 1
                    binaryMat = tmp2;
                end
                % Calculate the centroid of the lesion by finding the index of maximum sum along each dimension
                [~, app.lesionCenter(app.lesionIndex(ii), 1)] = max(squeeze(sum(sum(binaryMat, 2), 3)));
                [~, app.lesionCenter(app.lesionIndex(ii), 2)] = max(squeeze(sum(sum(binaryMat, 1), 3)));
                [~, app.lesionCenter(app.lesionIndex(ii), 3)] = max(squeeze(sum(sum(binaryMat, 1), 2)));
            end
            % Calculate the change in lesion size between two time points and convert to volume
            app.sizeChange(:, 3) = app.sizeChange(:, 2) - app.sizeChange(:, 1);
            app.sizeChange  =  app.sizeChange * app.voxelSize;
            
            % which lesions have grown in size
            app.enlargeLesionIndex = find(app.sizeChange(:,3)>0&app.sizeChange(:,1)>=1e-10);
            if isempty(app.enlargeLesionIndex)
                app.EnlargingCheckBox.Enable = 'off';
            else
                app.EnlargingCheckBox.Enable = 'on';
            end

            % Set the limits and enable the lesion index spinner based on available lesions
            app.LesionIndexSpinner.Limits = [1, size(app.lesionCenter, 1)];
            app.LesionIndexSpinner.Enable = 'on';

            % Initialize the review states for each lesion across both time points as "keep"
            app.LesionReviewStates = repmat("keep", numel(app.lesionIndex), 2);
            app.LesionEditStates = repmat("reset", numel(app.lesionIndex), 1);

            % Prepare clean and draft lesion matrices and backup for both time points
            app.Lesion1Clean = app.L1;
            app.Lesion1Draft = zeros(size(app.L1));
            app.Lesion2Clean = app.L2;
            app.Lesion2Draft = zeros(size(app.L2));
            app.L1backUp = app.L1;
            app.L2backUp = app.L2;

            % Display summary information about lesions in TextArea
            app.currentIndex = 1;
            infoText = sprintf('Time 1 - %d lesions (%.3f ml) - #%d: %d mm^3\nTime 2 - %d lesions (%.3f ml) - #%d: %d mm^3', ...
                sum(app.LesionReviewStates(:,1) ~= "delete"), sum(app.sizeChange(:,1)), app.currentIndex, floor(app.sizeChange(app.currentIndex,1) * 1000), ...
                sum(app.LesionReviewStates(:,2) ~= "delete"), sum(app.sizeChange(:,2)), app.currentIndex, floor(app.sizeChange(app.currentIndex,2) * 1000));
            app.TextArea.Value = infoText;


            % Identify new lesions in time point 2 that were not present in time point 1
            updateNewGoneLesionIndex(app);

            
            app.x0.Value = app.lesionCenter(app.currentIndex,1);
            app.y0.Value = app.lesionCenter(app.currentIndex,2);
            app.z0.Value = app.lesionCenter(app.currentIndex,3);

            % 
            % % Define a proper directory path for temporary work files
            % app.tmpworkdir = fullfile(app.bidsDir, 'derivatives','tmpworkdir', app.subject);
            % 
            % % Create the directory if it doesn't exist
            % if ~exist(app.tmpworkdir, 'dir')
            %     mkdir(app.tmpworkdir);
            % end
            % 
            % % Build a filename that includes subject, app.lesionDerivDir, and the two sessions
            % fileName = sprintf('%s_%s_%s_%s.mat', ...
            %     app.subject, ...
            %     app.lesionDerivDir, ...
            %     app.firstSesName, ...
            %     app.lastSesName);
            % 
            % % Finally, save the MAT file with the new name
            % save(fullfile(app.tmpworkdir, fileName),'app');

        end

        function updateNewGoneLesionIndex(app)

            app.NewLesionCheckBox.Value = 0;
            app.DisappearingCheckBox.Value = 0;            

            % Identify new lesions in time point 2 that were not present in time point 1
            % we don't delete from app.L1.
            tmp1 = app.L1;
            tmp1(ismember(tmp1,app.lesionIndex(app.LesionReviewStates(:,1)=="delete"))) = 0;
            tmp2 = app.L2;
            tmp2(ismember(tmp2,app.lesionIndex(app.LesionReviewStates(:,2)=="delete"))) = 0;

            lesionList1 = unique(tmp1);
            lesionList2 = unique(tmp2);
            app.newLesionIndex = lesionList2(~ismember(unique(tmp2), unique(tmp1)));
            app.goneLesionIndex = lesionList1(~ismember(unique(tmp1), unique(tmp2)));

            if isempty(app.newLesionIndex)
                app.NewLesionCheckBox.Enable = 'off';               
            else
                app.NewLesionCheckBox.Enable = 'on';
            end

            if isempty(app.goneLesionIndex)
                app.DisappearingCheckBox.Enable = 'off';
            else
                app.DisappearingCheckBox.Enable = 'on';
            end
        end


        function drawBrainMask(app)
            if ~isempty(app.brainMask)
                [x, y, z] = meshgrid(1:size(app.brainMask,2), 1:size(app.brainMask,1), 1:size(app.brainMask,3));
                [f, v] = isosurface(x, y, z, app.brainMask, 0.5);
                app.brainMaskPatch = patch(app.LesionVisualizationAxes, 'Faces', f, 'Vertices', v, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.03);
                view(app.LesionVisualizationAxes, 3);
                axis(app.LesionVisualizationAxes, 'equal');
                axis(app.LesionVisualizationAxes, 'off');
                camlight(app.LesionVisualizationAxes, 'headlight');
                lighting(app.LesionVisualizationAxes, 'gouraud');
            end
        end

        function drawLesions(app)

            [x, y, z] = meshgrid(1:size(app.L1,2), 1:size(app.L1,1), 1:size(app.L1,3));
            app.lesionPatches = cell(numel(app.lesionIndex)*2,1);

            for idx = 1:numel(app.lesionIndex)
                updateProgress(app,['Drawing lesion # ' num2str(idx) ' ...'])
                updateProgressBar(app, 200/3+round(idx / numel(app.lesionIndex) * 100/3))
                drawLesion(app, app.lesionIndex(idx), x, y, z);
            end
            updateProgress(app,'Done!')
        end

        function drawLesion(app, idx, x, y, z)
            % Draw lesion for L1

            if any(app.L1(:) ==  app.lesionIndex(idx))
                drawMat = app.L1 ==  app.lesionIndex(idx);
                if nnz(drawMat) > 0 % Check if non-empty
                    [f, v] = isosurface(x, y, z, drawMat, 0.8);
                    lesionPatch = patch(app.LesionVisualizationAxes, 'Faces', f, 'Vertices', v, 'FaceColor', app.blueColor, 'FaceAlpha', 0, 'EdgeColor', 'none'); % Initially invisible
                    app.lesionPatches{app.lesionIndex(idx)} = {lesionPatch, 1, idx}; % Time point 1
                end
            end

            % Repeat for L2 with appropriate checks and adjustments
            if any(app.L2(:) ==  app.lesionIndex(idx))
                drawMat = app.L2 ==  app.lesionIndex(idx);
                if nnz(drawMat) > 0
                    [f, v] = isosurface(x, y, z, drawMat, 0.8);
                    lesionPatch = patch(app.LesionVisualizationAxes, 'Faces', f, 'Vertices', v, 'FaceColor', 'green', 'FaceAlpha', 0, 'EdgeColor', 'none'); % Initially invisible
                    app.lesionPatches{numel(app.lesionIndex)+app.lesionIndex(idx)} = {lesionPatch, 2, idx}; % Time point 2
                end
            end
        end

        function editLesion(app)
            % for editing purpose, different from the initial drawing
            [x, y, z] = meshgrid(1:size(app.L1,2), 1:size(app.L1,1), 1:size(app.L1,3));
            patchInfo = app.lesionPatches{app.currentIndex};
            if ~isempty(patchInfo)
                patchInfo{1}.FaceAlpha = 0;
                delete(patchInfo{1});
            end
            drawMat = app.L1 ==  app.currentIndex;
            if nnz(drawMat) > 0 % Check if non-empty
                updateProgress(app,['Redrawing baseline lesion # ' num2str(app.currentIndex) ' ...'])
                [f, v] = isosurface(x, y, z, drawMat, 0.8);
                lesionPatch = patch(app.LesionVisualizationAxes, 'Faces', f, 'Vertices', v, 'FaceColor', app.blueColor, 'FaceAlpha', 0, 'EdgeColor', 'none'); % Initially invisible
                app.lesionPatches{app.currentIndex} = {lesionPatch, 1, app.currentIndex}; % Time point 1
            end

            patchInfo = app.lesionPatches{numel(app.lesionIndex)+app.currentIndex};
            if ~isempty(patchInfo)
                patchInfo{1}.FaceAlpha = 0;
                delete(patchInfo{1});
            end
            drawMat = app.L2 ==  app.currentIndex;
            if nnz(drawMat) > 0
                updateProgress(app,['Redrawing followup lesion # ' num2str(app.currentIndex) ' ...'])
                [f, v] = isosurface(x, y, z, drawMat, 0.8);
                lesionPatch = patch(app.LesionVisualizationAxes, 'Faces', f, 'Vertices', v, 'FaceColor', 'green', 'FaceAlpha', 0, 'EdgeColor', 'none'); % Initially invisible
                app.lesionPatches{numel(app.lesionIndex)+app.currentIndex} = {lesionPatch, 2, app.currentIndex}; % Time point 2
            end
            updateProgress(app,['Done!'])

        end

        function updateLesionVisibility(app)

            switchState = app.LesionVisibilitySwitch.Value; % 'One' or 'All' switch states

            for whichPatch = 1:length(app.lesionPatches)
                patchInfo = app.lesionPatches{whichPatch};
                if ~isempty(patchInfo)
                    lesionPatch = patchInfo{1}; % The patch object
                    lesionTimePoint = patchInfo{2}; % Time point of the lesion

                    % Ensure visibility and coloring apply only to the current time point
                    if isvalid(lesionPatch)
                        if lesionTimePoint == app.currentImageIndex
                            if strcmp(switchState, 'All')
                                % For "All" state, color all lesions based on their review state

                                if ismember(patchInfo{3},app.whichIndex)
                                    lesionPatch.FaceAlpha = 1; % Make lesion visible
                                    currentState = app.LesionReviewStates(patchInfo{3}, app.currentImageIndex);
                                    updatePatchColor(app, lesionPatch, currentState); % Update color based on state
                                else
                                    lesionPatch.FaceAlpha = 0; % Make lesion invisible
                                end
                            else
                                % For "One" state, only the selected lesion is fully visible
                                lesionPatch.FaceAlpha = double(patchInfo{3} == app.currentIndex);
                                if patchInfo{3} == app.currentIndex
                                    % Use review state to color the selected lesion
                                    currentState = app.LesionReviewStates(patchInfo{3}, app.currentImageIndex);
                                    updatePatchColor(app, lesionPatch, currentState);
                                end
                            end
                        else
                            lesionPatch.FaceAlpha = 0; % Make lesions from other time points invisible
                        end
                    end
                end
            end

        end

        function updatePatchColor(app,lesionPatch, currentState)
            % Define patch color based on the lesion's review state
            if isvalid(lesionPatch)
                switch currentState
                    case 'keep'
                        if app.currentImageIndex == 1
                            lesionPatch.FaceColor = app.blueColor; % blue
                        else
                            lesionPatch.FaceColor = [0, 1, 0]; % Green
                        end
                    case 'draft'
                        lesionPatch.FaceColor = [1, 1, 0]; % Yellow
                    case 'delete'
                        lesionPatch.FaceColor = [1, 0, 0]; % Red
                    otherwise
                        lesionPatch.FaceColor = [0.5, 0.5, 0.5]; % Default/undefined state
                end
            end
        end

        function updateLesionMasks(app)
            % first check edit state and then check for review state
            currentState = app.LesionEditStates(app.currentIndex); % Get current review state
            switch currentState
                case 'merge'
                    updateProgress(app,'Merging two time points');
                    app.L1(app.L2==app.currentIndex) = app.currentIndex;
                    app.L2(app.L1==app.currentIndex) = app.currentIndex;

                case 'clone 1'
                    updateProgress(app,'Cloning baseline lesion to followup');
                    app.L2(app.L2==app.currentIndex) = 0; % clear current time 2 les
                    app.L2(app.L1==app.currentIndex) = app.currentIndex; % clone time1 to time2

                case 'clone 2'
                    updateProgress(app,'Cloning followup lesion to baseline');
                    app.L1(app.L1==app.currentIndex) = 0;
                    app.L1(app.L2==app.currentIndex) = app.currentIndex;

                case 'reset'
                    updateProgress(app,'Reseting lesion...');
                    app.L1(app.L1==app.currentIndex) = 0;
                    app.L1(app.L1backUp==app.currentIndex) = app.currentIndex;
                    app.L2(app.L2==app.currentIndex) = 0;
                    app.L2(app.L2backUp==app.currentIndex) = app.currentIndex;

            end

            currentState = app.LesionReviewStates(app.currentIndex,app.currentImageIndex); % Get current review state

            switch currentState
                case 'keep'
                    if app.currentImageIndex == 1
                        updateProgress(app,'saving to time point 1 clean')
                        app.Lesion1Clean(app.L1==app.currentIndex) = app.currentIndex;
                        app.Lesion1Draft(app.L1==app.currentIndex) = 0;
                    else
                        updateProgress(app,'saving to time point 2 clean')
                        app.Lesion2Clean(app.L2==app.currentIndex) = app.currentIndex;
                        app.Lesion2Draft(app.L2==app.currentIndex) = 0;
                    end

                case 'draft'
                    if app.currentImageIndex == 1
                        updateProgress(app,'saving to time point 1 draft')
                        app.Lesion1Clean(app.L1==app.currentIndex) = 0;
                        app.Lesion1Draft(app.L1==app.currentIndex) = app.currentIndex;
                    else
                        updateProgress(app,'saving to time point 2 draft')
                        app.Lesion2Clean(app.L2==app.currentIndex) = 0;
                        app.Lesion2Draft(app.L2==app.currentIndex) = app.currentIndex;
                    end

                case 'delete'
                    if app.currentImageIndex == 1
                        updateProgress(app,'removing from time point 1 clean & draft')
                        app.Lesion1Clean(app.L1==app.currentIndex) = 0;
                        app.Lesion1Draft(app.L1==app.currentIndex) = 0;
                    else
                        updateProgress(app,'removing from time point 2 clean & draft')
                        app.Lesion2Clean(app.L2==app.currentIndex) = 0;
                        app.Lesion2Draft(app.L2==app.currentIndex) = 0;
                    end

            end
            updateProgress(app,['Done!'])
        end

        function updateReviewStateUI(app)              

            % first check edit state and then check for review state
            currentState = app.LesionEditStates(app.currentIndex); % Get current review state
            switch currentState
                case 'merge'
                    app.LesionEditButtonGroup.SelectedObject = app.MergeButton;
                case 'clone 1'
                    app.LesionEditButtonGroup.SelectedObject = app.Clone1Button;
                case 'clone 2'
                    app.LesionEditButtonGroup.SelectedObject = app.Clone2Button;
                case 'reset'
                    app.LesionEditButtonGroup.SelectedObject = app.ResetButton;
            end

            currentState = app.LesionReviewStates(app.currentIndex,app.currentImageIndex); % Get current review state

            % Find and select the corresponding button in the ButtonGroup
            switch currentState
                case 'keep'
                    app.LesionReviewButtonGroup.SelectedObject = app.KeepButton;
                    app.KeepButton.BackgroundColor = [0 1 0];
                    app.DraftButton.BackgroundColor = [1 1 1];
                    app.DeleteButton.BackgroundColor = [1 1 1];
                case 'draft'
                    app.LesionReviewButtonGroup.SelectedObject = app.DraftButton;
                    app.KeepButton.BackgroundColor = [1 1 1];
                    app.DraftButton.BackgroundColor = [1 1 0];
                    app.DeleteButton.BackgroundColor = [1 1 1];
                case 'delete'
                    app.LesionReviewButtonGroup.SelectedObject = app.DeleteButton;
                    app.KeepButton.BackgroundColor = [1 1 1];
                    app.DraftButton.BackgroundColor = [1 1 1];
                    app.DeleteButton.BackgroundColor = [1 0 0];
                otherwise
                    % If no state is set, default to 'keep'
                    app.LesionReviewButtonGroup.SelectedObject = app.KeepButton;

            end

        end

        function rotateView(app)

            viewAngle = get(app.LesionVisualizationAxes, 'View');  % Get the current view angle of the axes
            viewAngle(1) = viewAngle(1) + 5;      % Increment the azimuth angle for rotation (adjust the value as needed)
            view(app.LesionVisualizationAxes, viewAngle);          % Update the view angle to rotate the plot

        end

        function [indexedImg, map] = captureUIAxesFrame(app)
            % Capture the current frame from app.UIAxes
            frame = getframe(app.UIAxes);
            % Convert the frame to an image suitable for GIF creation
            [image, map] = frame2im(frame);
            if isempty(map)
                % For RGB images
                [indexedImg, map] = rgb2ind(image, 256, 'nodither');
            else
                % For indexed images
                indexedImg = rgb2ind(image, map, 'nodither');
            end
        end

        function saveUIAxesAsGif(app)

            folder = uigetdir; % Let user select save directory
            if folder == 0
                return; % User cancelled
            end

            switch app.LesionVisibilitySwitch.Value
                case 'One'
                    gifFilename1 = sprintf('%s/%s_lesionSurf_%s.gif',folder,app.subject,num2str(app.currentIndex));

                case 'All'
                    gifFilename1 = sprintf('%s/%s_lesionSurf_%s.gif',folder,app.subject,'All');
            end

            gifFilename = sprintf('%s/%s_lesionVol_%s_%s_%s_%s.gif',folder,app.subject,num2str(app.currentIndex),num2str(app.x0.Value), num2str(size(app.L1,2)-app.y0.Value),num2str(size(app.L1,3)-app.z0.Value));

            % Loop through each frame
            for k = 1:2
                % Temporarily export each frame to a PNG file
                tempFilename = sprintf('tempFrame_%d.png', k);
                tempFilename1 = sprintf('tempFrame1_%d.png', k);
                app.currentImageIndex = 3-k;
                toggleT2Image(app);
                % Export the current frame as a high-resolution image
                exportgraphics(app.UIAxes, tempFilename, 'Resolution', 300);
                exportgraphics(app.LesionVisualizationAxes, tempFilename1, 'Resolution', 300);

                % Read the exported image back into MATLAB
                [img, ~] = imread(tempFilename);
                [img1, ~] = imread(tempFilename1);
                [indexedImg, map] = rgb2ind(img, 256); % Convert image to indexed format
                [indexedImg1, map1] = rgb2ind(img1, 256);
                % Write the indexed image to the GIF
                if k == 1
                    imwrite(indexedImg, map, gifFilename, 'gif', 'LoopCount', Inf, 'DelayTime', 1);
                    imwrite(indexedImg1, map1, gifFilename1, 'gif', 'LoopCount', Inf, 'DelayTime', 1);

                else
                    imwrite(indexedImg, map, gifFilename, 'gif', 'WriteMode', 'append', 'DelayTime', 1);
                    imwrite(indexedImg1, map1, gifFilename1, 'gif', 'WriteMode', 'append', 'DelayTime', 1);

                end

                % Delete the temporary PNG file
                delete(tempFilename);
                delete(tempFilename1);

            end

        end


        function drawReport(app,whereReport)

            updateLesionVisibility(app);

            for ii = 1:2 % overlay yes and no
                app.OverlayAlpha.Value = ii-1;


                for k = 1:2 % Assuming you want to loop through two images
                    updateProgress(app,['Saving to report: 2D view lesion ' num2str(app.currentIndex) ' timepoint ' num2str(k) ' - ' num2str(ii) '...'])
                    app.currentImageIndex = 3 - k;

                    toggleT2Image(app); %
                    app.x0.Value = app.lesionCenter(app.currentIndex,1);
                    app.y0.Value = app.lesionCenter(app.currentIndex,2);
                    app.z0.Value = app.lesionCenter(app.currentIndex,3);
                    updateImage(app); % sometimes it's too slow

                    % Temporarily export each frame to a PNG file for high-resolution capture
                    tempFilename1 = sprintf('tempFrame1_%d.png', k);
                    exportgraphics(app.UIAxes, tempFilename1, 'Resolution', 300);

                    % Read the captured image
                    [img, ~] = imread(tempFilename1);


                    imageWidth = 0.45;  % Normalized width for each image
                    imageHeight = size(img,1)/size(img,2) * imageWidth;  % Normalized height for each image
                    gapWidth = (1 - 2 * imageWidth) / 3;
                    gapHeight = (1 - 4 * imageHeight) / 3;


                    % Calculate target position for the image
                    if whereReport == 1 % top half
                        if k == 1
                            % First image positioning

                            targetPosition = [gapWidth   1-gapHeight-imageHeight-(ii-1)*imageHeight/1.4-0.1   imageWidth   imageHeight];

                        else
                            % Second image positioning
                            targetPosition = [gapWidth * 2 + imageWidth   1-gapHeight-imageHeight-(ii-1)*imageHeight/1.4-0.1   imageWidth   imageHeight];
                        end
                    else % bottom half
                        if k == 1
                            % First image positioning
                            targetPosition = [gapWidth  gapHeight+imageHeight-(ii-1)*imageHeight/1.4-0.05   imageWidth   imageHeight];
                        else
                            % Second image positioning
                            targetPosition = [gapWidth * 2 + imageWidth  gapHeight+imageHeight-(ii-1)*imageHeight/1.4-0.05   imageWidth   imageHeight];
                        end
                    end

                    % Create axes for the image and adjust to target position
                    imgAxes = axes('Parent', app.fig, 'Position', targetPosition);
                    imshow(img,'InitialMagnification', 'fit', 'Parent', imgAxes);


                    if ii == 1 % if no overlay
                        if k == 1 % if baseline
                            if app.currentIndex == 1
                                textStr = ['Lesion ' num2str(app.currentIndex) ' (largest lesion) - baseline'];
                            else
                                textStr = ['Lesion ' num2str(app.currentIndex) ' - baseline'];
                            end
                        else % if followup
                            tmpMat = app.L2==app.lesionIndex(app.currentIndex);
                            if app.currentIndex == 1
                                textStr = ['Lesion ' num2str(app.currentIndex) ' (largest lesion) - followup'];
                            else
                                textStr = ['Lesion ' num2str(app.currentIndex) ' - followup - ' num2str(sum(tmpMat(:))*app.voxelSize) ' ml'];
                            end
                        end
                        text(0, 1.1, textStr, ...
                            'FontSize', 15, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
                            'Units', 'normalized', 'Parent', imgAxes,'FontWeight','bold');
                    end

                    set(imgAxes, 'XTick', [], 'YTick', [], 'Box', 'on');

                    % Clean up temporary file
                    delete(tempFilename1);
                end
            end
        end


        function setupFigure(app)

            % set up figure for export

            dpi = 300;
            a4WidthInches = 8.27; % A4 width in inches
            a4HeightInches = 11.69; % A4 height in inches
            a4WidthPixels = a4WidthInches * dpi; % Convert inches to pixels
            a4HeightPixels = a4HeightInches * dpi; % Convert inches to pixels

            app.fig = figure;
            % Set figure units to pixels for on-screen size control
            set(app.fig, 'Units', 'pixels', ...
                'Position', [100, 100, a4WidthPixels, a4HeightPixels], ...
                'Visible', 'off');

            set(app.fig, 'PaperUnits', 'inches', ...
                'PaperSize', [a4WidthInches, a4HeightInches], ...
                'PaperPositionMode', 'manual','PaperPosition', [0 0 a4WidthInches a4HeightInches]);
        end

        function updateProgress(app, message)
            % Append new message to the TextArea
            currentText = app.ProgressTextArea.Value;
            if iscell(currentText)
                % If there are multiple lines already, append the new message
                app.ProgressTextArea.Value = [currentText; {message}];
            else
                % If it's the first message
                app.ProgressTextArea.Value = {currentText; message};
            end
            % Automatically scroll to the bottom of the TextArea
            drawnow;
            scroll(app.ProgressTextArea, 'bottom');
        end

        function updateProgressBar(app, progressPercentage)
            app.progressBarFront.Visible = 'on';
            app.PleasewaitLabel.Visible = 'on';
            app.PleasewaitLabel.Text = 'Please Wait';
            % Calculate the new width of the progress panel
            newWidth = progressPercentage/100 * app.progressBarLength;
            % Update the progress panel's width to reflect current progress
            app.progressBarFront.Position(3) = newWidth;
            drawnow;
        end

        function startCompute(app)
            if ~isempty(app.Lesion1) && ~isempty(app.Lesion2)
                analyzeLesions(app);
                drawLesions(app);
                updateImage(app); % Refresh the T2 flair image display
                updateNewGoneLesionIndex(app);
                checkWhichIndexList(app);
                updateLesionVisibility(app);

                app.progressBarFront.Visible = 'off';
                app.PleasewaitLabel.Visible = 'off';

                % Make export buttons visible and enabled
                app.ExportPDFButton.Enable = 'on';
                app.ExportNIfTIButton.Enable = 'on';

                app.DeleteButton.Enable = 'on';
                app.DraftButton.Enable = 'on';
                app.KeepButton.Enable = 'on';

                app.ResetButton.Enable = 'on';
                app.Clone2Button.Enable = 'on';
                app.Clone1Button.Enable = 'on';
                app.MergeButton.Enable = 'on';
                app.UpdateButton.Enable = 'on';
                app.allowKey = 1;

            end
        end

        function checkWhichIndexList(app)

            % based on lesion check boxes
            app.whichIndex = [];
            if app.NewLesionCheckBox.Value
                app.whichIndex = unique([app.whichIndex; app.newLesionIndex]);
            end
            if app.DisappearingCheckBox.Value
                app.whichIndex = unique([app.whichIndex; app.goneLesionIndex]);
            end
            if app.EnlargingCheckBox.Value
                app.whichIndex = unique([app.whichIndex; app.enlargeLesionIndex]);
            end

            if (app.EnlargingCheckBox.Value+app.DisappearingCheckBox.Value+app.NewLesionCheckBox.Value)<0.1
                app.whichIndex = app.lesionIndex;
            end

            app.LesionIndexSpinner.Limits = [1, numel(app.whichIndex)];

            app.currentIndex = app.whichIndex(min([app.LesionIndexSpinner.Value numel(app.whichIndex)]));
            app.x0.Value = app.lesionCenter(app.currentIndex,1);
            app.y0.Value = app.lesionCenter(app.currentIndex,2);
            app.z0.Value = app.lesionCenter(app.currentIndex,3);

            % Display summary information about lesions in TextArea
            infoText = sprintf('Time 1 - %d lesions (%.3f ml) - #%d: %d mm^3\nTime 2 - %d lesions (%.3f ml) - #%d: %d mm^3', ...
                sum(app.LesionReviewStates(:,1) ~= "delete"), sum(app.sizeChange(:,1)), app.currentIndex, floor(app.sizeChange(app.currentIndex,1) * 1000), ...
                sum(app.LesionReviewStates(:,2) ~= "delete"), sum(app.sizeChange(:,2)), app.currentIndex, floor(app.sizeChange(app.currentIndex,2) * 1000));
            app.TextArea.Value = infoText;

        end


        function updateLesionSize(app)

            exportIndex = app.lesionIndex;
            exportIndex(((app.LesionReviewStates(:,1)=="keep")+(app.LesionReviewStates(:,2)=="keep"))==0)=[];

            % reset the matrix to store size changes across two time points
            app.sizeChange = zeros(numel(exportIndex), 3);

            for ii = 1:numel(exportIndex)
                % Generate binary matrices for each lesion by comparing with their indices
                if app.LesionReviewStates(exportIndex(ii),1)~="delete"
                    app.sizeChange(ii,1) = sum(ismember(app.L1,exportIndex(ii)),'all');
                else
                    app.sizeChange(ii,1) = 0;
                end
                if app.LesionReviewStates(exportIndex(ii),2)~="delete"
                    app.sizeChange(ii,2) = sum(ismember(app.L2,exportIndex(ii)),'all');
                else
                    app.sizeChange(ii,2) = 0;
                end
            end
            % Calculate the change in lesion size between two time points and convert to volume
            app.sizeChange(:,3) = app.sizeChange(:,2) - app.sizeChange(:,1);
            app.sizeChange = app.sizeChange * app.voxelSize;

            %% enlarging lesion
            app.EnlargingCheckBox.Value = 0;
            % which lesions have grown in size
            app.enlargeLesionIndex = find(app.sizeChange(:,3)>0&app.sizeChange(:,1)>=1e-10);

            if isempty(app.enlargeLesionIndex)
                app.EnlargingCheckBox.Enable = 'off';
            else
                app.EnlargingCheckBox.Enable = 'on';
            end

            %%

            [~, whoBig] = max(max(app.sizeChange(:,1:2)'));
            app.largestLesion = exportIndex(whoBig);

        end


        function get_newLesionMask(app)

            % Initialize new lesion mask
            app.newLesionMask = zeros(size(app.Lesion2Clean));

            % Calculate the difference between the two lesion masks
            lesionDiff = app.Lesion2Clean - app.Lesion1Clean;

            % Loop through each voxel and apply conditions
            for ii = 1:numel(app.Lesion2Clean)
                if lesionDiff(ii) == 0 && app.Lesion2Clean(ii) == 1
                    % Same lesion
                    app.newLesionMask(ii) = 1;
                elseif lesionDiff(ii) == 1
                    % Check if it's a new lesion or an enlarging lesion
                    if app.Lesion1Clean(ii) == 0
                        app.newLesionMask(ii) = 2;
                    end
                elseif lesionDiff(ii) == -1
                    % Disappearing lesion
                    app.newLesionMask(ii) = 0;
                end
            end

            [L2, ~] = bwlabeln(app.Lesion2Clean > 0.8, 26);

            for ii = 1:(numel(unique(L2)) - 1)
                % Find the current lesion in L2
                currentLesion = (L2 == ii);

                % Check for overlap with lesion1
                overlap = currentLesion & (app.Lesion1Clean > 0.8);

                % If there is no overlap, it is a new lesion
                if sum(overlap(:)) == 0
                    app.newLesionMask(currentLesion) = 3;
                end
            end


        end

    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            updateProgress(app,'Hi hi, ready to start.')
            app.x0.Value = 100;
            app.y0.Value = 100;
            app.z0.Value = 100;
            % Initialize with a random matrix of size 260x311x260
            app.whichT2 = rand(260, 311, 260);
            app.whichLes = rand(260, 311, 260);

            app.x0.Limits = [1 size(app.whichT2, 3)];
            app.y0.Limits = [1 size(app.whichT2, 2)];
            app.z0.Limits = [1 size(app.whichT2, 1)];

            app.LesionVisibilitySwitch.Value = 'One';
            app.currentImageIndex = 1;
            app.lesionIndex = 1;
            app.whichIndex = 1;

            app.LesionIndexSpinner.Limits = [1, 1]; % Minimal safe range
            app.LesionIndexSpinner.Value = 1; % Set an initial value
            app.currentIndex = 1;
            app.LesionIndexSpinner.Enable = 'off'; % Disable until lesions are loaded

            % Call updateImage to display the initial random matrix or handle as needed
            updateImage(app);

            app.ExportNIfTIButton.Enable = 'off';
            app.ExportPDFButton.Enable = 'off';

            app.NewLesionCheckBox.Enable = 'off';
            app.DisappearingCheckBox.Enable = 'off';

            app.DeleteButton.Enable = 'off';
            app.DraftButton.Enable = 'off';
            app.KeepButton.Enable = 'off';

            app.ResetButton.Enable = 'off';
            app.Clone2Button.Enable = 'off';
            app.Clone1Button.Enable = 'off';
            app.MergeButton.Enable = 'off';

            app.UpdateButton.Enable = 'off';


            app.progressBarLength = app.progressBarFront.Position(3);
            app.progressBarFront.Visible = 'off';
            app.PleasewaitLabel.Visible = 'on';
            app.PleasewaitLabel.Text = '↓ Click here to load files';

            app.ImageSwitchTimer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', 1, ...
                'TimerFcn', @(~,~)toggleT2Image(app));

            app.rotationTimer = timer(...
                'ExecutionMode', 'fixedRate', ...  % Execute the timer repeatedly at a fixed rate
                'Period', 0.15, ...                 % Set the period of the timer (adjust as needed for rotation speed)
                'TimerFcn', @(~,~)rotateView(app)); % Function to rotate the plot





        end

        % Value changed function: x0
        function x0ValueChanged(app, event)
            updateImage(app);
        end

        % Value changed function: y0
        function y0ValueChanged(app, event)
            updateImage(app);
        end

        % Value changed function: z0
        function z0ValueChanged(app, event)
            updateImage(app);
        end

        % Button pushed function: LoadBIDSButton
        function LoadBIDSButtonPushed(app, event)
            % Open folder selection dialog
            defaultDir = '/Volumes/Vision/UsersShare/Amna/Multiple_Sclerosis_BIDS/derivatives';

            % Check if the default directory exists
            if exist(defaultDir, 'dir')
                subDir = uigetdir(defaultDir);
            else
                subDir = uigetdir();
            end

            if isequal(subDir, 0)
                updateProgress(app,'User selected Cancel');
                return;
            end
            cla(app.LesionVisualizationAxes);

            tmpVal = strfind(string(subDir), filesep);
            % Extract the subject ID
            app.subject = char(extractAfter(string(subDir), tmpVal(end)));
            % Extract the lesion type - raw, manual, or clean?
            pathParts = strsplit(subDir, filesep);
            subIndex = find(contains(pathParts, 'sub-'));
            app.lesionDerivDir = pathParts{subIndex - 1};
            % Extract the BIDS directory
            app.bidsDir = char(extractBefore(string(subDir), tmpVal(end-2)));

            LamDir = 'samseg';
            LesDir = app.lesionDerivDir;

            updateProgress(app,['Loading from :'  app.bidsDir])
            updateProgressBar(app, 0);

            % Identify all session folders
            allSesDirs = dir(fullfile(app.bidsDir,'derivatives',LamDir,app.subject,'ses-*'));
            sesList = {};
            for i = 1:length(allSesDirs)
                if allSesDirs(i).isdir
                    sesList{end+1} = allSesDirs(i).name; %#ok<AGROW>
                end
            end
            numericSessions = [];
            for i = 1:length(sesList)
                idx = str2double(regexprep(sesList{i}, 'ses-', ''));
                if ~isnan(idx)
                    numericSessions(end+1) = idx; %#ok<AGROW>
                end
            end

            if isempty(numericSessions)
                updateProgress(app,'*** No sessions found ***');
                return;
            end

            firstSesNum = min(numericSessions);
            lastSesNum  = max(numericSessions);

            % Store session names in the app
            app.firstSesName = sprintf('ses-%02d', firstSesNum);
            app.lastSesName  = sprintf('ses-%02d', lastSesNum);

            % % Define a directory path for temporary work files
            % app.tmpworkdir = fullfile(app.bidsDir, 'derivatives','tmpworkdir', app.subject);
            % if ~exist(app.tmpworkdir, 'dir')
            %     mkdir(app.tmpworkdir);
            % end
            % 
            % % Build a filename that includes subject, app.lesionDerivDir, and the two sessions
            % tmpWorkFileName = sprintf('%s_%s_%s_%s.mat', ...
            %     app.subject, ...
            %     app.lesionDerivDir, ...
            %     app.firstSesName, ...
            %     app.lastSesName);
            % 
            % tmpWorkFilePath = fullfile(app.tmpworkdir, tmpWorkFileName);
            % 
            % % If the file already exists, load and replace app with the saved one
            % if exist(tmpWorkFilePath, 'file')
            %     loadedMAT = load(tmpWorkFilePath);
            %     if isfield(loadedMAT, 'app')
            %         updateProgress(app, ['Loading existing tmp work file: ' tmpWorkFileName]);
            %         app = loadedMAT.app;
            %         return;
            %     else
            %         updateProgress(app,'*** No ''app'' field found in existing tmp work file, will reload data ***')
            %     end
            % end

            try
                % ---------------------------
                % Load FLAIR for FIRST ses
                % ---------------------------
                FlairTP1File = dir(fullfile(app.bidsDir,'derivatives',LamDir,app.subject, ...
                    app.firstSesName, '*acq-2D*FLAIR.nii.gz'));
                if isempty(FlairTP1File)
                    FlairTP1File = dir(fullfile(app.bidsDir,'derivatives',LamDir,app.subject, ...
                        app.firstSesName, '*acq-3D*FLAIR.nii.gz'));
                end
                if ~isempty(FlairTP1File)
                    updateProgress(app,['Loading T2 Flair time point 1 from : ', ...
                        fullfile(FlairTP1File.folder, FlairTP1File.name)]);
                    app.FlairTP1 = niftiread(fullfile(FlairTP1File.folder, FlairTP1File.name));
                    app.FlairTP1 = flip(app.FlairTP1,2);
                    app.FlairTP1 = flip(app.FlairTP1,3);
                    app.fileStatus(1) = true;
                    updateProgressBar(app, sum(double(app.fileStatus))*20/3);
                else
                    updateProgress(app,'*** No baseline FLAIR found, please load manually ***')
                end

                % ---------------------------
                % Load FLAIR for LAST ses
                % ---------------------------
                FlairTP2File = dir(fullfile(app.bidsDir,'derivatives',LamDir,app.subject, ...
                    app.lastSesName, '*acq-2D*FLAIR.nii.gz'));
                if isempty(FlairTP2File)
                    FlairTP2File = dir(fullfile(app.bidsDir,'derivatives',LamDir,app.subject, ...
                        app.lastSesName, '*acq-3D*FLAIR.nii.gz'));
                end
                if ~isempty(FlairTP2File)
                    updateProgress(app,['Loading Flair time point 2 from : ', ...
                        fullfile(FlairTP2File.folder, FlairTP2File.name)]);
                    app.FlairTP2 = niftiread(fullfile(FlairTP2File.folder, FlairTP2File.name));
                    app.FlairTP2 = flip(app.FlairTP2,2);
                    app.FlairTP2 = flip(app.FlairTP2,3);
                    app.fileStatus(2) = true;
                    updateProgressBar(app, sum(double(app.fileStatus))*20/3);
                else
                    updateProgress(app,'*** No followup FLAIR found, please load manually ***')
                end

                app.whichT2 = app.FlairTP2;
                app.currentImageIndex = 2;
                updateImage(app);
                clf(app.LesionVisualizationAxes);
                close all;

                % ---------------------------
                % Brain Mask from FIRST ses
                % ---------------------------
                brainMaskFile = dir(fullfile(app.bidsDir,'derivatives',LamDir,app.subject, ...
                    app.firstSesName, '*brain_mask.nii.gz'));
                if ~isempty(brainMaskFile)
                    updateProgress(app,['Loading brain mask from : ', ...
                        fullfile(brainMaskFile(1).folder, brainMaskFile(1).name)]);
                    app.brainMask = niftiread(fullfile(brainMaskFile(1).folder, brainMaskFile(1).name));
                    app.fileStatus(5) = true;
                    updateProgressBar(app, sum(double(app.fileStatus))*20/3);
                    updateProgress(app,'Drawing brain mask ...');
                    drawBrainMask(app);
                else
                    updateProgress(app,'*** No BrainMask found, please load manually ***')
                end
                close all;

                % ---------------------------
                % Lesion for FIRST ses
                % ---------------------------
                lesion1File = dir(fullfile(app.bidsDir,'derivatives',LesDir,app.subject, ...
                    app.firstSesName, '*acq-2D*lesion*.nii.gz'));
                if isempty(lesion1File)
                    lesion1File = dir(fullfile(app.bidsDir,'derivatives',LesDir,app.subject, ...
                        app.firstSesName, '*acq-3D*lesion*.nii.gz'));
                end
                if ~isempty(lesion1File)
                    updateProgress(app,['Loading Lesion mask time point 1 from : ', ...
                        fullfile(lesion1File(1).folder, lesion1File(1).name)]);
                    app.Lesion1 = niftiread(fullfile(lesion1File(1).folder, lesion1File(1).name));
                    app.FlairInfo = niftiinfo(fullfile(lesion1File(1).folder, lesion1File(1).name));
                    app.fileStatus(3) = true;
                    updateProgressBar(app, sum(double(app.fileStatus))*20/3);

                    app.tmpLesionNameClean1 = fullfile(app.bidsDir,'derivatives','tmp_lesion',...
                        app.subject, app.firstSesName, ...
                        strrep(lesion1File(1).name,'_mask.nii.gz','Clean_mask.nii.gz'));
                    app.tmpLesionNameDraft1 = fullfile(app.bidsDir,'derivatives','tmp_lesion',...
                        app.subject, app.firstSesName, ...
                        strrep(lesion1File(1).name,'lesion','draft'));
                else
                    updateProgress(app,'*** No baseline lesion found, please load manually ***')
                end
                close all;

                % ---------------------------
                % Lesion for LAST ses
                % ---------------------------
                lesion2File = dir(fullfile(app.bidsDir,'derivatives',LesDir,app.subject, ...
                    app.lastSesName, '*acq-2D*lesion*.nii.gz'));
                if isempty(lesion2File)
                    lesion2File = dir(fullfile(app.bidsDir,'derivatives',LesDir,app.subject, ...
                        app.lastSesName, '*acq-3D*lesion*.nii.gz'));
                end
                if ~isempty(lesion2File)
                    updateProgress(app,['Loading Lesion mask time point 2 from : ', ...
                        fullfile(lesion2File(1).folder, lesion2File(1).name)]);
                    app.Lesion2 = niftiread(fullfile(lesion2File(1).folder, lesion2File(1).name));
                    app.fileStatus(4) = true;
                    updateProgressBar(app, sum(double(app.fileStatus))*20/3);

                    app.tmpLesionNameClean2 = fullfile(app.bidsDir,'derivatives','tmp_lesion',...
                        app.subject, app.lastSesName, ...
                        strrep(lesion2File(1).name,'_mask.nii.gz','Clean_mask.nii.gz'));
                    app.tmpLesionNameDraft2 = fullfile(app.bidsDir,'derivatives','tmp_lesion',...
                        app.subject, app.lastSesName, ...
                        strrep(lesion2File(1).name,'lesion','draft'));
                else
                    updateProgress(app,'*** No followup lesion found, please load manually ***')
                end
                close all;

                startCompute(app);

                % Save a tmp work file for the current configuration
             %   save(tmpWorkFilePath, 'app');

            catch ME
                updateProgress(app,['Error loading files: ', ME.message]);
            end
            close all;
        end

        % Value changed function: LesionIndexSpinner
        function LesionIndexSpinnerValueChanged(app, event)
            app.LesionVisibilitySwitch.Value = 'One';
            checkWhichIndexList(app);


            updateLesionVisibility(app);

            updateImage(app);
            updateReviewStateUI(app);

        end

        % Value changed function: LesionVisibilitySwitch
        function LesionVisibilitySwitchValueChanged(app, event)
            checkWhichIndexList(app);
            updateImage(app);
            updateLesionVisibility(app);

        end

        % Selection changed function: ButtonGroup
        function ButtonGroupSelectionChanged(app, event)
            selectedButton = app.ButtonGroup.SelectedObject.Text;

            switch selectedButton
                case '1'
                    stop(app.ImageSwitchTimer); % Stop the timer if running
                    app.currentImageIndex = 1;
                    if isempty(app.FlairTP1)
                        app.whichT2 = rand(260, 311, 260);
                    else
                        app.whichT2 = app.FlairTP1; % Set to first image
                    end

                    updateImage(app); % Refresh the image display for Time 1
                    updateLesionVisibility(app);
                    
                    if ~isempty(app.Lesion1)
                    updateReviewStateUI(app);
                    end

                case '2'
                    stop(app.ImageSwitchTimer); % Stop the timer if running
                    app.currentImageIndex = 2;
                    if isempty(app.FlairTP2)
                        app.whichT2 = rand(260, 311, 260);
                    else
                        app.whichT2 = app.FlairTP2; % Set to first image
                    end

                    updateImage(app); % Refresh the image display for Time 2
                    updateLesionVisibility(app);

                    if ~isempty(app.Lesion2)
                        updateReviewStateUI(app);
                    end

                case 'Play'
                    start(app.ImageSwitchTimer);

                    if ~isempty(app.Lesion1) && ~isempty(app.Lesion2)
                        updateReviewStateUI(app);
                    end
            end
        end

        % Value changing function: OverlayAlpha
        function OverlayAlphaValueChanging(app, event)
            alphaValue = app.OverlayAlpha.Value; % Get the current value of the slider
            if isfield(app, 'hLes') && isvalid(app.hLes) % Check if the overlay handle exists and is valid
                set(app.hLes, 'AlphaData', alphaValue); % Adjust the overlay's alpha transparency
            end
            updateImage(app);
        end

        % Value changed function: OverlayAlpha
        function OverlayAlphaValueChanged(app, event)
            alphaValue = app.OverlayAlpha.Value; % Get the current value of the slider
            if isfield(app, 'hLes') && isvalid(app.hLes) % Check if the overlay handle exists and is valid
                set(app.hLes, 'AlphaData', alphaValue); % Adjust the overlay's alpha transparency
            end
            updateImage(app);            
        end

        % Selection changed function: LesionReviewButtonGroup
        function LesionReviewButtonGroupSelectionChanged(app, event)
            selectedButton = app.LesionReviewButtonGroup.SelectedObject.Text;
            % Default all buttons to white background
            % Update the review state for the current lesion
            app.LesionReviewStates(app.currentIndex,app.currentImageIndex) = lower(selectedButton);
            
            % Update lesion masks based on the selected review state
            updateReviewStateUI(app);
            updateLesionMasks(app);
            updateLesionVisibility(app);
            

        end

        % Button pushed function: ExportNIfTIButton
        function ExportNIfTIButtonPushed(app, event)

            folder = fullfile(app.bidsDir,'derivatives','tmp_lesion',app.subject);
            if ~isfolder(folder)
                mkdir(folder);
            end

            app.Lesion1Clean = single(logical(app.Lesion1Clean)); %
            app.Lesion1Draft = single(logical(app.Lesion1Draft)); % 
            app.Lesion2Clean = single(logical(app.Lesion2Clean)); %
            app.Lesion2Draft = single(logical(app.Lesion2Draft)); % 

            % Save each mask as a nifti file
            app.PleasewaitLabel.Visible = 'on';
            app.PleasewaitLabel.Text = 'Exporting... Please wait ...';
            updateProgress(app,['*** Please wait, saving nii.gz files ***'])
            updateProgress(app,['Saving Clean1 ...'])

            folderPath = fileparts(app.tmpLesionNameClean1);
            if ~isfolder(folderPath)
                mkdir(folderPath);  % Attempt to create the folder if it doesn't exist
            end

            niftiwrite(app.Lesion1Clean, app.tmpLesionNameClean1, app.FlairInfo,'Compressed',true);
            
            updateProgress(app,['Saving Draft1 ...'])
            niftiwrite(app.Lesion1Draft, app.tmpLesionNameDraft1, app.FlairInfo,'Compressed',true);

            folderPath = fileparts(app.tmpLesionNameClean2);
            if ~isfolder(folderPath)
                mkdir(folderPath);  % Attempt to create the folder if it doesn't exist
            end

            updateProgress(app,['Saving Clean2 ...'])
            niftiwrite(app.Lesion2Clean, app.tmpLesionNameClean2, app.FlairInfo,'Compressed',true);

            updateProgress(app,['Saving Draft2 ...'])
            niftiwrite(app.Lesion2Draft,  app.tmpLesionNameDraft2, app.FlairInfo,'Compressed',true);
            app.PleasewaitLabel.Visible = 'off';
            updateProgress(app,['Done!'])


            %% save final lesion mask (3 color coded)

          get_newLesionMask(app);

            outputDir = fullfile(app.bidsDir,'derivatives','colorCodedLesionMask',app.subject);
            if ~exist(outputDir, 'dir')
                mkdir(outputDir);
            end
            saveFinalMaskFilePath = fullfile(outputDir, 'ColorCodedlesionMask.nii.gz');

            niftiwrite(single(app.newLesionMask),  saveFinalMaskFilePath, app.FlairInfo,'Compressed',true);

        end

        % Button pushed function: XButton
        function XButtonPushed(app, event)
            view(app.LesionVisualizationAxes, [0 1 0]); % Set view to sagittal
        end

        % Button pushed function: YButton
        function YButtonPushed(app, event)
            view(app.LesionVisualizationAxes, [1 0 0]); % Set view to coronal
        end

        % Button pushed function: ZButton
        function ZButtonPushed(app, event)
            view(app.LesionVisualizationAxes, [0 0 1]); % Set view to Ax
        end

        % Button pushed function: RButton
        function RButtonPushed(app, event)
            if strcmp(app.rotationTimer.Running, 'off')
                start(app.rotationTimer);  % Start the timer, and hence the rotation, if it's not already running
            else
                stop(app.rotationTimer);   % Stop the timer, and hence the rotation, if it's currently running
            end
        end

        % Value changed function: EnlargingCheckBox, NewLesionCheckBox
        function NewLesionCheckBoxValueChanged(app, event)
            app.LesionIndexSpinner.Value = 1;
            checkWhichIndexList(app);

            updateLesionVisibility(app);
            updateImage(app);
            updateReviewStateUI(app);

        end

        % Selection changed function: LesionEditButtonGroup
        function LesionEditButtonGroupSelectionChanged(app, event)
            % Update the edit state for the current lesion
            app.LesionEditStates(app.currentIndex) = lower(app.LesionEditButtonGroup.SelectedObject.Text);
            
            % Update lesion masks based on the selected review/edit state
            updateReviewStateUI(app);
            updateLesionMasks(app);
            editLesion(app);
            updateImage(app);
            updateLesionVisibility(app);
            
        end

        % Value changed function: DisappearingCheckBox
        function DisappearingCheckBoxValueChanged(app, event)
            app.LesionIndexSpinner.Value = 1;
            checkWhichIndexList(app);

            updateImage(app);
            updateReviewStateUI(app);
            updateLesionVisibility(app);
        end

        % Button pushed function: ExportPDFButton
        function ExportPDFButtonPushed(app, event)

            app.PleasewaitLabel.Visible = 'on';
            app.PleasewaitLabel.Text = 'Exporting... Please wait ...';

            %% Initialize the PDF filename
            whichPage = 1;

            % pdfFilename1 = fullfile(folder, sprintf('%s_lesionReport_%s.pdf', app.subject, num2str(whichPage)));
            pdfFilename1 = fullfile(app.bidsDir,'derivatives','Report',app.subject, sprintf('%s_lesionReport_%s.pdf', app.subject, num2str(whichPage)));
            if ~isfolder(fullfile(app.bidsDir,'derivatives','Report',app.subject))
            mkdir(fullfile(app.bidsDir,'derivatives','Report',app.subject))
            end
            %% Create figure sized as A4 in portrait orientation
            % Define A4 size in pixels at 300 DPI (dots per inch)


            setupFigure(app);

            %% Add title text at the top of the page
            % Use normalized units for positioning
            annotation(app.fig,'rectangle',[0, 0.95, 1, 0.1],'FaceColor',[0.5 0.5 0.5],'FaceAlpha',.2,'EdgeColor', 'none');

            annotation(app.fig, 'textbox', [0, 0.925, 1, 0.1], 'String', ['Lesion report of ' app.subject], ...
                'FontSize', 28, 'FontWeight','bold','VerticalAlignment', 'middle','HorizontalAlignment', 'center','EdgeColor', 'none', 'Interpreter', 'none');

            %% Process and display each image            
            
            % Export only the new lesions that have passed the review
            updateNewGoneLesionIndex(app);
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
                updateProgress(app,['Saving to report: 3D view timepoint ' num2str(k) ' ...'])
                app.currentImageIndex = 3 - k;
                app.LesionVisibilitySwitch.Value = 'All';
                toggleT2Image(app); % update the visualization
                view(app.LesionVisualizationAxes, [0 0 1]); % Set view to Axial

                % update lesion color
                for ii = 1:numel(app.lesionPatches)
                    patchInfo = app.lesionPatches{ii};
                    if ~isempty(patchInfo)
                        lesionPatch = patchInfo{1}; % The patch object
                        if isvalid(lesionPatch)
                            if sum(double(patchInfo{3} == app.newLesionIndexExport))>0
                                if app.currentImageIndex == 2
                                    lesionPatch.FaceColor = [0 1 0]; % new lesion green
                                else
                                    lesionPatch.FaceAlpha = 0;
                                end
                            elseif sum(double(patchInfo{3} == app.goneLesionIndexExport))>0
                                if app.currentImageIndex == 1
                                    lesionPatch.FaceColor = app.blueColor; % disappearing lesion blue
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
                tempFilename1 = sprintf('tempFrame1_%d.png', k);
                exportgraphics(app.LesionVisualizationAxes, tempFilename1, 'Resolution', 300);

                % Read the captured image
                [img, ~] = imread(tempFilename1);
                img = rot90(img); % Rotate 90 degrees counterclockwise

                % Calculate target position for the image
                if k == 1
                    % First image positioning
                    targetPosition = [0.0640    0.66    0.2019    size(img,1)/size(img,2)*0.2019]; % Left bottom width height

                else
                    % Second image positioning
                    targetPosition = [0.3    0.66    0.2019    size(img,1)/size(img,2)*0.2019]; % 0.1711
                end

                % Create axes for the image and adjust to target position
                imgAxes = axes('Parent', app.fig, 'Position', targetPosition);
                imshow(img, 'Parent', imgAxes);

                if k == 1 % if time point 1
                    text(0.525, 1, 'baseline', ...
                        'FontSize', 15, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                        'Units', 'normalized', 'Parent', imgAxes,'FontWeight','bold');

                else
                    text(0.525, 1, 'followup', ...
                        'FontSize', 15, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                        'Units', 'normalized', 'Parent', imgAxes,'FontWeight','bold');

                end

                set(imgAxes, 'XTick', [], 'YTick', [], 'Box', 'on');

                % Clean up temporary file
                delete(tempFilename1);
            end

            %% Recalculating final lesion stats based on reviewing status

             updateLesionSize(app);

             %% Prepare the info text
             infoTextLines = {
                 sprintf('Baseline - %.3f ml lesions', sum(app.sizeChange(:,1))),
                 sprintf('Followup - %.3f ml lesions', sum(app.sizeChange(:,2)))
                 };


            % Define the starting position for the text (bottom-right corner in normalized units)
            infoPositionX = 0.55; % Horizontal start position in normalized units
            infoPositionYStart = 0.85; % Vertical start position in normalized units
            lineSpacing = 0.05; % Space between lines in normalized units

            % Create a full-size invisible axes for positioning text
            infoAxes = axes('Parent', app.fig, 'Position', [0, 0, 1, 1], 'Visible', 'off');
            set(infoAxes, 'XLim', [0, 1], 'YLim', [0, 1], 'YDir', 'reverse');

            % Loop through the lines of text and place them
            for ii = 1:length(infoTextLines)
                text(infoPositionX, infoPositionYStart - (ii-1)*lineSpacing, infoTextLines{ii}, ...
                    'FontSize', 15, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
                    'Units', 'normalized', 'Parent', infoAxes,'FontWeight','bold');
            end

            %% bar graph of lesion size change

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

            %% Draw the largest lesion on bottom of page 1

            whereReport = 2;
            
            app.LesionVisibilitySwitch.Value = 'One';
            app.NewLesionCheckBox.Value = 0;
            app.DisappearingCheckBox.Value = 0;
            checkWhichIndexList(app);
            app.currentIndex = app.largestLesion(1); 
            app.LesionIndexSpinner.Value = app.currentIndex;

            drawReport(app,whereReport);

            updateProgress(app,['Exporting ' pdfFilename1 ' ...'])
            print(app.fig, pdfFilename1, '-dpdf', '-r300');
            close(app.fig);
            updateProgress(app,'Page 1 done!')

            %% fill the 2nd+ pages with new lesions
            % This is budget workaround, not the best practice, please find
            % another way
            
            % Export only the new lesions that have passed the review

            if isempty(app.newLesionIndexExport)

                updateProgress(app,['No new lesions found ...'])
                morePages = 0;

            else

                morePages = ceil(numel(app.newLesionIndexExport)/2);
                whichLesion = 1; % we always draw 2 lesions per page, and always draw first new lesion on page 2


                for whichPage = 2:(1+morePages)

                    % check if it's half a page or one full page
                    numLes = 2;
                    if whichPage == (1+morePages)
                        numLes = double(rem(numel(app.newLesionIndexExport)/2,1)==0)+1;
                    end
         
                    pdfFilename1 = fullfile(app.bidsDir,'derivatives','Report',app.subject, sprintf('%s_lesionReport_%s.pdf', app.subject, num2str(whichPage)));

                    setupFigure(app);

                    % Add title text at the top of the page
                    annotation(app.fig,'rectangle',[0, 0.95, 1, 0.1],'FaceColor',[0.5 0.5 0.5],'FaceAlpha',.2,'EdgeColor', 'none');

                    annotation(app.fig, 'textbox', [0, 0.925, 1, 0.1], 'String', ['Possible New Lesions'], ...
                        'FontSize', 28, 'FontWeight','bold','VerticalAlignment', 'middle','HorizontalAlignment', 'left','EdgeColor', 'none', 'Interpreter', 'none');


                    for ii = 1:numLes % loop through the lesions to draw on the current page
                        app.currentIndex = app.newLesionIndexExport(whichLesion);

                        if ~rem(whichLesion,2) % even index, draw at bottom of page
                            drawReport(app,2);
                        else % odd index, draw at top of page
                            drawReport(app,1);
                        end
                        whichLesion = whichLesion + 1; % goes to next lesion
                    end

                    updateProgress(app,['Exporting ' pdfFilename1 ' ...'])
                    print(app.fig, pdfFilename1, '-dpdf', '-r300');
                    close(app.fig);
                    updateProgress(app,['Page ' num2str(whichPage) ' done!'])

                end

            end

            inputFiles = cell(1, 1+morePages);
            for ii = 1:(1+morePages)
                inputFiles{ii} = fullfile(app.bidsDir,'derivatives','Report',app.subject, sprintf('%s_lesionReport_%d.pdf', app.subject, ii));
            end
            outputFile = fullfile(app.bidsDir,'derivatives','Report',app.subject, sprintf('%s_lesionReport.pdf', app.subject));


            % Create the Ghostscript command for merging
            %cmd = sprintf('/opt/homebrew/bin/gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile="%s"', outputFile);
            
            cmd = sprintf('%s/gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile="%s"',pwd,outputFile);

            % Append each input file to the command
            for ii = 1:length(inputFiles)
                cmd = sprintf('%s "%s"', cmd, inputFiles{ii});
            end

            % Execute the command
            [status, cmdout] = system(cmd);

            if status == 0
                % Delete individual PDF files
                for ii = 1:length(inputFiles)
                    delete(inputFiles{ii});
                end
                updateProgress(app,'PDF files were merged successfully.');
            else
                updateProgress(app,['An error occurred: ', cmdout]);
            end

            app.PleasewaitLabel.Visible = 'off';

        end

        % Button pushed function: UpdateButton
        function UpdateButtonPushed(app, event)
            updateNewGoneLesionIndex(app);
            app.LesionIndexSpinner.Value = 1;
            checkWhichIndexList(app);
            updateLesionSize(app);
            updateLesionVisibility(app);
            updateImage(app);
            

        end

        % Key press function: UIFigure
        function UIFigureKeyPress(app, event)

            switch event.Key
                case 'hyphen'
                    app.x0.Value = app.x0.Value - 1;
                    updateImage(app);
                case 'equal'
                    app.x0.Value = app.x0.Value + 1;
                    updateImage(app);
                case 'leftbracket'
                    app.y0.Value = app.y0.Value - 1;
                    updateImage(app);
                case 'rightbracket'
                    app.y0.Value = app.y0.Value + 1;
                    updateImage(app);
                case 'quote'
                    app.z0.Value = app.z0.Value - 1;
                    updateImage(app);
                case 'backslash'
                    app.z0.Value = app.z0.Value + 1;
                    updateImage(app);
            end

        end

        % Key release function: UIFigure
        function UIFigureKeyRelease(app, event)

            if app.allowKey

                switch event.Key

                    case 'leftarrow'

                        % Decrease spinner value
                        newValue = app.LesionIndexSpinner.Value - 1;
                        % Check if newValue is less than Spinner's Minimum
                        if newValue >= app.LesionIndexSpinner.Limits(1)
                            app.LesionIndexSpinner.Value = newValue;
                        end
                        LesionIndexSpinnerValueChanged(app, []);

                    case 'rightarrow'

                        % Increase spinner value
                        newValue = app.LesionIndexSpinner.Value + 1;
                        % Check if newValue exceeds Spinner's Maximum
                        if newValue <= app.LesionIndexSpinner.Limits(2)
                            app.LesionIndexSpinner.Value = newValue;
                        end
                        LesionIndexSpinnerValueChanged(app, []);

                    case 'uparrow'

                        app.ButtonGroup.SelectedObject = findobj(app.ButtonGroup.Children, 'Text', '1');
                        ButtonGroupSelectionChanged(app, []);

                    case 'downarrow'

                        app.ButtonGroup.SelectedObject = findobj(app.ButtonGroup.Children, 'Text', '2');
                        ButtonGroupSelectionChanged(app, []);

                    case 'd'

                        app.LesionReviewButtonGroup.SelectedObject = findobj(app.LesionReviewButtonGroup.Children, 'Text', 'Delete');
                        LesionReviewButtonGroupSelectionChanged(app, []);

                    case 's'

                        app.LesionReviewButtonGroup.SelectedObject = findobj(app.LesionReviewButtonGroup.Children, 'Text', 'Keep');
                        LesionReviewButtonGroupSelectionChanged(app, []);

                    case 'e'

                        app.LesionReviewButtonGroup.SelectedObject = findobj(app.LesionReviewButtonGroup.Children, 'Text', 'Draft');
                        LesionReviewButtonGroupSelectionChanged(app, []);

                    case '1'

                        app.LesionEditButtonGroup.SelectedObject = findobj(app.LesionEditButtonGroup.Children, 'Text', 'Clone 1');
                        LesionEditButtonGroupSelectionChanged(app, []);

                    case '2'

                        app.LesionEditButtonGroup.SelectedObject = findobj(app.LesionEditButtonGroup.Children, 'Text', 'Clone 2');
                        LesionEditButtonGroupSelectionChanged(app, []);

                    case '3'

                        app.LesionEditButtonGroup.SelectedObject = findobj(app.LesionEditButtonGroup.Children, 'Text', 'Merge');
                        LesionEditButtonGroupSelectionChanged(app, []);

                    case '4'

                        app.LesionEditButtonGroup.SelectedObject = findobj(app.LesionEditButtonGroup.Children, 'Text', 'Reset');
                        LesionEditButtonGroupSelectionChanged(app, []);

                    case 'return'
                        UpdateButtonPushed(app, []);


                end

            end

        end

        % Button pushed function: goToLastLes
        function goToLastLesButtonPushed(app, event)
             app.LesionIndexSpinner.Value = app.LesionIndexSpinner.Limits(2);  
             LesionIndexSpinnerValueChanged(app, []);
        end

        % Button pushed function: goToFirstLes
        function goToFirstLesButtonPushed(app, event)
            app.LesionIndexSpinner.Value = 1;
            LesionIndexSpinnerValueChanged(app, []);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1545 862];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.KeyPressFcn = createCallbackFcn(app, @UIFigureKeyPress, true);
            app.UIFigure.KeyReleaseFcn = createCallbackFcn(app, @UIFigureKeyRelease, true);

            % Create LeftPanel
            app.LeftPanel = uipanel(app.UIFigure);
            app.LeftPanel.BackgroundColor = [0 0 0];
            app.LeftPanel.Position = [1 3 1543 860];

            % Create UIAxes
            app.UIAxes = uiaxes(app.LeftPanel);
            app.UIAxes.Toolbar.Visible = 'off';
            app.UIAxes.Position = [7 0 1129 768];

            % Create LesionVisualizationAxes
            app.LesionVisualizationAxes = uiaxes(app.LeftPanel);
            ylabel(app.LesionVisualizationAxes, 'Y')
            app.LesionVisualizationAxes.Toolbar.Visible = 'off';
            app.LesionVisualizationAxes.Color = 'none';
            app.LesionVisualizationAxes.HitTest = 'off';
            app.LesionVisualizationAxes.Position = [1182 425 285 317];

            % Create ExportPDFButton
            app.ExportPDFButton = uibutton(app.LeftPanel, 'push');
            app.ExportPDFButton.ButtonPushedFcn = createCallbackFcn(app, @ExportPDFButtonPushed, true);
            app.ExportPDFButton.FontSize = 18;
            app.ExportPDFButton.FontWeight = 'bold';
            app.ExportPDFButton.Tooltip = {'Generate a PDF report'};
            app.ExportPDFButton.Position = [1280 112 113 32];
            app.ExportPDFButton.Text = 'Export PDF';

            % Create PleasewaitLabel
            app.PleasewaitLabel = uilabel(app.LeftPanel);
            app.PleasewaitLabel.FontSize = 24;
            app.PleasewaitLabel.FontColor = [0 1 0];
            app.PleasewaitLabel.Position = [1183 147 341 53];
            app.PleasewaitLabel.Text = 'Please wait ...';

            % Create progressBarFront
            app.progressBarFront = uitextarea(app.LeftPanel);
            app.progressBarFront.Editable = 'off';
            app.progressBarFront.BackgroundColor = [0.2118 0.9686 0.2118];
            app.progressBarFront.Visible = 'off';
            app.progressBarFront.Position = [1368 163 143 22];

            % Create x0
            app.x0 = uispinner(app.LeftPanel);
            app.x0.ValueChangedFcn = createCallbackFcn(app, @x0ValueChanged, true);
            app.x0.FontSize = 20;
            app.x0.FontWeight = 'bold';
            app.x0.FontAngle = 'italic';
            app.x0.FontColor = [1 1 1];
            app.x0.BackgroundColor = [0 0 0];
            app.x0.Tooltip = {'- ='};
            app.x0.Position = [203 793 107 34];

            % Create z0
            app.z0 = uispinner(app.LeftPanel);
            app.z0.ValueChangedFcn = createCallbackFcn(app, @z0ValueChanged, true);
            app.z0.FontSize = 20;
            app.z0.FontWeight = 'bold';
            app.z0.FontAngle = 'italic';
            app.z0.FontColor = [1 1 1];
            app.z0.BackgroundColor = [0 0 0];
            app.z0.Tooltip = {''' \'};
            app.z0.Position = [634 795 107 34];

            % Create y0
            app.y0 = uispinner(app.LeftPanel);
            app.y0.ValueChangedFcn = createCallbackFcn(app, @y0ValueChanged, true);
            app.y0.FontSize = 20;
            app.y0.FontWeight = 'bold';
            app.y0.FontAngle = 'italic';
            app.y0.FontColor = [1 1 1];
            app.y0.BackgroundColor = [0 0 0];
            app.y0.Tooltip = {'[ ]'};
            app.y0.Position = [415 794 107 35];

            % Create ButtonGroup
            app.ButtonGroup = uibuttongroup(app.LeftPanel);
            app.ButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @ButtonGroupSelectionChanged, true);
            app.ButtonGroup.BackgroundColor = [0 0 0];
            app.ButtonGroup.Position = [808 782 190 61];

            % Create Button
            app.Button = uitogglebutton(app.ButtonGroup);
            app.Button.Tooltip = {'(up arrow) Switch to baseline view'};
            app.Button.Text = '1';
            app.Button.BackgroundColor = [0.3882 0.7569 1];
            app.Button.FontSize = 20;
            app.Button.FontWeight = 'bold';
            app.Button.FontColor = [1 1 1];
            app.Button.Position = [33 12 28 34];
            app.Button.Value = true;

            % Create Button_2
            app.Button_2 = uitogglebutton(app.ButtonGroup);
            app.Button_2.Tooltip = {'(down arrow) Switch to followup view'};
            app.Button_2.Text = '2';
            app.Button_2.BackgroundColor = [0.451 0.7686 0.2235];
            app.Button_2.FontSize = 20;
            app.Button_2.FontWeight = 'bold';
            app.Button_2.FontColor = [1 1 1];
            app.Button_2.Position = [81 12 28 34];

            % Create PlayButton
            app.PlayButton = uitogglebutton(app.ButtonGroup);
            app.PlayButton.Tooltip = {'Toggle back and forth between two time points (can be slow if left on for too long)'};
            app.PlayButton.Text = 'Play';
            app.PlayButton.BackgroundColor = [0 0 0];
            app.PlayButton.FontSize = 20;
            app.PlayButton.FontWeight = 'bold';
            app.PlayButton.FontColor = [1 1 1];
            app.PlayButton.Position = [120 12 55 34];

            % Create ProgressTextArea
            app.ProgressTextArea = uitextarea(app.LeftPanel);
            app.ProgressTextArea.Interruptible = 'off';
            app.ProgressTextArea.Editable = 'off';
            app.ProgressTextArea.FontColor = [0.902 0.902 0.902];
            app.ProgressTextArea.BackgroundColor = [0 0 0];
            app.ProgressTextArea.Position = [1168 27 355 72];

            % Create ExportNIfTIButton
            app.ExportNIfTIButton = uibutton(app.LeftPanel, 'push');
            app.ExportNIfTIButton.ButtonPushedFcn = createCallbackFcn(app, @ExportNIfTIButtonPushed, true);
            app.ExportNIfTIButton.WordWrap = 'on';
            app.ExportNIfTIButton.FontSize = 18;
            app.ExportNIfTIButton.FontWeight = 'bold';
            app.ExportNIfTIButton.Position = [1398 113 123 31];
            app.ExportNIfTIButton.Text = 'Export NIfTI';

            % Create LoadBIDSButton
            app.LoadBIDSButton = uibutton(app.LeftPanel, 'push');
            app.LoadBIDSButton.ButtonPushedFcn = createCallbackFcn(app, @LoadBIDSButtonPushed, true);
            app.LoadBIDSButton.FontSize = 18;
            app.LoadBIDSButton.FontWeight = 'bold';
            app.LoadBIDSButton.FontAngle = 'italic';
            app.LoadBIDSButton.Position = [1170 112 106 32];
            app.LoadBIDSButton.Text = 'Load BIDS';

            % Create OverlayAlpha
            app.OverlayAlpha = uislider(app.LeftPanel);
            app.OverlayAlpha.Limits = [0 1];
            app.OverlayAlpha.MajorTicks = [];
            app.OverlayAlpha.Orientation = 'vertical';
            app.OverlayAlpha.ValueChangedFcn = createCallbackFcn(app, @OverlayAlphaValueChanged, true);
            app.OverlayAlpha.ValueChangingFcn = createCallbackFcn(app, @OverlayAlphaValueChanging, true);
            app.OverlayAlpha.MinorTicks = [];
            app.OverlayAlpha.Tooltip = {'Adjust lesion mask transparency'};
            app.OverlayAlpha.Position = [1158 425 3 265];
            app.OverlayAlpha.Value = 1;

            % Create goToFirstLes
            app.goToFirstLes = uibutton(app.LeftPanel, 'push');
            app.goToFirstLes.ButtonPushedFcn = createCallbackFcn(app, @goToFirstLesButtonPushed, true);
            app.goToFirstLes.Position = [1217 784 14 40];
            app.goToFirstLes.Text = 'I';

            % Create goToLastLes
            app.goToLastLes = uibutton(app.LeftPanel, 'push');
            app.goToLastLes.ButtonPushedFcn = createCallbackFcn(app, @goToLastLesButtonPushed, true);
            app.goToLastLes.Position = [1321 784 14 40];
            app.goToLastLes.Text = 'I';

            % Create EnlargingCheckBox
            app.EnlargingCheckBox = uicheckbox(app.LeftPanel);
            app.EnlargingCheckBox.ValueChangedFcn = createCallbackFcn(app, @NewLesionCheckBoxValueChanged, true);
            app.EnlargingCheckBox.Tooltip = {'Shows only the disappearing lesions'};
            app.EnlargingCheckBox.Text = 'Enlarging';
            app.EnlargingCheckBox.FontSize = 20;
            app.EnlargingCheckBox.FontColor = [1 1 1];
            app.EnlargingCheckBox.Position = [1065 759 140 35];

            % Create NewLesionCheckBox
            app.NewLesionCheckBox = uicheckbox(app.LeftPanel);
            app.NewLesionCheckBox.ValueChangedFcn = createCallbackFcn(app, @NewLesionCheckBoxValueChanged, true);
            app.NewLesionCheckBox.Tooltip = {'Shows only the new lesions'};
            app.NewLesionCheckBox.Text = 'New Lesion';
            app.NewLesionCheckBox.FontSize = 20;
            app.NewLesionCheckBox.FontColor = [1 1 1];
            app.NewLesionCheckBox.Position = [1065 809 140 35];

            % Create DisappearingCheckBox
            app.DisappearingCheckBox = uicheckbox(app.LeftPanel);
            app.DisappearingCheckBox.ValueChangedFcn = createCallbackFcn(app, @DisappearingCheckBoxValueChanged, true);
            app.DisappearingCheckBox.Tooltip = {'Shows only the disappearing lesions'};
            app.DisappearingCheckBox.Text = 'Disappearing';
            app.DisappearingCheckBox.FontSize = 20;
            app.DisappearingCheckBox.FontColor = [1 1 1];
            app.DisappearingCheckBox.Position = [1065 784 140 35];

            % Create RButton
            app.RButton = uibutton(app.LeftPanel, 'push');
            app.RButton.ButtonPushedFcn = createCallbackFcn(app, @RButtonPushed, true);
            app.RButton.FontSize = 20;
            app.RButton.FontWeight = 'bold';
            app.RButton.FontAngle = 'italic';
            app.RButton.Position = [1480 539 29 34];
            app.RButton.Text = 'R';

            % Create ZButton
            app.ZButton = uibutton(app.LeftPanel, 'push');
            app.ZButton.ButtonPushedFcn = createCallbackFcn(app, @ZButtonPushed, true);
            app.ZButton.FontSize = 20;
            app.ZButton.FontWeight = 'bold';
            app.ZButton.FontAngle = 'italic';
            app.ZButton.Position = [1480 573 28 34];
            app.ZButton.Text = 'Z';

            % Create YButton
            app.YButton = uibutton(app.LeftPanel, 'push');
            app.YButton.ButtonPushedFcn = createCallbackFcn(app, @YButtonPushed, true);
            app.YButton.FontSize = 20;
            app.YButton.FontWeight = 'bold';
            app.YButton.FontAngle = 'italic';
            app.YButton.Position = [1480 607 28 34];
            app.YButton.Text = 'Y';

            % Create XButton
            app.XButton = uibutton(app.LeftPanel, 'push');
            app.XButton.ButtonPushedFcn = createCallbackFcn(app, @XButtonPushed, true);
            app.XButton.FontSize = 20;
            app.XButton.FontWeight = 'bold';
            app.XButton.FontAngle = 'italic';
            app.XButton.Position = [1480 639 28 34];
            app.XButton.Text = 'X';

            % Create LesionVisibilitySwitch
            app.LesionVisibilitySwitch = uiswitch(app.LeftPanel, 'slider');
            app.LesionVisibilitySwitch.Items = {'One', 'All'};
            app.LesionVisibilitySwitch.ValueChangedFcn = createCallbackFcn(app, @LesionVisibilitySwitchValueChanged, true);
            app.LesionVisibilitySwitch.Tooltip = {'View all lesions or only the selected lesion'};
            app.LesionVisibilitySwitch.FontSize = 20;
            app.LesionVisibilitySwitch.FontWeight = 'bold';
            app.LesionVisibilitySwitch.FontColor = [1 1 1];
            app.LesionVisibilitySwitch.Position = [1397 782 95 42];
            app.LesionVisibilitySwitch.Value = 'One';

            % Create LesionIndexSpinner
            app.LesionIndexSpinner = uispinner(app.LeftPanel);
            app.LesionIndexSpinner.ValueChangedFcn = createCallbackFcn(app, @LesionIndexSpinnerValueChanged, true);
            app.LesionIndexSpinner.FontSize = 20;
            app.LesionIndexSpinner.FontWeight = 'bold';
            app.LesionIndexSpinner.FontAngle = 'italic';
            app.LesionIndexSpinner.Tooltip = {'(left/right arrow) Select lesion index'};
            app.LesionIndexSpinner.Position = [1231 782 92 42];

            % Create LesionReviewButtonGroup
            app.LesionReviewButtonGroup = uibuttongroup(app.LeftPanel);
            app.LesionReviewButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @LesionReviewButtonGroupSelectionChanged, true);
            app.LesionReviewButtonGroup.BackgroundColor = [0 0 0];
            app.LesionReviewButtonGroup.Position = [1167 214 340 196];

            % Create KeepButton
            app.KeepButton = uitogglebutton(app.LesionReviewButtonGroup);
            app.KeepButton.Tooltip = {'(s) This lesion is saved in the clean nifti'};
            app.KeepButton.Text = 'Keep';
            app.KeepButton.FontSize = 25;
            app.KeepButton.FontWeight = 'bold';
            app.KeepButton.Position = [38 142 81 40];
            app.KeepButton.Value = true;

            % Create DraftButton
            app.DraftButton = uitogglebutton(app.LesionReviewButtonGroup);
            app.DraftButton.Tooltip = {'(e) This lesion is saved in the draft nifti'};
            app.DraftButton.Text = 'Draft';
            app.DraftButton.FontSize = 25;
            app.DraftButton.FontWeight = 'bold';
            app.DraftButton.Position = [136 142 75 40];

            % Create DeleteButton
            app.DeleteButton = uitogglebutton(app.LesionReviewButtonGroup);
            app.DeleteButton.Tooltip = {'(d) Remove this lesion from the cleaned up nifti file'};
            app.DeleteButton.Text = 'Delete';
            app.DeleteButton.FontSize = 25;
            app.DeleteButton.FontWeight = 'bold';
            app.DeleteButton.Position = [231 142 87 40];

            % Create TextArea
            app.TextArea = uitextarea(app.LesionReviewButtonGroup);
            app.TextArea.Editable = 'off';
            app.TextArea.FontAngle = 'italic';
            app.TextArea.BackgroundColor = [0.9412 0.9412 0.9412];
            app.TextArea.Position = [38 13 280 41];

            % Create LesionEditButtonGroup
            app.LesionEditButtonGroup = uibuttongroup(app.LesionReviewButtonGroup);
            app.LesionEditButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @LesionEditButtonGroupSelectionChanged, true);
            app.LesionEditButtonGroup.BackgroundColor = [0 0 0];
            app.LesionEditButtonGroup.Position = [35 72 226 49];

            % Create MergeButton
            app.MergeButton = uitogglebutton(app.LesionEditButtonGroup);
            app.MergeButton.Tooltip = {'(3) Merge this lesion from two time points together'};
            app.MergeButton.Text = 'Merge';
            app.MergeButton.Position = [123 13 45 23];
            app.MergeButton.Value = true;

            % Create Clone1Button
            app.Clone1Button = uitogglebutton(app.LesionEditButtonGroup);
            app.Clone1Button.Tooltip = {'(1) Clone the baseline lesion to followup'};
            app.Clone1Button.Text = 'Clone 1';
            app.Clone1Button.Position = [12 13 48 23];

            % Create Clone2Button
            app.Clone2Button = uitogglebutton(app.LesionEditButtonGroup);
            app.Clone2Button.Tooltip = {'(2) Clone the followup lesion to baseline'};
            app.Clone2Button.Text = 'Clone 2';
            app.Clone2Button.Position = [66 13 50 23];

            % Create ResetButton
            app.ResetButton = uitogglebutton(app.LesionEditButtonGroup);
            app.ResetButton.Tooltip = {'(4) Reset to default'};
            app.ResetButton.Text = 'Reset';
            app.ResetButton.Position = [174 13 45 23];

            % Create UpdateButton
            app.UpdateButton = uibutton(app.LesionReviewButtonGroup, 'push');
            app.UpdateButton.ButtonPushedFcn = createCallbackFcn(app, @UpdateButtonPushed, true);
            app.UpdateButton.Tooltip = {'Regenerate new new lesion and disappearing lesion index'};
            app.UpdateButton.Position = [264 78 54 38];
            app.UpdateButton.Text = 'Update';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = lesionView_converted

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end