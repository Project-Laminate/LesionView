        function app = toggleT2Image(app)

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

            app = updateImage(app); % Refresh the T2 flair image display

        end