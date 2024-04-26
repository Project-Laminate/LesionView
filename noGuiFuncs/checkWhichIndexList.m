        function app = checkWhichIndexList(app)

            % based on new and disappearing lesion check boxes

            if app.NewLesionCheckBox.Value&&app.DisappearingCheckBox.Value %both new and disappearing
                app.whichIndex = unique([app.goneLesionIndex; app.newLesionIndex]);
            elseif ~app.NewLesionCheckBox.Value&&app.DisappearingCheckBox.Value % only disappearing
                app.whichIndex = app.goneLesionIndex;
            elseif ~app.DisappearingCheckBox.Value&&app.NewLesionCheckBox.Value % only new
                app.whichIndex = app.newLesionIndex;
            else
                app.whichIndex = app.lesionIndex;
            end

            app.LesionIndexSpinner.Limits = [1, numel(app.whichIndex)];
        end