        function app = ExportButtonPushed(app)
            app = updateLesionSize(app);
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

            % app = setupFigure(app);
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
            %% Add title text at the top of the page
            % Use normalized units for positioning
            annotation(app.fig,'rectangle',[0, 0.95, 1, 0.1],'FaceColor',[0.5 0.5 0.5],'FaceAlpha',.2,'EdgeColor', 'none');

            annotation(app.fig, 'textbox', [0, 0.925, 1, 0.1], 'String', ['Lesion report of ' app.subject], ...
                'FontSize', 28, 'FontWeight','bold','VerticalAlignment', 'middle','HorizontalAlignment', 'center','EdgeColor', 'none', 'Interpreter', 'none');

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


            %% Prepare the info text
            infoTextLines = {
                sprintf('Baseline - %.3f ml lesions', round(sum(app.sizeChange(:,1)), 3)) ,
                sprintf('Followup - %.3f ml lesions', round(sum(app.sizeChange(:,2)),3))
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
            app = checkWhichIndexList(app);
            app.currentIndex = app.largestLesion(1); 
            app.LesionIndexSpinner.Value = app.currentIndex;

            app = drawReport(app,whereReport);

            disp(['Exporting ' pdfFilename1 ' ...'])
            print(app.fig, pdfFilename1, '-dpdf', '-r300');
            close(app.fig);
            disp('Page 1 done!')

            %% fill the 2nd+ pages with new lesions
            % This is budget workaround, not the best practice, please find
            % another way
            
            % Export only the new lesions that have passed the review

            if isempty(app.newLesionIndexExport)

                disp(['No new lesions found ...'])
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


                    % Add title text at the top of the page
                    annotation(app.fig,'rectangle',[0, 0.95, 1, 0.1],'FaceColor',[0.5 0.5 0.5],'FaceAlpha',.2,'EdgeColor', 'none');

                    annotation(app.fig, 'textbox', [0, 0.925, 1, 0.1], 'String', ['Possible New Lesions'], ...
                        'FontSize', 28, 'FontWeight','bold','VerticalAlignment', 'middle','HorizontalAlignment', 'left','EdgeColor', 'none', 'Interpreter', 'none');


                    for ii = 1:numLes % loop through the lesions to draw on the current page
                        app.currentIndex = app.newLesionIndexExport(whichLesion);

                        if ~rem(whichLesion,2) % even index, draw at bottom of page
                            app = drawReport(app,2);
                        else % odd index, draw at top of page
                            app = drawReport(app,1);
                        end
                        whichLesion = whichLesion + 1; % goes to next lesion
                    end

                    disp(['Exporting ' pdfFilename1 ' ...'])
                    print(app.fig, pdfFilename1, '-dpdf', '-r300');
                    close(app.fig);
                    disp(['Page ' num2str(whichPage) ' done!'])

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
                disp('PDF files were merged successfully.');
            else
                disp(['An error occurred: ', cmdout]);
            end

            app.PleasewaitLabel.Visible = 'off';

        end
