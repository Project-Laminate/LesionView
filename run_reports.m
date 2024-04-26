% this script generates lesion view report without GUI
clearvars;
close all
clc;

bidsDir = '/Volumes/Vision/UsersShare/Amna/Multiple_Sclerosis_BIDS';
subjects = dir(fullfile(bidsDir,'derivatives','tmp_lesion','*sub*'));
addpath(genpath(fullfile(pwd,'noGuiFuncs')));
%% run all sub
tic
for whichSub = 3%17:numel(subjects)
    subject = subjects(whichSub).name;
    hasLesion1 = dir(fullfile(subjects(whichSub).folder,subject,'ses-01','*lesion*nii*'));
    hasLesion2 = dir(fullfile(subjects(whichSub).folder,subject,'ses-02','*lesion*nii*'));
    if numel(hasLesion1)&&numel(hasLesion2)
        lv_report(subject);
    end
end
toc
%% run one sub
% lv_report('sub-001');