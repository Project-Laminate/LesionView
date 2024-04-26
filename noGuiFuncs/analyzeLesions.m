function app = analyzeLesions(app)
% This function analyzes lesions across two time points to identify new,
% continuing, and merged lesions. It labels each lesion, matches lesions
% across time points, calculates their volumes, and updates the UI
% components accordingly.

% Label the lesions in each time point image using a binary threshold of 0.8
% and a connectivity of 26.
[app.L1, ~] = bwlabeln(app.Lesion1 > 0.8, 26);
[app.L2, ~] = bwlabeln(app.Lesion2 > 0.8, 26);

% Initialize arrays to store new indices for matched lesions across time points
lesion1index = nonzeros(unique(app.L1));
lesion2index = nonzeros(unique(app.L2));
lesion1indexNew = zeros(size(lesion1index));
lesion2indexNew = zeros(size(lesion2index));

disp('Matching lesions across two time points ...');

% Loop through each lesion index in time point 1 and match with lesions in time point 2
% this is stupid
for i1 = 1:numel(lesion1index)

    for i2 = 1:numel(lesion2index)
        % Check if lesions overlap between time points
        match = (app.L1 == i1) & (app.L2 == i2);
        if sum(match(:)) > 0
            % Assign matching lesions the same new index
            if lesion2indexNew(i2) == 0
                lesion2indexNew(i2) = i1;
            else
                % Handle merged lesions by assigning them the index of the merging lesion
                lesion1indexNew(i1) = lesion2indexNew(i2);
            end
        end
    end
end

lesion1indexNew(lesion1indexNew==0) = lesion1index(lesion1indexNew==0);
lesion2indexNew(lesion2indexNew==0) = max(lesion1index)+1:max(lesion1index)+sum(lesion2indexNew==0);

valueToIndex = containers.Map(unique([lesion1indexNew;lesion2indexNew]), 1:numel(unique([lesion1indexNew;lesion2indexNew])));
lesion1indexNew = arrayfun(@(x) valueToIndex(x),lesion1indexNew);
lesion2indexNew = arrayfun(@(x) valueToIndex(x),lesion2indexNew);

[~, loc] = ismember(app.L1, lesion1index);
loc(loc > 0) = lesion1indexNew(loc(loc > 0));
app.L1(loc > 0) = loc(loc > 0);
[~, loc] = ismember(app.L2, lesion2index);
loc(loc > 0) = lesion2indexNew(loc(loc > 0));
app.L2(loc > 0) = loc(loc > 0);

disp('Sorting lesions by size ...')
newlist = unique([lesion1indexNew; lesion2indexNew]);
lesionVol = zeros(nnz(newlist), 1);
for ii = 1:nnz(newlist)
    lesionVol(ii) = max([nnz(app.L1 == ii) nnz(app.L2 == ii)]); % Number of voxels in the ith lesion
end

[~,newlistOrder] = sort(lesionVol,'descend');

[~, loc] = ismember(app.L1, newlistOrder);
loc(loc > 0) = newlist(loc(loc > 0));
app.L1(loc > 0) = loc(loc > 0);

[~, loc] = ismember(app.L2, newlistOrder);
loc(loc > 0) = newlist(loc(loc > 0));
app.L2(loc > 0) = loc(loc > 0);

% remove any lesion size less than xxx
app.L1(ismember(app.L1, find(sort(lesionVol,'descend')<3))) = 0;
app.L2(ismember(app.L2, find(sort(lesionVol,'descend')<3))) = 0;

disp('Calculating lesion centers ...')

% Calculate the center of each lesion for visualization
app.lesionIndex = nonzeros(unique([app.L1; app.L2])); % Combined list of unique lesion indices
app.lesionCenter = zeros(numel(app.lesionIndex), 3);
% Note: Image orientation adjustments might be necessary for correct visualization
tmpL1 = flip(app.L1, 2);
tmpL1 = flip(tmpL1, 3);
tmpL2 = flip(app.L2, 2);
tmpL2 = flip(tmpL2, 3);

% Initialize the matrix to store size changes across two time points
app.sizeChange = zeros(numel(app.lesionIndex), 3);

for ii = 1:numel(app.lesionIndex)
    % Generate binary matrices for each lesion by comparing with their indices
    binaryMat = tmpL1 == app.lesionIndex(ii);
    % Count the number of true values (lesion volume) in time point 1
    app.sizeChange(ii, 1) = sum(binaryMat(:));
    % Repeat for time point 2
    tmp2 = tmpL2 == app.lesionIndex(ii);
    app.sizeChange(ii, 2) = sum(tmp2(:));
    % If a lesion is not present in time point 1, use its presence in time point 2
    if sum(binaryMat(:)) < 1
        binaryMat = tmp2;
    end
    % Calculate the centroid of the lesion by finding the index of maximum sum along each dimension
    [~, app.lesionCenter(app.lesionIndex(ii), 1)] = max(squeeze(sum(sum(binaryMat, 2), 3)));
    [~, app.lesionCenter(app.lesionIndex(ii), 2)] = max(squeeze(sum(sum(binaryMat, 1), 3)));
    [~, app.lesionCenter(app.lesionIndex(ii), 3)] = max(squeeze(sum(sum(binaryMat, 1), 2)));
end
% Calculate the change in lesion size between two time points and convert to volume
app.sizeChange(:, 3) = (app.sizeChange(:, 2) - app.sizeChange(:, 1)) * app.voxelSize;

% Set the limits and enable the lesion index spinner based on available lesions
app.LesionIndexSpinner.Limits = [1, size(app.lesionCenter, 1)];
app.LesionIndexSpinner.Enable = 'on';

% Initialize the review states for each lesion across both time points as "keep"
app.LesionReviewStates = repmat("keep", numel(app.lesionIndex), 2);
app.LesionEditStates = repmat("reset", numel(app.lesionIndex), 1);

% Prepare clean and draft lesion matrices and backup for both time points
app.Lesion1Clean = app.L1;
app.Lesion1Draft = zeros(size(app.L1));
app.Lesion2Clean = app.L2;
app.Lesion2Draft = zeros(size(app.L2));
app.L1backUp = app.L1;
app.L2backUp = app.L2;

% Identify new lesions in time point 2 that were not present in time point 1
tmp1 = app.L1;
tmp1(ismember(tmp1,app.lesionIndex(app.LesionReviewStates(:,1)=="delete"))) = 0;
tmp2 = app.L2;
tmp2(ismember(tmp2,app.lesionIndex(app.LesionReviewStates(:,2)=="delete"))) = 0;

lesionList1 = unique(tmp1);
lesionList2 = unique(tmp2);
app.newLesionIndex = lesionList2(~ismember(unique(tmp2), unique(tmp1)));
app.goneLesionIndex = lesionList1(~ismember(unique(tmp1), unique(tmp2)));


app.currentIndex = 1;
app.x0.Value = app.lesionCenter(app.currentIndex,1);
app.y0.Value = app.lesionCenter(app.currentIndex,2);
app.z0.Value = app.lesionCenter(app.currentIndex,3);

end