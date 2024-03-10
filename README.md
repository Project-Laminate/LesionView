# LesionView

LesionView is designed to review and compare lesions at two time points. 

## Prerequisites

- MATLAB Image Processing Toolbox
- [Ghostscript](https://www.ghostscript.com/) (for PDF report generation)
    `brew install ghostscript`

## Files Required

- **T2 Flair Images**: MRI images at baseline and followup. These should be in NIfTI format.
- **Lesion Masks**: Binary masks indicating the location of lesions within the brain at baseline and followup. These should be binary images of the same size and orientation as the T2 flair images.
- **Brain Mask** (optional): A binary mask indicating the brain region. 

## Usage

- In MATLAB command window type `LesionView` and load the required files
- LesionView offers two main functionalities: lesion review and report generation. Depending on your workflow, you can use the app for either purpose as described below.

### For Lesion Review:
- Use the visualization tools to examine lesions across the two time points.
- Review each lesion and mark it as "keep", "draft", or "delete".
- Click "SAVE .nii"
- Use other software like *fsleyes* to edit lesions in draft.nii and merge it with clean.nii as the final lesion mask 

### For Report Generation:
- Ensure you have loaded the cleaned and final lesion masks post-review. The app generates reports based on these cleaned-up masks.
- Click "Export" 

For report generation, it's crucial to use lesion masks that have been reviewed to ensure the accuracy and relevance of the generated reports. This report is only as accuracte as the lesion masks. 


## Outputs

The app can generate the following outputs:

- **Clean Lesion Masks**: Lesions classified as "keep". Values will be the lesion index.
- **Draft Lesion Masks**: Lesions classified as "draft". Values will be the lesion index. 
- **GIFs**: Animated visualizations showing lesions over time.
- **PDF Reports**: A PDF report including lesion counts, volumes, and comparative visualizations.

## Report Contents
- **Page 1**
- 3D visualizations of lesions at baseline and followup
- Summary of lesion counts and volumes
- A bar graph showing the lesion size change
- 2D view of the change of the larget lesion
- **Page 2+**
- 2D view of each new lesions

## Currently hardcoded variables 
- incorrect BIDS path
- remove lesions less than 5 ml 





