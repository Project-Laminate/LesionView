clearvars; close all; clc;

bidsDir = '/Volumes/Vision/UsersShare/Amna/Multiple_Sclerosis_BIDS';
subjects = {'sub-001', 'sub-002', 'sub-003'};

for whichSub = 1:numel(subjects)
    subject = subjects{whichSub};

    % Define paths for session 1
    lesion1Path2D = fullfile(bidsDir, 'derivatives', 'tmp_lesion', subject, 'ses-01', [subject, '_ses-01_acq-2D_space-individual_desc-lesionManualClean_mask.nii.gz']);
    lesion1Path3D = strrep(lesion1Path2D,'2D','3D');

    % Check if 2D file exists, otherwise use 3D
    if exist(lesion1Path2D, 'file')
        lesion1Path = lesion1Path2D;
        whichD = 2;
    elseif exist(lesion1Path3D, 'file')
        lesion1Path = lesion1Path3D;
        whichD = 3;
    else
        fprintf('Missing file for %s session 1\n', subject);
        continue;
    end

    % Define paths for session 2
    lesion2Path2D = fullfile(bidsDir, 'derivatives', 'tmp_lesion', subject, 'ses-02', [subject, '_ses-02_acq-2D_space-individual_desc-lesionManualClean_mask.nii.gz']);
    lesion2Path3D = strrep(lesion2Path2D,'2D','3D');

    % Check if 2D file exists, otherwise use 3D
    if exist(lesion2Path2D, 'file')
        lesion2Path = lesion2Path2D;
    elseif exist(lesion2Path3D, 'file')
        lesion2Path = lesion2Path3D;
    else
        fprintf('Missing file for %s session 2\n', subject);
        continue;
    end

    % Load NIfTI files
    lesion1 = niftiread(lesion1Path);
    lesion2 = niftiread(lesion2Path);

    % Initialize new lesion mask
    newLesionMask = zeros(size(lesion2));

    % Calculate the difference between the two lesion masks
    lesionDiff = lesion2 - lesion1;

    % Loop through each voxel and apply conditions
    for i = 1:numel(lesion2)
        if lesionDiff(i) == 0 && lesion2(i) == 1
            % Same lesion
            newLesionMask(i) = 1;
        elseif lesionDiff(i) == 1
            % Check if it's a new lesion or an enlarging lesion
            if lesion1(i) == 0
                newLesionMask(i) = 2;
            end
        elseif lesionDiff(i) == -1
            % Disappearing lesion
            newLesionMask(i) = 0;
        end
    end

    [L2, ~] = bwlabeln(lesion2 > 0.8, 26);

    for ii = 1:(numel(unique(L2)) - 1)
        % Find the current lesion in L2
        currentLesion = (L2 == ii);

        % Check for overlap with lesion1
        overlap = currentLesion & (lesion1 > 0.8);

        % If there is no overlap, it is a new lesion
        if sum(overlap(:)) == 0
            newLesionMask(currentLesion) = 3;
        end
    end

    % Save the new lesion mask
    outputDir = fullfile(bidsDir, 'derivatives', 'colorCodedLesionMask', subject);
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    if whichD == 2
        infoPath = fullfile(bidsDir, 'derivatives', 'Laminate', subject, 'ses-02', [subject, '_ses-02_acq-2D_space-individual_desc-preproc_FLAIR.nii.gz']);
    elseif whichD == 3
        infoPath = strrep(infoPath,'2D','3D');
    end

    info = niftiinfo(infoPath);
    outputFilePath = fullfile(outputDir, 'finalLesionMask.nii.gz');

    niftiwrite(single(newLesionMask), outputFilePath, info);
end