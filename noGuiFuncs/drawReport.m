        function app = drawReport(app,whereReport)

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
                        if k == 2
                            % First image positioning

                            targetPosition = [gapWidth   1-gapHeight-imageHeight-(ii-1)*imageHeight/1.4-0.1   imageWidth   imageHeight];

                        else
                            % Second image positioning
                            targetPosition = [gapWidth * 2 + imageWidth   1-gapHeight-imageHeight-(ii-1)*imageHeight/1.4-0.1   imageWidth   imageHeight];
                        end
                    else % bottom half
                        if k == 2
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
                        if k == 2 % if baseline
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
