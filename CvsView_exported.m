classdef CvsView_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        LeftPanel                matlab.ui.container.Panel
        LesionReviewButtonGroup  matlab.ui.container.ButtonGroup
        DeleteButton             matlab.ui.control.ToggleButton
        DraftButton              matlab.ui.control.ToggleButton
        KeepButton               matlab.ui.control.ToggleButton
        Slider                   matlab.ui.control.RangeSlider
        SliderLabel              matlab.ui.control.Label
        goToFirstLes             matlab.ui.control.Button
        goToLastLes              matlab.ui.control.Button
        LesionIndexSpinner       matlab.ui.control.Spinner
        OverlayAlpha             matlab.ui.control.Slider
        LoadBIDSButton           matlab.ui.control.Button
        ExportNIfTIButton        matlab.ui.control.Button
        ProgressTextArea         matlab.ui.control.TextArea
        y0                       matlab.ui.control.Spinner
        z0                       matlab.ui.control.Spinner
        x0                       matlab.ui.control.Spinner
        ExportPNGButton          matlab.ui.control.Button
        UIAxes                   matlab.ui.control.UIAxes
    end


    properties (Access = private)

        % General properties
        subject = 'sub - xxx'; % e.g. sub-001 - Identifier for the subject
        bidsDir
        lesionDerivDir
        voxelSize = 0.7*0.7*0.7./1000; % Voxel size for the images, adjust based on your data
        FlairInfo % metadata - Information about the T2 flair images (used for saving or processing)
        fileStatus = [false,false]; % whether each files are loaded
        allowKey = 0;
        

        % Image data properties
        FlairTP1 % 3D matrix - T2 flair image at time point 1
        Lesion1 % 3D matrix - Lesion image at time point 1
        tmpLesionNameClean1
        tmpLesionNameDraft1
        backupLesion1

        % Image analyses properties
        L1 % 3D matrix - Processed lesion image with lables at time point 1 for analysis
        L1backUp % 3D matrix - backup of L1
        whichT2 % 3D matrix - The variable to hold the currently selected 3D T2 image data
        whichLes % 3D matrix - The variable to hold the currently selected lesion data
        sizeChange % numLes by 3 - [size1, size2, size2-size1] - To store the results of lesion size change analysis
        lesionCenter % numLes by 3 - [x, y, z] - Center coordinates of lesions, used for visualization adjustments

        % Indexing
        currentIndex = 1 % scaler - Index of the currently selected lesion for processing
        currentImageIndex = 1 % 1 or 2 - Indicates the current image being displayed (1 for FlairTP1, 2 for FlairTP2)
        lesionIndex % numLes by 1 - Array of unique indices for each lesion
        whichIndex % which index list are currently being use, i.e, are we viewing all lesions or only new lesion etc
        largestLesion = 1
        lesionVol

        % Visualization and UI elements
        sizeZoom double = 26; % Zoom window size for detailed lesion viewing

        hLes % Placeholder for lesion visualization handles
        fig % Main figure for export
        progressBarLength
        blueColor = [0,120,255]./255;


        hLes_other 
        hLes_selected 

        % Lesion processing and review properties
        Lesion1Clean % 3D matrix - Cleaned lesion image at time point 1
        Lesion1Draft % 3D matrix - Draft lesion image at time point 1

        newLesionMask % % 3D matrix - Cleaned lesion image at time point 2 (color coded 1 2 3)
        LesionReviewStates % numLes by 2 time points - Stores the review state ('keep', 'draft', 'delete') for each lesion
        LesionEditStates % numLes by 2 time points - Stores the edit state ('merge', 'clone1', 'clone2','reset') for each lesion
    end


    methods (Access = private)

        function updateImage(app)

            % This function prepares the 2D view with color-coded lesion overlays

            % --- Prepare the Base Image ---

            % Extract slices for the bottom row images
            img21 = squeeze(app.whichT2(app.x0.Value,:,:))'; % sagittal
            img22 = squeeze(app.whichT2(:,app.y0.Value,:))'; % coronal
            img23 = squeeze(app.whichT2(:,:,app.z0.Value));  % axial

            % Combine them horizontally
            botrow = [img21 img22 img23];

            % Calculate padding because the images are wider than a square
            padding = (size(botrow,2) - size(botrow,1)*3) / 2;

            % Extract and resize the zoomed-in images for the top row
            img11 = imresize(img21(max(1, app.z0.Value - app.sizeZoom):min(end, app.z0.Value + app.sizeZoom), ...
                max(1, app.y0.Value - app.sizeZoom):min(end, app.y0.Value + app.sizeZoom)), ...
                [size(botrow,1) size(botrow,1)], 'nearest');
            img12 = imresize(img22(max(1, app.z0.Value - app.sizeZoom):min(end, app.z0.Value + app.sizeZoom), ...
                max(1, app.x0.Value - app.sizeZoom):min(end, app.x0.Value + app.sizeZoom)), ...
                [size(botrow,1) size(botrow,1)], 'nearest');
            img13 = imresize(img23(max(1, app.x0.Value - app.sizeZoom):min(end, app.x0.Value + app.sizeZoom), ...
                max(1, app.y0.Value - app.sizeZoom):min(end, app.y0.Value + app.sizeZoom)), ...
                [size(botrow,1) size(botrow,1)], 'nearest');

            % Combine the top row images with padding
            toprow = [zeros(size(botrow,1), floor(padding)-20), ...
                img11, zeros(size(botrow,1), 20), ...
                img12, zeros(size(botrow,1), 20), ...
                img13, zeros(size(botrow,1), ceil(padding)-20)];

            % Combine top and bottom rows
            img = [toprow; botrow];

            % Display the combined image in UIAxes
            imshow(img, 'DisplayRange', [app.Slider.Value(1) app.Slider.Value(2)], 'Parent', app.UIAxes); % adjust color range when Flair is loaded
            hold(app.UIAxes, 'on'); % Keep the original image, allowing overlays to be added

            % --- Prepare Lesion Overlays ---

            % Retrieve and preprocess the lesion mask
            if ~isempty(app.L1)
                currentLesionMask = flip(app.L1, 2);
                currentLesionMask = flip(currentLesionMask, 3);
                currentLesionMask(ismember(currentLesionMask, app.lesionIndex(app.LesionReviewStates(:,1) == "delete"))) = 0;
            else
                currentLesionMask = app.whichLes;
            end

            % **Important Modification: Keep the lesion labels instead of binarizing**
            % currentLesionMask(currentLesionMask > 0.5) = 1; % Remove or comment out this line

            % Define the selected lesion label
            selectedLabel = app.currentIndex; % Ensure this property is properly defined in your app

            % Create separate masks for selected and other lesions
            selectedMask = (currentLesionMask == selectedLabel);
            otherMask = (currentLesionMask > 0) & (currentLesionMask ~= selectedLabel);

            % --- Process Selected Lesion Mask ---

            % Extract and process slices for the selected lesion (bottom row)
            les_selected21 = mat2gray(squeeze(selectedMask(app.x0.Value,:,:)))';
            les_selected22 = mat2gray(squeeze(selectedMask(:,app.y0.Value,:)))';
            les_selected23 = mat2gray(squeeze(selectedMask(:,:,app.z0.Value)));

            % Combine selected lesion slices horizontally for the bottom row
            botles_selected = [les_selected21 les_selected22 les_selected23];

            % Extract and resize zoomed-in selected lesion images for the top row
            img11_selected = imresize(selectedMask(max(1, app.z0.Value - app.sizeZoom):min(end, app.z0.Value + app.sizeZoom), ...
                max(1, app.y0.Value - app.sizeZoom):min(end, app.y0.Value + app.sizeZoom)), ...
                [size(botrow,1) size(botrow,1)], 'nearest');
            img12_selected = imresize(selectedMask(max(1, app.z0.Value - app.sizeZoom):min(end, app.z0.Value + app.sizeZoom), ...
                max(1, app.x0.Value - app.sizeZoom):min(end, app.x0.Value + app.sizeZoom)), ...
                [size(botrow,1) size(botrow,1)], 'nearest');
            img13_selected = imresize(selectedMask(max(1, app.x0.Value - app.sizeZoom):min(end, app.x0.Value + app.sizeZoom), ...
                max(1, app.y0.Value - app.sizeZoom):min(end, app.y0.Value + app.sizeZoom)), ...
                [size(botrow,1) size(botrow,1)], 'nearest');

            % Combine selected lesion top row with padding
            toples_selected = [zeros(size(botrow,1), floor(padding)-20), ...
                img11_selected, zeros(size(botrow,1), 20), ...
                img12_selected, zeros(size(botrow,1), 20), ...
                img13_selected, zeros(size(botrow,1), ceil(padding)-20)];

            % --- Process Other Lesions Mask ---

            % Extract and process slices for other lesions (bottom row)
            les_other21 = mat2gray(squeeze(otherMask(app.x0.Value,:,:)))';
            les_other22 = mat2gray(squeeze(otherMask(:,app.y0.Value,:)))';
            les_other23 = mat2gray(squeeze(otherMask(:,:,app.z0.Value)));

            % Combine other lesions slices horizontally for the bottom row
            botles_other = [les_other21 les_other22 les_other23];

            % Extract and resize zoomed-in other lesions images for the top row
            img11_other = imresize(otherMask(max(1, app.z0.Value - app.sizeZoom):min(end, app.z0.Value + app.sizeZoom), ...
                max(1, app.y0.Value - app.sizeZoom):min(end, app.y0.Value + app.sizeZoom)), ...
                [size(botrow,1) size(botrow,1)], 'nearest');
            img12_other = imresize(otherMask(max(1, app.z0.Value - app.sizeZoom):min(end, app.z0.Value + app.sizeZoom), ...
                max(1, app.x0.Value - app.sizeZoom):min(end, app.x0.Value + app.sizeZoom)), ...
                [size(botrow,1) size(botrow,1)], 'nearest');
            img13_other = imresize(otherMask(max(1, app.x0.Value - app.sizeZoom):min(end, app.x0.Value + app.sizeZoom), ...
                max(1, app.y0.Value - app.sizeZoom):min(end, app.y0.Value + app.sizeZoom)), ...
                [size(botrow,1) size(botrow,1)], 'nearest');

            % Combine other lesions top row with padding
            toples_other = [zeros(size(botrow,1), floor(padding)-20), ...
                img11_other, zeros(size(botrow,1), 20), ...
                img12_other, zeros(size(botrow,1), 20), ...
                img13_other, zeros(size(botrow,1), ceil(padding)-20)];

            % --- Combine Top and Bottom Rows for Overlays ---

            % Selected Lesion Overlay
            img_selected = [toples_selected; botles_selected];
            img_selected = double(img_selected > 0.5);
            img_selected = bwperim(img_selected, 8);
            img_selected = imdilate(bwperim(img_selected, 8), strel('disk', 1));

            % Other Lesions Overlay
            img_other = [toples_other; botles_other];
            img_other = double(img_other > 0.5);
            img_other = bwperim(img_other, 8);
            img_other = imdilate(bwperim(img_other, 8), strel('disk', 1));

            % --- Create Colored Overlays ---

            % Color for other lesions (blue)
            tmpImg_other = double(img_other) .* reshape(app.blueColor, [1, 1, 3]);

            % Color for selected lesion (green)
            greenColor = [0, 1, 0]; % Define green color
            tmpImg_selected = double(img_selected) .* reshape(greenColor, [1, 1, 3]);

            % --- Display the Overlays ---

            % Display other lesions in blue
            app.hLes_other = imshow(tmpImg_other, 'Parent', app.UIAxes);
            set(app.hLes_other, 'AlphaData', double(img_other) * app.OverlayAlpha.Value);

            % Display selected lesion in green
            app.hLes_selected = imshow(tmpImg_selected, 'Parent', app.UIAxes);
            set(app.hLes_selected, 'AlphaData', double(img_selected) * app.OverlayAlpha.Value); % Ensure you have a SelectedOverlayAlpha property

            % --- Draw Zoom Rectangles (Optional) ---

            % Calculate starting positions for rectangles
            startXImg22 = size(img21, 2) + 1;
            startXImg23 = startXImg22 + size(img22, 2);
            startY = size(img21, 1) + 1;

            % Define the zoom area size
            zoomAreaSize = 2 * app.sizeZoom; % The size of the zoomed area

            % Drawing rectangle for img21 (no adjustment needed for startX)
            rectangle('Position', [app.y0.Value - app.sizeZoom, ...
                startY + app.z0.Value - app.sizeZoom, ...
                zoomAreaSize, zoomAreaSize], ...
                'EdgeColor', 'w', 'LineWidth', 1, 'Parent', app.UIAxes);

            % Drawing rectangle for img22 (adjust startX for img22)
            rectangle('Position', [startXImg22 + app.x0.Value - app.sizeZoom, ...
                startY + app.z0.Value - app.sizeZoom, ...
                zoomAreaSize, zoomAreaSize], ...
                'EdgeColor', 'w', 'LineWidth', 1, 'Parent', app.UIAxes);

            % Drawing rectangle for img23 (adjust startX for img23)
            rectangle('Position', [startXImg23 + app.y0.Value - app.sizeZoom, ...
                startY + app.x0.Value - app.sizeZoom, ...
                zoomAreaSize, zoomAreaSize], ...
                'EdgeColor', 'w', 'LineWidth', 1, 'Parent', app.UIAxes);

            hold(app.UIAxes, 'off');

        end

        function analyzeLesions(app)
            close all;
            % This function analyzes lesions across two time points to identify new,
            % continuing, and merged lesions. It labels each lesion, matches lesions
            % across time points, calculates their volumes, and updates the UI
            % components accordingly.

            % Label the lesions in each time point image using a binary threshold of 0.8
            % and a connectivity of 26.

            [app.L1, ~] = bwlabeln(app.backupLesion1  > 0.8, 26);
            lesion1index = nonzeros(unique(app.L1));
            app.lesionVol = zeros(nnz(lesion1index), 1);
            for ii = 1:nnz(lesion1index)
                app.lesionVol(ii) = max([nnz(app.L1 == ii)]); % Number of voxels in the ith lesion
            end

            [app.L1, ~] = bwlabeln(app.Lesion1 > 0.8, 26);

            % Initialize arrays to store new indices for matched lesions across time points
            lesion1index = nonzeros(unique(app.L1));
    
            updateProgress(app,[' ...']);


            valueToIndex = containers.Map(unique(lesion1index), 1:numel(unique(lesion1index)));
            lesion1index = arrayfun(@(x) valueToIndex(x),lesion1index);

            [~, loc] = ismember(app.L1, lesion1index);
            loc(loc > 0) = lesion1index(loc(loc > 0));
            app.L1(loc > 0) = loc(loc > 0);

            updateProgress(app,'Sorting lesions by size ...')
            newlist = unique(lesion1index);
            lesionVol = zeros(nnz(newlist), 1);
            for ii = 1:nnz(newlist)
                lesionVol(ii) = max([nnz(app.L1 == ii)]); % Number of voxels in the ith lesion
            end

            [~,newlistOrder] = sort(lesionVol,'descend');

            [~, loc] = ismember(app.L1, newlistOrder);
            loc(loc > 0) = newlist(loc(loc > 0));
            app.L1(loc > 0) = loc(loc > 0);


            % remove any lesion size less than xxx
            app.L1(ismember(app.L1, find(sort(lesionVol,'descend')<3))) = 0;


            updateProgress(app,'Calculating lesion centers ...')

            % Calculate the center of each lesion for visualization
            app.lesionIndex = nonzeros(unique(app.L1)); % Combined list of unique lesion indices
            app.lesionCenter = zeros(numel(app.lesionIndex), 3);
            % Note: Image orientation adjustments might be necessary for correct visualization
            tmpL1 = flip(app.L1, 2);
            tmpL1 = flip(tmpL1, 3);

            % Initialize the matrix to store size changes across two time points
            app.sizeChange = zeros(numel(app.lesionIndex), 3);

            for ii = 1:numel(app.lesionIndex)
                % Generate binary matrices for each lesion by comparing with their indices
                binaryMat = tmpL1 == app.lesionIndex(ii);
                % Count the number of true values (lesion volume) in time point 1
                app.sizeChange(ii, 1) = sum(binaryMat(:));
    
          
                % Calculate the centroid of the lesion by finding the index of maximum sum along each dimension
                [~, app.lesionCenter(app.lesionIndex(ii), 1)] = max(squeeze(sum(sum(binaryMat, 2), 3)));
                [~, app.lesionCenter(app.lesionIndex(ii), 2)] = max(squeeze(sum(sum(binaryMat, 1), 3)));
                [~, app.lesionCenter(app.lesionIndex(ii), 3)] = max(squeeze(sum(sum(binaryMat, 1), 2)));
            end
            % Calculate the change in lesion size between two time points and convert to volume
            app.sizeChange  =  app.sizeChange * app.voxelSize;
            

 
            % Set the limits and enable the lesion index spinner based on available lesions
            app.LesionIndexSpinner.Limits = [1, size(app.lesionCenter, 1)];
            app.LesionIndexSpinner.Enable = 'on';
            % Initialize the review states for each lesion across both time points as "keep"
            app.LesionReviewStates = repmat("keep", numel(app.lesionIndex), 1);
            app.LesionEditStates = repmat("reset", numel(app.lesionIndex), 1);

            % Prepare clean and draft lesion matrices and backup for both time points
            app.Lesion1Clean = app.L1;
            app.Lesion1Draft = zeros(size(app.L1));
            app.L1backUp = app.L1;


            % Display summary information about lesions in TextArea
            app.currentIndex = 1;

            app.x0.Value = app.lesionCenter(app.currentIndex,1);
            app.y0.Value = app.lesionCenter(app.currentIndex,2);
            app.z0.Value = app.lesionCenter(app.currentIndex,3);

            app.goToLastLes.Text = num2str(app.LesionIndexSpinner.Limits(2));
            app.goToFirstLes.Text = num2str(app.LesionIndexSpinner.Limits(1));


             updateProgress(app,'Finished analyzing lesions')
             updateProgress(app,'Ready')

        end

        function updateLesionMasks(app)
            % first check edit state and then check for review state

            currentState = app.LesionReviewStates(app.currentIndex,app.currentImageIndex); % Get current review state

            switch currentState
                case 'keep'

                    updateProgress(app,'saving to clean')
                        app.Lesion1Clean(app.L1==app.currentIndex) = app.currentIndex;
                        app.Lesion1Draft(app.L1==app.currentIndex) = 0;

                case 'draft'
                     updateProgress(app,'saving to draft')
                        app.Lesion1Clean(app.L1==app.currentIndex) = 0;
                        app.Lesion1Draft(app.L1==app.currentIndex) = app.currentIndex;

                case 'delete'
                    updateProgress(app,'removing from clean & draft')
                        app.Lesion1Clean(app.L1==app.currentIndex) = 0;
                        app.Lesion1Draft(app.L1==app.currentIndex) = 0;

            end
            updateProgress(app,['Done!'])
        end

        function updateReviewStateUI(app)              

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


        function startCompute(app)
            if ~isempty(app.Lesion1) 
                analyzeLesions(app);
                updateImage(app); % Refresh the T2 flair image display
                checkWhichIndexList(app);

                % Make export buttons visible and enabled
                app.ExportNIfTIButton.Enable = 'on';
                app.ExportPNGButton.Enable = 'on';

                app.DeleteButton.Enable = 'on';
                app.DraftButton.Enable = 'on';
                app.KeepButton.Enable = 'on';


  
                app.allowKey = 1;

            end
        end

        function checkWhichIndexList(app)

            % based on lesion check boxes
            app.whichIndex = app.lesionIndex;
            app.LesionIndexSpinner.Limits = [1, numel(app.whichIndex)];

            app.currentIndex = app.whichIndex(min([app.LesionIndexSpinner.Value numel(app.whichIndex)]));
            app.x0.Value = app.lesionCenter(app.currentIndex,1);
            app.y0.Value = app.lesionCenter(app.currentIndex,2);
            app.z0.Value = app.lesionCenter(app.currentIndex,3);

        end


    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            updateProgress(app,'Hi hi, ready to start.')
            app.x0.Value = 38;
            app.y0.Value = 38;
            app.z0.Value = 38;
            % Initialize with a random matrix of size 260x311x260
            app.whichT2 = rand(260, 311, 260);
            app.whichLes = rand(260, 311, 260);

            app.x0.Limits = [1 size(app.whichT2, 3)];
            app.y0.Limits = [1 size(app.whichT2, 2)];
            app.z0.Limits = [1 size(app.whichT2, 1)];

            app.currentImageIndex = 1;
            app.lesionIndex = 1;
            app.whichIndex = 1;

            app.LesionIndexSpinner.Limits = [1, 2]; % Minimal safe range
            app.LesionIndexSpinner.Value = 1; % Set an initial value
            app.currentIndex = 1;
            app.LesionIndexSpinner.Enable = 'off'; % Disable until lesions are loaded

            % Call updateImage to display the initial random matrix or handle as needed
            updateImage(app);

            app.ExportNIfTIButton.Enable = 'off';
            app.ExportPNGButton.Enable = 'off';
            app.DeleteButton.Enable = 'off';
            app.DraftButton.Enable = 'off';
            app.KeepButton.Enable = 'off';


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

    tmpVal = strfind(string(subDir), filesep);
    % Extract the subject ID
    app.subject = char(extractAfter(string(subDir), tmpVal(end)));
    % Extract the lesion type - raw, manual, or clean?
    pathParts = strsplit(subDir, filesep);
    subIndex = find(contains(pathParts, 'sub-'));
    app.lesionDerivDir = pathParts{subIndex - 1};
    % Extract the BIDS directory
    app.bidsDir = char(extractBefore(string(subDir), tmpVal(end-2)));

    LamDir = 'flairStar';
    LesDir = app.lesionDerivDir; % April 20th update - make lesion dir dynamic 

    updateProgress(app,['Loading from :'  app.bidsDir])
    % Attempt to load each file

    try
        %% Load FLAIR Image
        FlairTP1File = dir(fullfile(app.bidsDir,'derivatives',LamDir,app.subject, '*FLAIRSTAR.nii.gz'));

        if ~isempty(FlairTP1File)
            updateProgress(app,['Loading T2 Flair time point 1 from : ', fullfile(FlairTP1File.folder, FlairTP1File.name)]);
            FlairPath = fullfile(FlairTP1File.folder, FlairTP1File.name);
            app.FlairTP1 = niftiread(FlairPath);
            app.FlairInfo = niftiinfo(FlairPath);
            app.FlairTP1 = flip(app.FlairTP1,2); % Adjust orientation as needed
            app.FlairTP1 = flip(app.FlairTP1,3);
            app.fileStatus(1) = true;

            app.Slider.Limits = double([min(app.FlairTP1(:)) max(app.FlairTP1(:))]);
            
        else
            updateProgress(app,['*** No baseline FLAIR found ***'])
        end

        %% Load Lesion Mask
        lesion1File = dir(fullfile(app.bidsDir,'derivatives',LamDir,app.subject, '*lesion*.nii.gz'));

        if ~isempty(lesion1File)
            updateProgress(app,['Loading Lesion mask from : ', fullfile(lesion1File(1).folder, lesion1File(1).name)]);
            LesionPath = fullfile(lesion1File(1).folder, lesion1File(1).name);
            app.Lesion1 = niftiread(LesionPath);
            app.backupLesion1 = app.Lesion1;
            % app.FlairInfo = niftiinfo(fullfile(lesion1File(1).folder, lesion1File(1).name));
            app.fileStatus(2) = true;
            % New file names for saving the cleaned-up version of lesions
            app.tmpLesionNameClean1 = fullfile(app.bidsDir,'derivatives','CvsView',app.subject, strrep(lesion1File(1).name,'_mask.nii.gz','Clean_mask.nii.gz'));
            app.tmpLesionNameDraft1 = fullfile(app.bidsDir,'derivatives','CvsView',app.subject, strrep(lesion1File(1).name,'lesion','draft'));
        else
            updateProgress(app,['*** No baseline lesion found ***'])
        end
        close all;

        %% Resample Images to Isotropic Voxel Size
        if app.fileStatus(1) && app.fileStatus(2)
            % Get original voxel dimensions
            originalPxDim = app.FlairInfo.PixelDimensions; % [xSpacing, ySpacing, zSpacing]

            % Define reference spacing (smallest voxel dimension)
            refSpacing = min(originalPxDim);

            % Calculate scaling factors for each dimension
            scaleFactors = originalPxDim / refSpacing;

            % Compute new image sizes
            newSizeFlair = round(size(app.FlairTP1) .* scaleFactors);
            newSizeLesion = round(size(app.Lesion1) .* scaleFactors);

            % Resample FLAIR Image
            app.FlairTP1 = imresize3(app.FlairTP1, newSizeFlair, 'linear');

            % Update PixelDimensions in FlairInfo
            app.FlairInfo.PixelDimensions = [refSpacing, refSpacing, refSpacing];

            % Resample Lesion Mask using 'nearest' to preserve labels
            app.Lesion1 = imresize3(app.Lesion1, newSizeLesion, 'nearest');

            % Assign to app.whichT2 and app.whichLes for consistency with existing code
            app.whichT2 = app.FlairTP1;
            app.whichLes = app.Lesion1;

            % Update ImageSize in FlairInfo
            app.FlairInfo.ImageSize = size(app.FlairTP1);

            %% Pad the Third Dimension 
            desired_z_size = app.FlairInfo.ImageSize(1);
            current_z_size = size(app.whichT2, 3); % 

            if current_z_size < desired_z_size
                pad_total = desired_z_size - current_z_size; % 
                pad_before = floor(pad_total / 2); % 
                pad_after = ceil(pad_total / 2);  % 

                % Verify padding amounts
                if pad_before + current_z_size + pad_after ~= desired_z_size
                    error('Padding calculation error: total size mismatch.');
                end

                % Create padding arrays
                padding_flair = zeros(size(app.whichT2,1), size(app.whichT2,2), pad_before);
                padding_lesion = zeros(size(app.whichLes,1), size(app.whichLes,2), pad_before);

                padding_flair_after = zeros(size(app.whichT2,1), size(app.whichT2,2), pad_after);
                padding_lesion_after = zeros(size(app.whichLes,1), size(app.whichLes,2), pad_after);

                % Pad FLAIR Image
                app.whichT2 = cat(3, padding_flair, app.whichT2, padding_flair_after);

                % Pad Lesion Mask
                app.whichLes = cat(3, padding_lesion, app.whichLes, padding_lesion_after);
                app.Lesion1 = app.whichLes;

                % Update ImageSize after padding
                app.FlairInfo.ImageSize = size(app.whichT2);
                
                app.x0.Limits = [1 size(app.whichT2, 3)];
                app.y0.Limits = [1 size(app.whichT2, 2)];
                app.z0.Limits = [1 size(app.whichT2, 1)];

                app.x0.Value = round(size(app.whichT2, 3)/2);
                app.y0.Value = round(size(app.whichT2, 2)/2);
                app.z0.Value = round(size(app.whichT2, 1)/2);


            elseif current_z_size > desired_z_size
                error('Current z-dimension is larger than desired. Trimming not implemented.');
            end
        end

        %% Proceed with Existing Workflow
        app.currentImageIndex = 1;
        updateImage(app);
        close all;

        %% Start Computation or Further Processing
        startCompute(app);

    catch ME
        updateProgress(app,['Error loading files: ', ME.message]);
    end
    close all;
        end

        % Value changed function: LesionIndexSpinner
        function LesionIndexSpinnerValueChanged(app, event)
            checkWhichIndexList(app);
             updateReviewStateUI(app);
            updateImage(app);

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

          
            updateProgress(app,sprintf('*** CVS - %d out of %d lesions ***',sum(contains(app.LesionReviewStates(:, app.currentImageIndex), {'keep'})),numel(app.lesionIndex)))
          
        end

        % Button pushed function: ExportNIfTIButton
        function ExportNIfTIButtonPushed(app, event)
            % Define the folder path
            folder = fullfile(app.bidsDir, 'derivatives', 'CvsView', app.subject);
            if ~isfolder(folder)
                mkdir(folder);
            end

            % Convert lesion data to single precision logical
            app.Lesion1Clean = single(logical(app.Lesion1Clean));
            app.Lesion1Draft = single(logical(app.Lesion1Draft));

            % Initialize waitbar
            totalSteps = 3; % Total number of steps
            hWaitbar = waitbar(0, '*** Please wait, saving nii.gz files ***', 'Name', 'Saving NIfTI Files');

            try
                % Step 1: Saving Lesion1Clean
                waitbar(1/totalSteps, hWaitbar, 'Saving Lesion1Clean ...');
                updateProgress(app, 'Saving Lesion1Clean ...'); % Optional: Update textual progress

                % Ensure the folder for Lesion1Clean exists
                folderPathClean = fileparts(app.tmpLesionNameClean1);
                if ~isfolder(folderPathClean)
                    mkdir(folderPathClean);
                end

                % Save Lesion1Clean
                niftiwrite(app.Lesion1Clean, app.tmpLesionNameClean1, app.FlairInfo, 'Compressed', true);

                % Step 2: Saving Lesion1Draft
                waitbar(2/totalSteps, hWaitbar, 'Saving Lesion1Draft ...');
                updateProgress(app, 'Saving Lesion1Draft ...'); % Optional: Update textual progress

                % Ensure the folder for Lesion1Draft exists
                folderPathDraft = fileparts(app.tmpLesionNameDraft1);
                if ~isfolder(folderPathDraft)
                    mkdir(folderPathDraft);
                end

                % Save Lesion1Draft
                niftiwrite(app.Lesion1Draft, app.tmpLesionNameDraft1, app.FlairInfo, 'Compressed', true);

                % Step 3: Completion
                waitbar(3/totalSteps, hWaitbar, 'Done!');
                updateProgress(app, 'Done!'); % Optional: Update textual progress

            catch ME
                % If an error occurs, close the waitbar and rethrow the error
                close(hWaitbar);
                rethrow(ME);
            end

            % Close the waitbar after all steps are done
            close(hWaitbar);
        end

        % Button pushed function: ExportPNGButton
        function ExportPNGButtonPushed(app, event)

            % Define a subfolder to store exported images
            exportFolder = fullfile(app.bidsDir,'derivatives','CvsView',app.subject);

            % Create the folder if it doesn't exist
            if ~exist(exportFolder, 'dir')
                mkdir(exportFolder);
            end

            % Identify lesions marked as "yes" in LesionReviewStates
            % Assuming LesionReviewStates is a 2D array where rows correspond to lesions
            % and columns correspond to images or views. Adjust indexing as necessary.
            % For example, if app.LesionReviewStates is a table or another structure,
            % modify the following line accordingly.

            % Here, we assume that "yes" is stored as lowercase 'yes' in the states
            % and that each row represents a lesion. Adjust if your data structure is different.
            lesionsToExport = find(contains(app.LesionReviewStates(:, app.currentImageIndex), {'keep','draft'}));

            % Check if there are any lesions to export
            if isempty(lesionsToExport)
                uialert(app.UIFigure, 'No lesions marked as "keep" to export.', 'Export Completed');
                return;
            end

            totalVolume =  sum(app.lesionVol)*app.FlairInfo.PixelDimensions(1)*app.FlairInfo.PixelDimensions(2)*app.FlairInfo.PixelDimensions(3)./1000;
            totalLesion = size(app.LesionReviewStates,1);
            % --- Write Lesion Statistics to a .txt File ---

            % Define the text filename
            txtFilename = sprintf('%s.txt', app.subject);
            txtFilepath = fullfile(exportFolder, txtFilename);

            % Prepare the content to write
            txtContent = sprintf(['Subject ID: %s\n' ...
                'Total Number of Lesions: %d\n' ...
                'Total Lesion Volume: %.2f ml\n' ...
                'CVS - %d out of %d lesions\n'], ...
                app.subject, totalLesion, totalVolume,sum(contains(app.LesionReviewStates(:, app.currentImageIndex), {'keep'})),numel(app.lesionIndex));

            % Write the content to the text file
            try
                fid = fopen(txtFilepath, 'w');
                if fid == -1
                    error('Failed to create text file: %s', txtFilepath);
                end
                fprintf(fid, '%s', txtContent);
                fclose(fid);
            catch ME
                uialert(app.UIFigure, sprintf('Failed to write lesion statistics to text file.\nError: %s', ME.message), 'Export Completed', 'Icon', 'warning');
                return;
            end

            % Initialize a waitbar to show progress
            wb = waitbar(0, 'Exporting Lesion Images...', 'Name', 'Export Progress');

            % Loop through each selected lesion and export the image
            for i = 1:length(lesionsToExport)
                lesionIdx = lesionsToExport(i);

                % Update the currentIndex to the lesion to export
                app.LesionIndexSpinner.Value = lesionIdx;
                LesionIndexSpinnerValueChanged(app, []);

                % Update the UIAxes with the current lesion
                updateImage(app);

                % Pause briefly to ensure the UI updates (optional, may help with rendering)
                pause(0.1);

                % Define the filename with lesion index

                if strcmp(app.LesionReviewStates(lesionIdx, app.currentImageIndex), 'keep')
                    filename = sprintf('%s_CVS_%d.png', app.subject,lesionIdx);
                else
                    filename = sprintf('%s_maybe_%d.png', app.subject,lesionIdx);
                end

                filepath = fullfile(exportFolder, filename);

                % Capture the UIAxes as a frame
                % Option 1: Using exportgraphics (recommended for higher quality)
                try
                    exportgraphics(app.UIAxes, filepath, 'Resolution', 300);
                catch ME
                    % If exportgraphics is not available, use alternative method
                    % Option 2: Using getframe and imwrite
                    frame = getframe(app.UIAxes);
                    imwrite(frame.cdata, filepath);
                end

                % Update the waitbar
                waitbar(i / length(lesionsToExport), wb, sprintf('Exporting Lesion %d of %d...', i, length(lesionsToExport)));
            end

            % Close the waitbar
            close(wb);

            % Notify the user upon completion with an 'info' icon
            uialert(app.UIFigure, ...
                sprintf('Exported %d lesion(s) to %s.', length(lesionsToExport), exportFolder), ...
                'Export Completed', ...
                'Icon', 'info');
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
                        % Decrease spinner value
                        newValue = app.LesionIndexSpinner.Value - 1;
                        % Check if newValue is less than Spinner's Minimum
                        if newValue >= app.LesionIndexSpinner.Limits(1)
                            app.LesionIndexSpinner.Value = newValue;
                        end
                        LesionIndexSpinnerValueChanged(app, []);
              

                    case 'downarrow'

                        % Increase spinner value
                        newValue = app.LesionIndexSpinner.Value + 1;
                        % Check if newValue exceeds Spinner's Maximum
                        if newValue <= app.LesionIndexSpinner.Limits(2)
                            app.LesionIndexSpinner.Value = newValue;
                        end
                        LesionIndexSpinnerValueChanged(app, []);

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

        % Value changed function: Slider
        function SliderValueChanged(app, event)


            updateImage(app); 
        end

        % Value changing function: Slider
        function SliderValueChanging(app, event)
            app.Slider.Value(1) = event.Value(1);
            app.Slider.Value(2) = event.Value(2);

            updateImage(app); 
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Color = [0 0 0];
            app.UIFigure.Position = [100 100 1088 907];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.KeyPressFcn = createCallbackFcn(app, @UIFigureKeyPress, true);
            app.UIFigure.KeyReleaseFcn = createCallbackFcn(app, @UIFigureKeyRelease, true);

            % Create LeftPanel
            app.LeftPanel = uipanel(app.UIFigure);
            app.LeftPanel.BorderType = 'none';
            app.LeftPanel.BorderWidth = 0;
            app.LeftPanel.BackgroundColor = [0 0 0];
            app.LeftPanel.Position = [1 1 1059 907];

            % Create UIAxes
            app.UIAxes = uiaxes(app.LeftPanel);
            app.UIAxes.Toolbar.Visible = 'off';
            app.UIAxes.Position = [32 162 1005 668];

            % Create ExportPNGButton
            app.ExportPNGButton = uibutton(app.LeftPanel, 'push');
            app.ExportPNGButton.ButtonPushedFcn = createCallbackFcn(app, @ExportPNGButtonPushed, true);
            app.ExportPNGButton.FontSize = 30;
            app.ExportPNGButton.FontWeight = 'bold';
            app.ExportPNGButton.Tooltip = {'Generate PNG of CSV lesion'};
            app.ExportPNGButton.Position = [161 39 118 82];
            app.ExportPNGButton.Text = {'Export '; 'PNG'};

            % Create x0
            app.x0 = uispinner(app.LeftPanel);
            app.x0.ValueChangedFcn = createCallbackFcn(app, @x0ValueChanged, true);
            app.x0.FontSize = 20;
            app.x0.FontWeight = 'bold';
            app.x0.FontAngle = 'italic';
            app.x0.FontColor = [1 1 1];
            app.x0.BackgroundColor = [0 0 0];
            app.x0.Tooltip = {'- ='};
            app.x0.Position = [198 853 107 34];

            % Create z0
            app.z0 = uispinner(app.LeftPanel);
            app.z0.ValueChangedFcn = createCallbackFcn(app, @z0ValueChanged, true);
            app.z0.FontSize = 20;
            app.z0.FontWeight = 'bold';
            app.z0.FontAngle = 'italic';
            app.z0.FontColor = [1 1 1];
            app.z0.BackgroundColor = [0 0 0];
            app.z0.Tooltip = {''' \'};
            app.z0.Position = [637 855 107 34];

            % Create y0
            app.y0 = uispinner(app.LeftPanel);
            app.y0.ValueChangedFcn = createCallbackFcn(app, @y0ValueChanged, true);
            app.y0.FontSize = 20;
            app.y0.FontWeight = 'bold';
            app.y0.FontAngle = 'italic';
            app.y0.FontColor = [1 1 1];
            app.y0.BackgroundColor = [0 0 0];
            app.y0.Tooltip = {'[ ]'};
            app.y0.Position = [416 854 107 35];

            % Create ProgressTextArea
            app.ProgressTextArea = uitextarea(app.LeftPanel);
            app.ProgressTextArea.Interruptible = 'off';
            app.ProgressTextArea.Editable = 'off';
            app.ProgressTextArea.FontColor = [0.902 0.902 0.902];
            app.ProgressTextArea.BackgroundColor = [0 0 0];
            app.ProgressTextArea.Position = [718 46 330 70];

            % Create ExportNIfTIButton
            app.ExportNIfTIButton = uibutton(app.LeftPanel, 'push');
            app.ExportNIfTIButton.ButtonPushedFcn = createCallbackFcn(app, @ExportNIfTIButtonPushed, true);
            app.ExportNIfTIButton.WordWrap = 'on';
            app.ExportNIfTIButton.FontSize = 30;
            app.ExportNIfTIButton.FontWeight = 'bold';
            app.ExportNIfTIButton.Position = [291 39 107 82];
            app.ExportNIfTIButton.Text = {'Export '; 'NIfTI'};

            % Create LoadBIDSButton
            app.LoadBIDSButton = uibutton(app.LeftPanel, 'push');
            app.LoadBIDSButton.ButtonPushedFcn = createCallbackFcn(app, @LoadBIDSButtonPushed, true);
            app.LoadBIDSButton.FontSize = 30;
            app.LoadBIDSButton.FontWeight = 'bold';
            app.LoadBIDSButton.FontAngle = 'italic';
            app.LoadBIDSButton.Position = [55 39 94 82];
            app.LoadBIDSButton.Text = {'Load'; 'BIDS'};

            % Create OverlayAlpha
            app.OverlayAlpha = uislider(app.LeftPanel);
            app.OverlayAlpha.Limits = [0 1];
            app.OverlayAlpha.MajorTicks = [];
            app.OverlayAlpha.ValueChangedFcn = createCallbackFcn(app, @OverlayAlphaValueChanged, true);
            app.OverlayAlpha.ValueChangingFcn = createCallbackFcn(app, @OverlayAlphaValueChanging, true);
            app.OverlayAlpha.MinorTicks = [0 0.035 0.07 0.105 0.14 0.175 0.21 0.245 0.28 0.315 0.35 0.385 0.42 0.455 0.49 0.525 0.56 0.595 0.63 0.665 0.7 0.735 0.77 0.805 0.84 0.875 0.91 0.945 1];
            app.OverlayAlpha.Tooltip = {'Adjust lesion mask transparency'};
            app.OverlayAlpha.Position = [718 148 265 3];
            app.OverlayAlpha.Value = 1;

            % Create LesionIndexSpinner
            app.LesionIndexSpinner = uispinner(app.LeftPanel);
            app.LesionIndexSpinner.ValueChangedFcn = createCallbackFcn(app, @LesionIndexSpinnerValueChanged, true);
            app.LesionIndexSpinner.FontSize = 20;
            app.LesionIndexSpinner.FontWeight = 'bold';
            app.LesionIndexSpinner.FontAngle = 'italic';
            app.LesionIndexSpinner.Tooltip = {'(left/right arrow) Select lesion index'};
            app.LesionIndexSpinner.Position = [841 849 92 42];

            % Create goToLastLes
            app.goToLastLes = uibutton(app.LeftPanel, 'push');
            app.goToLastLes.ButtonPushedFcn = createCallbackFcn(app, @goToLastLesButtonPushed, true);
            app.goToLastLes.IconAlignment = 'center';
            app.goToLastLes.BackgroundColor = [0.8 0.8 0.8];
            app.goToLastLes.FontSize = 18;
            app.goToLastLes.FontWeight = 'bold';
            app.goToLastLes.Position = [932 849 39 42];
            app.goToLastLes.Text = '>';

            % Create goToFirstLes
            app.goToFirstLes = uibutton(app.LeftPanel, 'push');
            app.goToFirstLes.ButtonPushedFcn = createCallbackFcn(app, @goToFirstLesButtonPushed, true);
            app.goToFirstLes.BackgroundColor = [0.8 0.8 0.8];
            app.goToFirstLes.FontSize = 18;
            app.goToFirstLes.FontWeight = 'bold';
            app.goToFirstLes.Position = [801 849 39 42];
            app.goToFirstLes.Text = '<';

            % Create SliderLabel
            app.SliderLabel = uilabel(app.LeftPanel);
            app.SliderLabel.HorizontalAlignment = 'right';
            app.SliderLabel.Position = [13 140 36 22];
            app.SliderLabel.Text = 'Slider';

            % Create Slider
            app.Slider = uislider(app.LeftPanel, 'range');
            app.Slider.ValueChangedFcn = createCallbackFcn(app, @SliderValueChanged, true);
            app.Slider.ValueChangingFcn = createCallbackFcn(app, @SliderValueChanging, true);
            app.Slider.Tooltip = {'Change the color map limit for FLAIR*'};
            app.Slider.Position = [71 149 427 3];

            % Create LesionReviewButtonGroup
            app.LesionReviewButtonGroup = uibuttongroup(app.LeftPanel);
            app.LesionReviewButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @LesionReviewButtonGroupSelectionChanged, true);
            app.LesionReviewButtonGroup.BackgroundColor = [0 0 0];
            app.LesionReviewButtonGroup.Position = [423 39 281 84];

            % Create KeepButton
            app.KeepButton = uitogglebutton(app.LesionReviewButtonGroup);
            app.KeepButton.Tooltip = {'(s) This lesion has CVS'};
            app.KeepButton.Text = 'Keep';
            app.KeepButton.FontSize = 25;
            app.KeepButton.FontWeight = 'bold';
            app.KeepButton.Position = [9 20 77 40];
            app.KeepButton.Value = true;

            % Create DraftButton
            app.DraftButton = uitogglebutton(app.LesionReviewButtonGroup);
            app.DraftButton.Tooltip = {'(e) This lesion might have CVS'};
            app.DraftButton.Text = 'Draft';
            app.DraftButton.FontSize = 25;
            app.DraftButton.FontWeight = 'bold';
            app.DraftButton.Position = [96 20 75 40];

            % Create DeleteButton
            app.DeleteButton = uitogglebutton(app.LesionReviewButtonGroup);
            app.DeleteButton.Tooltip = {'(d) This lesion does not have CVS'};
            app.DeleteButton.Text = 'Delete';
            app.DeleteButton.FontSize = 25;
            app.DeleteButton.FontWeight = 'bold';
            app.DeleteButton.Position = [181 20 92 40];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = CvsView_exported

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