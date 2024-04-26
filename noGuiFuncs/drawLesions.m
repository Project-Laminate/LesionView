function  app = drawLesions(app)

[x, y, z] = meshgrid(1:size(app.L1,2), 1:size(app.L1,1), 1:size(app.L1,3));
app.lesionPatches = cell(numel(app.lesionIndex)*2,1);

for idx1 = 1:numel(app.lesionIndex)
    disp(['Drawing lesion # ' num2str(idx1) ' ...'])

    % Draw lesion for L1
    app = drawLesion(app, app.lesionIndex(idx1), x, y, z);

end
disp('Done!')
end

