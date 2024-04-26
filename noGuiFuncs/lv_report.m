function lv_report(subject,app)

    
% this function finds the flair and its lesion mask at two time points and
% generate a report 

    % Define default options if not provided
    if nargin < 2 || isempty(app)
        app = struct;
    end

    app.subject = subject;
    app.sizeZoom = 26;

    % Set default values for each expected field in opt
    defaultOptions = getDefaultOptions();
    fields = fieldnames(defaultOptions);
    for i = 1:length(fields)
        field = fields{i};
        if ~isfield(app, field) || isempty(app.(field))
            app.(field) = defaultOptions.(field);
        end
    end

    % load files
    app = load_bids(app);

    % analyze lesions
    app = analyzeLesions(app);

    % populate fig1
    app.currentImageIndex = 1;
    app = updateImage(app);
    app = checkWhichIndexList(app);


    app.fig2 = figure('Visible', 'on');
    app.LesionVisualizationAxes = axes('Parent', app.fig2);
    if ~isempty(app.brainMask)
        [x, y, z] = meshgrid(1:size(app.brainMask,2), 1:size(app.brainMask,1), 1:size(app.brainMask,3));
        [f, v] = isosurface(x, y, z, app.brainMask, 0.5);
        app.brainMaskPatch = patch(app.LesionVisualizationAxes, 'Faces', f, 'Vertices', v, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.03);
        view(app.LesionVisualizationAxes, 3);
        axis(app.LesionVisualizationAxes, 'equal');
        axis(app.LesionVisualizationAxes, 'off');
        camlight(app.LesionVisualizationAxes, 'headlight');
        lighting(app.LesionVisualizationAxes, 'gouraud');
    end
    app = drawLesions(app);

    % report
    app.whichIndex = app.lesionIndex;
    app = ExportButtonPushed(app);


end

function app = getDefaultOptions()
% This function returns a structure with all default values
app.bidsDir = '/Volumes/Vision/UsersShare/Amna/Multiple_Sclerosis_BIDS';
app.lesionDir = 'tmp_lesion';
app.LamDir = 'Laminate';
app.voxelSize = 0.7*0.7*0.7./1000;
app.LesionVisibilitySwitch.Value = 'One';
app.OverlayAlpha.Value = 1;
app.blueColor = [0,120,255]./255;
app.NewLesionCheckBox = struct;
app.NewLesionCheckBox.Value = 0;
app.DisappearingCheckBox = struct;
app.DisappearingCheckBox.Value = 0;

end


