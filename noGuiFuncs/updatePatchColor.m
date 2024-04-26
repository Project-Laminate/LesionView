        function app = updatePatchColor(app,lesionPatch, currentState)
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