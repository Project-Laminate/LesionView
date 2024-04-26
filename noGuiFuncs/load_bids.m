
function app = load_bids(app)

try
    % FlairTP1
    FlairTP1File = dir(fullfile(app.bidsDir,'derivatives', app.LamDir,app.subject, 'ses-01', '*acq-2D*FLAIR.nii.gz'));
    if isempty(FlairTP1File)
        FlairTP1File = dir(fullfile(app.bidsDir,'derivatives', app.LamDir,app.subject, 'ses-01', '*acq-3D*FLAIR.nii.gz'));
    end

    if ~isempty(FlairTP1File)
        disp(['Loading Flair time point 1 from : ', fullfile(FlairTP1File.folder, FlairTP1File.name)]);
        app.FlairTP1 = niftiread(fullfile(FlairTP1File.folder, FlairTP1File.name));
        app.FlairTP1 = flip(app.FlairTP1,2);app.FlairTP1 = flip(app.FlairTP1,3);
    else
        disp('*** No baseline FLAIR found ***')
    end

    % FlairTP2
    FlairTP2File = dir(fullfile(app.bidsDir,'derivatives', app.LamDir,app.subject, 'ses-02', '*acq-2D*FLAIR.nii.gz'));
    if isempty(FlairTP2File)
        FlairTP2File = dir(fullfile(app.bidsDir,'derivatives', app.LamDir,app.subject, 'ses-02', '*acq-3D*FLAIR.nii.gz'));
    end
    if ~isempty(FlairTP2File)
        disp(['Loading Flair time point 2 from : ', fullfile(FlairTP2File.folder, FlairTP2File.name)]);
        app.FlairTP2 = niftiread(fullfile(FlairTP2File.folder, FlairTP2File.name));
        app.FlairTP2 = flip(app.FlairTP2,2);app.FlairTP2 = flip(app.FlairTP2,3);
    else
        disp('*** No followup FLAIR found ***')
    end

    app.whichT2 = app.FlairTP2;
    app.currentImageIndex = 2;

    % BrainMask
    brainMaskFile = dir(fullfile(app.bidsDir,'derivatives',app.LamDir,app.subject, 'ses-01', '*brain_mask.nii.gz'));
    if ~isempty(brainMaskFile)
        disp(['Loading brain mask from : ', fullfile(brainMaskFile(1).folder, brainMaskFile(1).name)]);
        app.brainMask = niftiread(fullfile(brainMaskFile(1).folder, brainMaskFile(1).name));
        app.fileStatus(5) = true;
        disp('Drawing brain mask ...')
    else
        disp(['*** No BrainMask found ***'])
    end

    % Lesion1
    lesion1File = dir(fullfile(app.bidsDir,'derivatives',app.lesionDir,app.subject, 'ses-01', '*acq-2D*lesion*.nii.gz'));
    if isempty(lesion1File)
        lesion1File = dir(fullfile(app.bidsDir,'derivatives',app.lesionDir,app.subject, 'ses-01', '*acq-3D*lesion*.nii.gz'));
    end
    if ~isempty(lesion1File)
        disp(['Loading Lesion mask time point 1 from : ', fullfile(lesion1File(1).folder, lesion1File(1).name)]);
        app.Lesion1 = niftiread(fullfile(lesion1File(1).folder, lesion1File(1).name));
        app.FlairInfo = niftiinfo(fullfile(lesion1File(1).folder, lesion1File(1).name));
    else
        disp('*** No baseline lesion found ***')
    end

    % Lesion2
    lesion2File = dir(fullfile(app.bidsDir,'derivatives',app.lesionDir, app.subject, 'ses-02', '*acq-2D*lesion*.nii.gz'));
    if isempty(lesion2File)
        lesion2File = dir(fullfile(app.bidsDir,'derivatives',app.lesionDir, app.subject, 'ses-02', '*acq-3D*lesion*.nii.gz'));
    end

    if ~isempty(lesion2File)
        disp(['Loading Lesion mask time point 2 from : ', fullfile(lesion2File(1).folder, lesion2File(1).name)]);
        app.Lesion2 = niftiread(fullfile(lesion2File(1).folder, lesion2File(1).name));
    else
        disp('*** No followup lesion found ***')
    end
    close all;
catch ME
end

end