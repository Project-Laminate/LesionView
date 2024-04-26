        function app = updateNewGoneLesionIndex(app)

            app.NewLesionCheckBox.Value = 0;
            app.DisappearingCheckBox.Value = 0;

            % Identify new lesions in time point 2 that were not present in time point 1
            % we don't delete from app.L1.
            tmp1 = app.L1;
            tmp1(ismember(tmp1,app.lesionIndex(app.LesionReviewStates(:,1)=="delete"))) = 0;
            tmp2 = app.L2;
            tmp2(ismember(tmp2,app.lesionIndex(app.LesionReviewStates(:,2)=="delete"))) = 0;

            lesionList1 = unique(tmp1);
            lesionList2 = unique(tmp2);
            app.newLesionIndex = lesionList2(~ismember(unique(tmp2), unique(tmp1)));
            app.goneLesionIndex = lesionList1(~ismember(unique(tmp1), unique(tmp2)));

        end