# LesionView

# LesionView Application

LesionView is designed to review and compare lesions at two time points. 

## Prerequisites

- MATLAB Image Processing Toolbox
- [Ghostscript](https://www.ghostscript.com/) (for PDF report generation)
    brew install ghostscript

## Files Required

- **T2 Flair Images**: MRI images at baseline and followup. These should be in NIfTI format.
- **Lesion Masks**: Binary masks indicating the location of lesions within the brain at baseline and followup. These should be binary images of the same size and orientation as the T2 flair images.
- **Brain Mask** (optional): A binary mask indicating the brain region. 

## Usage

1. Start the app and load the required files using the provided buttons.
2. Use the visualization tools to review lesions across the two time points.
3. Classify lesions as "keep", "draft", or "delete" based on your review.
4. Generate reports, gifs, and clean or draft lesion masks as needed.

## Outputs

The app can generate the following outputs:

- **Clean Lesion Masks**: Binary masks of lesions classified as "keep".
- **Draft Lesion Masks**: Binary masks of lesions classified as "draft". 
- **GIFs**: Animated visualizations showing lesions over time.
- **PDF Reports**: A PDF report including lesion counts, volumes, and comparative visualizations.

## Report Contents

- 3D visualizations of lesions at baseline and followup.
- Textual summary of lesion counts and volumes.
- A bar graph showing the lesion size change between baseline and followup.
- 2D view of each new lesions at baseline and followup.


