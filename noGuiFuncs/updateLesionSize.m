
        function app = updateLesionSize(app)

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

            % Display summary information about lesions in TextArea
            infoText = sprintf('Time 1 - %d lesions (%d ml)\nTime 2 - %d lesions (%d ml)', ...
                sum(app.LesionReviewStates(:,1)~="delete"), round(sum(app.sizeChange(:,1))), ...
                sum(app.LesionReviewStates(:,2)~="delete"), round(sum(app.sizeChange(:,2))));
            app.TextArea.Value = infoText;

            [~, whoBig] = max(max(app.sizeChange(:,1:2)'));
            app.largestLesion = exportIndex(whoBig);

        end