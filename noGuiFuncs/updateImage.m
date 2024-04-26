function app = updateImage(app)
% Create an invisible figure
app.fig1 = figure('Visible', 'off');
app.UIAxes = axes('Parent', app.fig1);
%app.UIAxes.Position = [20 162 967 622];
if app.currentImageIndex == 1 % if current time is baseline
    app.whichT2 = app.FlairTP1; % switch to followup T2 flair
else % if current time is followup
    app.whichT2 = app.FlairTP2; % switch to followup T2 flair
end

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

            text(app.UIAxes, 0.95, 0.05, timePointText, 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', 'white', 'FontSize', 15, 'FontWeight', 'bold');
            text(app.UIAxes, 0.82, 0.05, 'L', 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', [0.5 0.5 0.5], 'FontSize', 15, 'FontWeight', 'bold','FontAngle','italic');
            text(app.UIAxes, 0.62, 0.18, 'L', 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Color', [0.5 0.5 0.5], 'FontSize', 15, 'FontWeight', 'bold','FontAngle','italic');

            hold(app.UIAxes, 'off'); % Release the hold to prevent further overlays on top











end
