classdef CvsView_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        LeftPanel                   matlab.ui.container.Panel
        ButtonGroup                 matlab.ui.container.ButtonGroup
        Phase                       matlab.ui.control.ToggleButton
        FLAIRButton                 matlab.ui.control.ToggleButton
        SWIButton                   matlab.ui.control.ToggleButton
        FlairStarButton             matlab.ui.control.ToggleButton
        HowlikelyisthereaveinLabel  matlab.ui.control.Label
        AdjustcontrastLabel         matlab.ui.control.Label
        Slider                      matlab.ui.control.RangeSlider
        CheckBox                    matlab.ui.control.CheckBox
        likelihoodSlider            matlab.ui.control.Slider
        goToFirstLes                matlab.ui.control.Button
        goToLastLes                 matlab.ui.control.Button
        LesionIndexSpinner          matlab.ui.control.Spinner
        LoadBIDSButton              matlab.ui.control.Button
        ExportNIfTIButton           matlab.ui.control.Button
        ProgressTextArea            matlab.ui.control.TextArea
        y0                          matlab.ui.control.Spinner
        z0                          matlab.ui.control.Spinner
        x0                          matlab.ui.control.Spinner
        ExportPNGButton             matlab.ui.control.Button
        UIAxes                      matlab.ui.control.UIAxes
    end


    properties (Access = private)

        % General properties
        subject = 'sub - xxx'; % e.g. sub-001 - Identifier for the subject
        bidsDir
        lesionDerivDir
        FlairInfo % metadata - Information about the T2 flair images (used for saving or processing)
        fileStatus = [false,false,false,false,false]; % whether each files are loaded
        allowKey = 0;
        

        % Image data properties
        FlairStar % 3D matrix -  flairstar image at time point 1
        flair
        swi
        phase
        Lesion1 % 3D matrix - Lesion image at time point 1
        cvsNiftiName
        backupLesion1
        OverlayAlpha = 1;

        % Image analyses properties
        L1 % 3D matrix - Processed lesion image with lables at time point 1 for analysis
        L1backUp % 3D matrix - backup of L1
        L1raw
        whichT2 % 3D matrix - The variable to hold the currently selected 3D T2 image data
        whichLes % 3D matrix - The variable to hold the currently selected lesion data
        lesionCenter = [1 1 1]; % numLes by 3 - [x, y, z] - Center coordinates of lesions, used for visualization adjustments

        % Indexing
        currentIndex = 1 % scaler - Index of the currently selected lesion for processing
        currentImageIndex = 1 % 1 or 2 - Indicates the current image being displayed (1 for FlairStar, 2 for FlairTP2)
        lesionIndex % numLes by 1 - Array of unique indices for each lesion
        whichIndex % which index list are currently being use, i.e, are we viewing all lesions or only new lesion etc
        largestLesion = 1
        lesionVol


        % Visualization and UI elements
        sizeZoom double = 52; % Zoom window size for detailed lesion viewing
        
        % Store [limitMin, limitMax, valMin, valMax] for each modality
        % 1=FlairStar, 2=SWI, 3=FLAIR, 4=Phase
        imgSettings = zeros(4,4); 
        currModality = 1;

        hLes % Placeholder for lesion visualization handles
        fig % Main figure for export
        progressBarLength
        blueColor = [0,120,255]./255;

        hLes_other 
        hLes_selected 


        % Lesion processing and review properties
        cvsMat % 3D matrix - Cleaned lesion image at time point 1
        cvsP % numLes by 1 - Stores the p for each lesion
        sizeChange

        newLesionMask % % 3D matrix - Cleaned lesion image at time point 2 (color coded 1 2 3)
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
            imshow(img, 'DisplayRange',[app.Slider.Value(1) app.Slider.Value(2)], 'Parent', app.UIAxes); % adjust color range when Flair is loaded
            hold(app.UIAxes, 'on'); % Keep the original image, allowing overlays to be added

            % --- Prepare Lesion Overlays ---

            % Retrieve and preprocess the lesion mask
            if ~isempty(app.L1)
                currentLesionMask = flip(app.L1, 2);
                currentLesionMask = flip(currentLesionMask, 3);
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
            % Use the 2D slices (les_selected21/22/23) as source, not the 3D volume
            img11_selected = imresize(les_selected21(max(1, app.z0.Value - app.sizeZoom):min(end, app.z0.Value + app.sizeZoom), ...
                max(1, app.y0.Value - app.sizeZoom):min(end, app.y0.Value + app.sizeZoom)), ...
                [size(botrow,1) size(botrow,1)], 'nearest');
            img12_selected = imresize(les_selected22(max(1, app.z0.Value - app.sizeZoom):min(end, app.z0.Value + app.sizeZoom), ...
                max(1, app.x0.Value - app.sizeZoom):min(end, app.x0.Value + app.sizeZoom)), ...
                [size(botrow,1) size(botrow,1)], 'nearest');
            img13_selected = imresize(les_selected23(max(1, app.x0.Value - app.sizeZoom):min(end, app.x0.Value + app.sizeZoom), ...
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
            % Use the 2D slices (les_other21/22/23) as source, not the 3D volume
            img11_other = imresize(les_other21(max(1, app.z0.Value - app.sizeZoom):min(end, app.z0.Value + app.sizeZoom), ...
                max(1, app.y0.Value - app.sizeZoom):min(end, app.y0.Value + app.sizeZoom)), ...
                [size(botrow,1) size(botrow,1)], 'nearest');
            img12_other = imresize(les_other22(max(1, app.z0.Value - app.sizeZoom):min(end, app.z0.Value + app.sizeZoom), ...
                max(1, app.x0.Value - app.sizeZoom):min(end, app.x0.Value + app.sizeZoom)), ...
                [size(botrow,1) size(botrow,1)], 'nearest');
            img13_other = imresize(les_other23(max(1, app.x0.Value - app.sizeZoom):min(end, app.x0.Value + app.sizeZoom), ...
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
            % img_selected = imdilate(bwperim(img_selected, 8), strel('disk', 1)); % Thinner line

            % Other Lesions Overlay
            img_other = [toples_other; botles_other];
            img_other = double(img_other > 0.5);
            img_other = bwperim(img_other, 8);
            % img_other = imdilate(bwperim(img_other, 8), strel('disk', 1)); % Thinner line

            % --- Create Colored Overlays ---

            % Color for other lesions (blue)
            tmpImg_other = double(img_other) .* reshape(app.blueColor, [1, 1, 3]);

            % Color for selected lesion (green)
            greenColor = [0, 1, 0]; % Define green color
            tmpImg_selected = double(img_selected) .* reshape(greenColor, [1, 1, 3]);

            % --- Display the Overlays ---

            % Display other lesions in blue
            app.hLes_other = imshow(tmpImg_other, 'Parent', app.UIAxes);
            set(app.hLes_other, 'AlphaData', double(img_other) * app.OverlayAlpha);

            % Display selected lesion in green
            app.hLes_selected = imshow(tmpImg_selected, 'Parent', app.UIAxes);
            set(app.hLes_selected, 'AlphaData', double(img_selected) * app.OverlayAlpha); % Ensure you have a SelectedOverlayAlpha property

            % --- Draw Zoom Rectangles (Optional) ---
            
            if app.CheckBox.Value
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

            app.L1 = uint32(bwlabeln(app.Lesion1 > 0.8, 26));
            N = double(max(app.L1(:))); if isempty(N) || N==0, N = 1; end

            % --- Map VIEW labels directly to RAW grid (no intersection with RAW mask) ---
            Lview2raw = imresize3(double(app.L1), size(app.backupLesion1), 'nearest');

            % expose mapped labels if needed elsewhere
            app.L1raw = uint32(Lview2raw);

            % --- RAW-space voxel counts per VIEW-ID (do not gate by Lraw0) ---
            vi  = double(Lview2raw(:));
            vi  = vi(vi>=1 & vi<=N);
            cnt = accumarray(vi, 1, [N, 1]);

            % ---- Optional size filtering (in RAW voxels) ----
            minVox = 75;
            if isprop(app,'minLesionVox') && ~isempty(app.minLesionVox), minVox = double(app.minLesionVox); end
            if minVox>0
                kill = find(cnt < minVox);
                if ~isempty(kill)
                    app.L1(ismember(app.L1, kill))       = 0;
                    app.L1raw(ismember(app.L1raw, kill)) = 0;
                    % recompute counts after pruning
                    N   = double(max(app.L1,[],'all'));
                    cnt = accumarray(double(app.L1raw(app.L1raw>0)),1,[max(N,1),1]); cnt = cnt(1:N);
                end
            end

            % ---- Sort so label 1 is LARGEST (by RAW volume) and relabel both maps ----
            labels = find(cnt>0);
            [~,ord] = sort(cnt(labels),'descend'); ranked = labels(ord);
            lut = zeros(max([labels;1]),1,'uint32');
            if ~isempty(ranked), lut(ranked) = uint32(1:numel(ranked)); end

            % ---- SAFE relabel: extend LUT to cover any label IDs in either map ----
            K  = max([1 double(max(app.L1(:))) double(max(app.L1raw(:)))]);
            if numel(lut) < K, lut(end+1:K,1) = uint32(0); end                      % grow LUT
            bad = setdiff(1:K, double(labels));                                     % IDs not in cnt>0
            if ~isempty(bad), lut(bad) = uint32(0); end                              % map orphans to 0

            fg = app.L1>0;    app.L1(fg)    = lut(double(app.L1(fg)));
            fg = app.L1raw>0; app.L1raw(fg) = lut(double(app.L1raw(fg)));

            % ---- Store volumes to match new IDs (index = new ID) ----
            app.lesionVol = cnt(ranked);

            updateProgress(app,'Calculating lesion centers ...')

            % Calculate the center of each lesion for visualization
            app.lesionIndex = nonzeros(unique(app.L1)); % Combined list of unique lesion indices
            app.lesionCenter = zeros(numel(app.lesionIndex), 3);
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

            % Set the limits and enable the lesion index spinner based on available lesions
         
            app.LesionIndexSpinner.Limits = [1, size(app.lesionCenter, 1)];
            app.LesionIndexSpinner.Enable = 'on';

            % Prepare clean and draft lesion matrices and backup
            app.L1backUp = app.L1;


            % Display summary information about lesions in TextArea
            app.currentIndex = 1;

            app.x0.Value = app.lesionCenter(app.currentIndex,1);
            app.y0.Value = app.lesionCenter(app.currentIndex,2);
            app.z0.Value = app.lesionCenter(app.currentIndex,3);

            app.goToLastLes.Text = num2str(app.LesionIndexSpinner.Limits(2));
            app.goToFirstLes.Text = num2str(app.LesionIndexSpinner.Limits(1));

            updateProgress(app,['check for previous files ...'])

            cacheFile = fullfile(app.bidsDir,'derivatives','CvsView',app.subject,'cache.mat');
            if isfile(cacheFile)
                choice = uiconfirm(app.UIFigure,'A cache file was found. Load it or start new?','Load Cache?', ...
                    'Options',{'Load Cache','Start New'},'DefaultOption',1,'CancelOption',2);
                if strcmp(choice,'Load Cache')
                    S = load(cacheFile,'cvsP'); app.cvsP = S.cvsP(:);
                    % align length to current lesion count
                    n = numel(app.lesionIndex);
                    if numel(app.cvsP)~=n, app.cvsP = [app.cvsP; zeros(max(0,n-numel(app.cvsP)),1)]; app.cvsP = app.cvsP(1:n); end
                    updateProgress(app,sprintf('Loaded cache.mat (%d entries).',numel(app.cvsP)));

                    app.likelihoodSlider.Value = app.cvsP(app.currentIndex);
                else
                    app.cvsP = zeros(numel(app.lesionIndex),1);
                    updateProgress(app,'Started new session (cvsP zeroed).');
                end
            else
                app.cvsP = zeros(numel(app.lesionIndex),1);
                updateProgress(app,'No cache found; initialized cvsP to zeros.');
            end



             updateProgress(app,'Finished analyzing lesions')
             updateProgress(app,'Ready')

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

                if app.fileStatus(3)
                    app.SWIButton.Enable = 'on';
                end
                if app.fileStatus(4)
                    app.Phase.Enable = 'on';
                end                
                if app.fileStatus(5)
                    app.FLAIRButton.Enable = 'on';
                end
  
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
        FlairStarFile = dir(fullfile(app.bidsDir,'derivatives',LamDir,app.subject, '*FLAIRSTAR.nii.gz'));

        if ~isempty(FlairStarFile)
            updateProgress(app,['Loading FlairStar from : ', fullfile(FlairStarFile.folder, FlairStarFile.name)]);
            FlairPath = fullfile(FlairStarFile.folder, FlairStarFile.name);
            app.FlairStar = niftiread(FlairPath);
            app.FlairInfo = niftiinfo(FlairPath);
            app.FlairStar = flip(app.FlairStar,2); % Adjust orientation as needed
            app.FlairStar = flip(app.FlairStar,3);
            app.fileStatus(1) = true;
            % Slider initialization is now handled after all images are processed
            
        else
            updateProgress(app,['*** No FlairStar found ***'])
        end
                 
        swiFile = dir(fullfile(app.bidsDir,'rawdata',app.subject,'ses-01','swi', '*ses-01_swi.nii.gz'));

        if ~isempty(swiFile)
            updateProgress(app,['Loading SWI from : ', fullfile(swiFile.folder, swiFile.name)]);
            swiPath = fullfile(swiFile.folder, swiFile.name);
            app.swi = niftiread(swiPath);
            app.swi = flip(app.swi,2); % Adjust orientation as needed
            app.swi = flip(app.swi,3);
            app.fileStatus(3) = true;
        else
            updateProgress(app,['*** No SWI found ***'])
        end

        phaseFile = dir(fullfile(app.bidsDir,'rawdata',app.subject,'ses-01','swi', '*phase*.nii.gz'));

        if ~isempty(phaseFile)
            updateProgress(app,['Loading phase image from : ', fullfile(phaseFile.folder, phaseFile.name)]);
            phasePath = fullfile(phaseFile.folder, phaseFile.name);
            app.phase = niftiread(phasePath);
            app.phase = flip(app.phase,2); % Adjust orientation as needed
            app.phase = flip(app.phase,3);
            app.fileStatus(4) = true;
            
        else
            updateProgress(app,['*** No phase found ***'])
        end

        flairFile = dir(fullfile(app.bidsDir,'derivatives',LamDir,app.subject, '*FLAIR.nii.gz'));

        if ~isempty(flairFile)
            updateProgress(app,['Loading phase image from : ', fullfile(flairFile.folder, flairFile.name)]);
            flairPath = fullfile(flairFile.folder, flairFile.name);
            app.flair = niftiread(flairPath);
            app.flair = flip(app.flair,2); % Adjust orientation as needed
            app.flair = flip(app.flair,3);
            app.fileStatus(5) = true;

            
        else
            updateProgress(app,['*** No flair found ***'])
        end


        %% Load Lesion Mask
        lesion1File = dir(fullfile(app.bidsDir,'derivatives',LamDir,app.subject, '*lesion_mask.nii.gz'));

        if ~isempty(lesion1File)
            updateProgress(app,['Loading Lesion mask from : ', fullfile(lesion1File(1).folder, lesion1File(1).name)]);
            LesionPath = fullfile(lesion1File(1).folder, lesion1File(1).name);
            app.Lesion1 = niftiread(LesionPath);
            app.backupLesion1 = app.Lesion1;
            % app.FlairInfo = niftiinfo(fullfile(lesion1File(1).folder, lesion1File(1).name));
            app.fileStatus(2) = true;
            % New file names for saving the cleaned-up version of lesions
            app.cvsNiftiName = fullfile(app.bidsDir,'derivatives','CvsView',app.subject, strrep(lesion1File(1).name,'lesion_mask.nii.gz','cvs_mask.nii.gz'));
        else
            updateProgress(app,['*** No lesion mask found ***'])
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
            newSizeFlair = round(size(app.FlairStar) .* scaleFactors);
            newSizeLesion = round(size(app.Lesion1) .* scaleFactors);

            % Resample images
            app.FlairStar = imresize3(app.FlairStar, newSizeFlair, 'linear');
            if app.fileStatus(3)
                app.swi = imresize3(app.swi, newSizeFlair, 'linear');
            end
            if app.fileStatus(4)
                app.phase = imresize3(app.phase, newSizeFlair, 'linear');
            end
            if app.fileStatus(5)
                app.flair = imresize3(app.flair, newSizeFlair, 'linear');
            end

            % Resample Lesion Mask using 'nearest' to preserve labels
            app.Lesion1 = imresize3(app.Lesion1, newSizeLesion, 'nearest');

            
            app.whichLes = app.Lesion1;



            %% Pad the Third Dimension 
            updateProgress(app,['preparing data ...'])
            desired_z_size = size(app.FlairStar,1);
            current_z_size = size(app.FlairStar, 3); % 

            if current_z_size < desired_z_size
                pad_total = desired_z_size - current_z_size; % 
                pad_before = floor(pad_total / 2); % 
                pad_after = ceil(pad_total / 2);  % 

                % Verify padding amounts
                if pad_before + current_z_size + pad_after ~= desired_z_size
                    error('Padding calculation error: total size mismatch.');
                end

                % Create padding arrays
                padding = zeros(size(app.whichLes,1), size(app.whichLes,2), pad_before);
                padding_after = zeros(size(app.FlairStar,1), size(app.FlairStar,2), pad_after);

                % Pad Image
                app.FlairStar = cat(3, padding, app.FlairStar, padding_after);
                if app.fileStatus(3)
                    app.swi = cat(3, padding, app.swi, padding_after);
                end
                if app.fileStatus(4)
                    app.phase = cat(3, padding, app.phase, padding_after);
                end
                if app.fileStatus(5)
                    app.flair = cat(3, padding, app.flair, padding_after);
                end                

                % Pad Lesion Mask
                app.whichLes = cat(3, padding, app.whichLes, padding_after);
                app.Lesion1 = app.whichLes;

                app.whichT2 = app.FlairStar;
                
                app.x0.Limits = [1 size(app.whichT2, 3)];
                app.y0.Limits = [1 size(app.whichT2, 2)];
                app.z0.Limits = [1 size(app.whichT2, 1)];

                app.x0.Value = round(size(app.whichT2, 3)/2);
                app.y0.Value = round(size(app.whichT2, 2)/2);
                app.z0.Value = round(size(app.whichT2, 1)/2);

                

                updateProgress(app,['done'])


            elseif current_z_size > desired_z_size
                error('Current z-dimension is larger than desired. Trimming not implemented.');
            end
        end

        %% Compute Image Stats (Limits & Default 5th-95th Percentile Range)
        updateProgress(app, 'Computing image stats...');
        imgs = {app.FlairStar, app.swi, app.flair, app.phase};
        % Check which are loaded
        loadedIndices = [1, 3, 5, 4]; % Indices in app.fileStatus matching the order above
        
        for k = 1:4
            if app.fileStatus(loadedIndices(k)) && ~isempty(imgs{k})
                % Compute Limits (Min/Max)
                d = double(imgs{k});
                app.imgSettings(k, 1) = min(d(:));
                app.imgSettings(k, 2) = max(d(:));
                
                % Compute Default Range (5th and 95th percentile)
                % Subsample for speed
                d_sub = d(1:20:end); 
                p = prctile(d_sub, [5 95]);
                app.imgSettings(k, 3) = p(1);
                app.imgSettings(k, 4) = p(2);
            end
        end

        %% Proceed with Existing Workflow
        app.currentImageIndex = 1;
        app.currModality = 1;
        % Initialize slider for FlairStar (Modality 1)
        if app.fileStatus(1)
             app.Slider.Limits = app.imgSettings(1, 1:2);
             app.Slider.Value  = app.imgSettings(1, 3:4);
        end
        
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
            updateImage(app);
            app.likelihoodSlider.Value = app.cvsP(app.currentIndex,1);

        end

        % Button pushed function: ExportNIfTIButton
        function ExportNIfTIButtonPushed(app, event)
            folder = fullfile(app.bidsDir,'derivatives','CvsView',app.subject);
            if ~isfolder(folder), mkdir(folder); end

            % quantize to 2 decimals and build volume
            cvsPq = min(1, max(0, round(app.cvsP(:), 2)));
            lut   = [0; cvsPq];
            app.cvsMat = single(lut(double(app.L1raw)+1));

            try
                updateProgress(app,'Exporting NIfTI ...');

                % write
                niftiwrite(app.cvsMat, app.cvsNiftiName, app.FlairInfo, 'Compressed', true);
                updateProgress(app,'NIfTI exported!');

                % also save cvsP cache
                cvsP = cvsPq; 
                save(fullfile(folder,'cache.mat'),'cvsP','-v7');
                updateProgress(app,'cache.mat exported!');

            catch ME
                rethrow(ME);
            end

        end

        % Button pushed function: ExportPNGButton
        function ExportPNGButtonPushed(app, event)

            % Define a subfolder to store exported images
            exportFolder = fullfile(app.bidsDir,'derivatives','CvsView',app.subject); if ~exist(exportFolder,'dir'), mkdir(exportFolder); end

            % select top-6 by probability
            [~,ord] = sort(app.cvsP(:),'descend'); lesions = ord(1:min(6,numel(app.cvsP)));

            % ----- text report -----
            P = 100*app.cvsP(:);
            totalVolML = sum(app.lesionVol)*prod(app.FlairInfo.PixelDimensions)/1000;
            edges = [0 20 40 60 80 100+eps]; counts = histcounts(P,edges);        % [0-20),[20-40),...,[80-100]
            fid = fopen(fullfile(exportFolder,[app.subject '.txt']),'w');
            fprintf(fid,'Subject: %s\nTotal lesions: %d\nTotal volume: %.2f ml\n',app.subject,numel(P),totalVolML);
            lows = [80 60 40 20 0]; highs = [100 80 60 40 20]; cc = fliplr(counts);
            for ii = 1:numel(lows), fprintf(fid,'%d-%d%%: %d lesions\n',lows(ii),highs(ii),cc(ii)); end
            fprintf(fid,'Exported PNGs (top-%d by probability): %s\n',numel(lesions),strjoin(compose('%d',lesions.'),', '));
            fclose(fid);

            % ----- PNG export -----
            if isempty(lesions), uialert(app.UIFigure,'No lesions to export.','Export'); return; end
            wb = waitbar(0,'Exporting...');
            for ii = 1:numel(lesions)
                idx = lesions(ii); app.LesionIndexSpinner.Value = idx; LesionIndexSpinnerValueChanged(app,[]); updateImage(app);
                fn = sprintf('%s_CVS_%d_%d%%.png',app.subject,idx,round(P(idx)));
                try exportgraphics(app.UIAxes,fullfile(exportFolder,fn),'Resolution',300); catch f=getframe(app.UIAxes); imwrite(f.cdata,fullfile(exportFolder,fn)); end
                waitbar(ii/numel(lesions),wb);
            end
            close(wb);
            uialert(app.UIFigure,sprintf('Exported %d lesions to %s.',numel(lesions),exportFolder),'Export Completed');

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

        % Value changed function: likelihoodSlider
        function likelihoodSliderValueChanged(app, event)

            val = app.likelihoodSlider.Value;
            val = max(0,min(1,val));                 % clamp to [0,1]
            app.cvsP(app.currentIndex,1) = val;

            pct = round(val*100);
            updateProgress(app, sprintf('Lesion #%d – %d%% chance of containing a vein', app.currentIndex, pct));

            yesCount = sum(app.cvsP >= 0.5);
            totalLesions = numel(app.cvsP);
            updateProgress(app, sprintf('%d out of %d lesions likely contain a vein', yesCount, totalLesions));

        end

        % Value changed function: CheckBox
        function CheckBoxValueChanged(app, event)
            app.OverlayAlpha = app.CheckBox.Value;
            updateImage(app);
        end

        % Value changed function: Slider
        function SliderValueChanged(app, event)
            % Save slider settings to current modality immediately
            if app.currModality > 0 && app.currModality <= 4
                app.imgSettings(app.currModality, 3:4) = app.Slider.Value;
            end
            updateImage(app); 
            
        end

        % Value changing function: Slider
        function SliderValueChanging(app, event)
            app.Slider.Value(1) = event.Value(1);
            app.Slider.Value(2) = event.Value(2);
            
            % Save slider settings to current modality immediately
            if app.currModality > 0 && app.currModality <= 4
                app.imgSettings(app.currModality, 3:4) = event.Value;
            end

            updateImage(app); 
        end

        % Selection changed function: ButtonGroup
        function ButtonGroupSelectionChanged(app, event)
            
            % Save current slider settings for the previous modality
            if app.currModality > 0
                app.imgSettings(app.currModality, 3:4) = app.Slider.Value;
            end

            newMod = 1;
            switch app.ButtonGroup.SelectedObject.Text
                case 'FlairStar'
                    app.whichT2 = app.FlairStar;
                    newMod = 1;
                case 'FLAIR'
                    app.whichT2 = app.flair;
                    newMod = 3;
                case 'SWI'
                    app.whichT2 = app.swi;
                    newMod = 2;
                case 'Phase'
                    app.whichT2 = app.phase;
                    newMod = 4;
            end
            
            app.currModality = newMod;
            
            % Restore settings for the new modality
            % Ensure limits are valid (min < max)
            lims = app.imgSettings(newMod, 1:2);
            vals = app.imgSettings(newMod, 3:4);
            
            if lims(2) > lims(1)
                app.Slider.Limits = lims;
                % Clamp values to limits
                vals(1) = max(lims(1), vals(1));
                vals(2) = min(lims(2), vals(2));
                app.Slider.Value = vals;
            end
            
            updateImage(app); 
        end

        % Button down function: ButtonGroup
        function ButtonGroupButtonDown(app, event)
            % Logic is handled in SelectionChanged
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
            title(app.UIAxes, 'PP')
            app.UIAxes.Toolbar.Visible = 'off';
            app.UIAxes.Position = [32 162 1005 668];

            % Create ExportPNGButton
            app.ExportPNGButton = uibutton(app.LeftPanel, 'push');
            app.ExportPNGButton.ButtonPushedFcn = createCallbackFcn(app, @ExportPNGButtonPushed, true);
            app.ExportPNGButton.FontSize = 30;
            app.ExportPNGButton.FontWeight = 'bold';
            app.ExportPNGButton.Tooltip = {'Generate PNG of CSV lesion'};
            app.ExportPNGButton.Position = [201 39 118 82];
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
            app.ProgressTextArea.Position = [667 38 370 78];

            % Create ExportNIfTIButton
            app.ExportNIfTIButton = uibutton(app.LeftPanel, 'push');
            app.ExportNIfTIButton.ButtonPushedFcn = createCallbackFcn(app, @ExportNIfTIButtonPushed, true);
            app.ExportNIfTIButton.WordWrap = 'on';
            app.ExportNIfTIButton.FontSize = 30;
            app.ExportNIfTIButton.FontWeight = 'bold';
            app.ExportNIfTIButton.Position = [331 39 107 82];
            app.ExportNIfTIButton.Text = {'Export '; 'NIfTI'};

            % Create LoadBIDSButton
            app.LoadBIDSButton = uibutton(app.LeftPanel, 'push');
            app.LoadBIDSButton.ButtonPushedFcn = createCallbackFcn(app, @LoadBIDSButtonPushed, true);
            app.LoadBIDSButton.FontSize = 30;
            app.LoadBIDSButton.FontWeight = 'bold';
            app.LoadBIDSButton.FontAngle = 'italic';
            app.LoadBIDSButton.Position = [95 39 94 82];
            app.LoadBIDSButton.Text = {'Load'; 'BIDS'};

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

            % Create likelihoodSlider
            app.likelihoodSlider = uislider(app.LeftPanel);
            app.likelihoodSlider.Limits = [0 1];
            app.likelihoodSlider.MajorTicks = [];
            app.likelihoodSlider.ValueChangedFcn = createCallbackFcn(app, @likelihoodSliderValueChanged, true);
            app.likelihoodSlider.MinorTicks = [0 0.0125 0.025 0.0375 0.05 0.0625 0.075 0.0875 0.1 0.1125 0.125 0.1375 0.15 0.1625 0.175 0.1875 0.2 0.2125 0.225 0.2375 0.25 0.2625 0.275 0.2875 0.3 0.3125 0.325 0.3375 0.35 0.3625 0.375 0.3875 0.4 0.4125 0.425 0.4375 0.45 0.4625 0.475 0.4875 0.5 0.5125 0.525 0.5375 0.55 0.5625 0.575 0.5875 0.6 0.6125 0.625 0.6375 0.65 0.6625 0.675 0.6875 0.7 0.7125 0.725 0.7375 0.75 0.7625 0.775 0.7875 0.8 0.8125 0.825 0.8375 0.85 0.8625 0.875 0.8875 0.9 0.9125 0.925 0.9375 0.95 0.9625 0.975 0.9875 1];
            app.likelihoodSlider.FontSize = 8;
            app.likelihoodSlider.Position = [689 147 335 3];

            % Create CheckBox
            app.CheckBox = uicheckbox(app.LeftPanel);
            app.CheckBox.ValueChangedFcn = createCallbackFcn(app, @CheckBoxValueChanged, true);
            app.CheckBox.Text = '';
            app.CheckBox.Position = [983 855 30 22];
            app.CheckBox.Value = true;

            % Create Slider
            app.Slider = uislider(app.LeftPanel, 'range');
            app.Slider.MajorTicks = [];
            app.Slider.ValueChangedFcn = createCallbackFcn(app, @SliderValueChanged, true);
            app.Slider.ValueChangingFcn = createCallbackFcn(app, @SliderValueChanging, true);
            app.Slider.MinorTicks = [0 2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48 50 52 54 56 58 60 62 64 66 68 70 72 74 76 78 80 82 84 86 88 90 92 94 96 98 100];
            app.Slider.Tooltip = {'Change the color map limit for FLAIR*'};
            app.Slider.Position = [104 146 325 3];

            % Create AdjustcontrastLabel
            app.AdjustcontrastLabel = uilabel(app.LeftPanel);
            app.AdjustcontrastLabel.FontAngle = 'italic';
            app.AdjustcontrastLabel.FontColor = [1 1 1];
            app.AdjustcontrastLabel.Position = [210 127 86 22];
            app.AdjustcontrastLabel.Text = 'Adjust contrast';

            % Create HowlikelyisthereaveinLabel
            app.HowlikelyisthereaveinLabel = uilabel(app.LeftPanel);
            app.HowlikelyisthereaveinLabel.FontSize = 18;
            app.HowlikelyisthereaveinLabel.FontAngle = 'italic';
            app.HowlikelyisthereaveinLabel.FontColor = [1 1 1];
            app.HowlikelyisthereaveinLabel.Position = [760 123 212 24];
            app.HowlikelyisthereaveinLabel.Text = 'How likely is there a vein?';

            % Create ButtonGroup
            app.ButtonGroup = uibuttongroup(app.LeftPanel);
            app.ButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @ButtonGroupSelectionChanged, true);
            app.ButtonGroup.BackgroundColor = [0 0 0];
            app.ButtonGroup.ButtonDownFcn = createCallbackFcn(app, @ButtonGroupButtonDown, true);
            app.ButtonGroup.Position = [496 42 128 98];

            % Create FlairStarButton
            app.FlairStarButton = uitogglebutton(app.ButtonGroup);
            app.FlairStarButton.Text = 'FlairStar';
            app.FlairStarButton.Position = [14 69 100 23];
            app.FlairStarButton.Value = true;

            % Create SWIButton
            app.SWIButton = uitogglebutton(app.ButtonGroup);
            app.SWIButton.Enable = 'off';
            app.SWIButton.Text = 'SWI';
            app.SWIButton.Position = [14 48 100 23];

            % Create FLAIRButton
            app.FLAIRButton = uitogglebutton(app.ButtonGroup);
            app.FLAIRButton.Enable = 'off';
            app.FLAIRButton.Text = 'FLAIR';
            app.FLAIRButton.Position = [14 27 100 23];

            % Create Phase
            app.Phase = uitogglebutton(app.ButtonGroup);
            app.Phase.Enable = 'off';
            app.Phase.Text = 'Phase';
            app.Phase.Position = [14 5 100 23];

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