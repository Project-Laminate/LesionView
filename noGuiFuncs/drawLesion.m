        function app = drawLesion(app, idx, x, y, z)
            % Draw lesion for L1

            if any(app.L1(:) ==  app.lesionIndex(idx))
                drawMat = app.L1 ==  app.lesionIndex(idx);
                if nnz(drawMat) > 0 % Check if non-empty
                    [f, v] = isosurface(x, y, z, drawMat, 0.8);
                    lesionPatch = patch(app.LesionVisualizationAxes, 'Faces', f, 'Vertices', v, 'FaceColor', app.blueColor, 'FaceAlpha', 1, 'EdgeColor', 'none'); % Initially invisible
                    app.lesionPatches{app.lesionIndex(idx)} = {lesionPatch, 1, idx}; % Time point 1
                end
            end

            % Repeat for L2 with appropriate checks and adjustments
            if any(app.L2(:) ==  app.lesionIndex(idx))
                drawMat = app.L2 ==  app.lesionIndex(idx);
                if nnz(drawMat) > 0
                    [f, v] = isosurface(x, y, z, drawMat, 0.8);
                    lesionPatch = patch(app.LesionVisualizationAxes, 'Faces', f, 'Vertices', v, 'FaceColor', 'green', 'FaceAlpha', 1, 'EdgeColor', 'none'); % Initially invisible
                    app.lesionPatches{numel(app.lesionIndex)+app.lesionIndex(idx)} = {lesionPatch, 2, idx}; % Time point 2
                end
            end
        end