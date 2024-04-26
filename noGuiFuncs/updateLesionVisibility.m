        function app = updateLesionVisibility(app)

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
                                    app = updatePatchColor(app, lesionPatch, currentState); % Update color based on state
                                else
                                    lesionPatch.FaceAlpha = 0; % Make lesion invisible
                                end
                            else
                                % For "One" state, only the selected lesion is fully visible
                                lesionPatch.FaceAlpha = double(patchInfo{3} == app.currentIndex);
                                if patchInfo{3} == app.currentIndex
                                    % Use review state to color the selected lesion
                                    currentState = app.LesionReviewStates(patchInfo{3}, app.currentImageIndex);
                                    app = updatePatchColor(app, lesionPatch, currentState);
                                end
                            end
                        else
                            lesionPatch.FaceAlpha = 0; % Make lesions from other time points invisible
                        end
                    end
                end
            end

        end
