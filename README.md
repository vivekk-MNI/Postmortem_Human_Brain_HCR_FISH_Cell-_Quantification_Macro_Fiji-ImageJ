🧠 Postmortem HCR FISH Cell Quantification Macro (Fiji/ImageJ)
This repository provides a custom ImageJ macro to batch-process and quantify HCR FISH-labeled cells in frozen postmortem human cortical tissue, incorporating nuclear proximity filtering and layer-specific analysis. The macro supports flexible processing of two independent gene panels:

Panel 1: SST / Reelin

Panel 2: VIP / CCK

📌 Overview
The macro performs the following operations:

Z-Projection of confocal stacks using standard deviation to enhance contrast.

Background subtraction and channel splitting (DAPI, Gene1, Gene2).

Marker-specific segmentation via median + Gaussian filtering and Phansalkar local thresholding.

Size and shape filtering to exclude small debris and large artifacts.

DAPI-based nuclear proximity filtering using imported StarDist DAPI masks.

Logical colocalization of dual-labeled cells (e.g., SST+/Reelin+).

Layer-wise quantification using pre-drawn cortical layer ROIs.

Export of per-layer counts, area-normalized densities, and optional cell masks.

📁 Input Requirements
Confocal image files (.tif) converted from Olympus .oir files (see notes below).

DAPI masks for each image generated via StarDist and saved as binary .bmp images (e.g., ImageName_DAPI_Objects.bmp).

ROI files defining cortical layers drawn per image and saved as .zip files with the same base name (e.g., ImageName.zip).

🔬 Recommended Acquisition Settings
Pixel Size: 1.2430 µm × 1.2430 µm

Voxel Depth (Z-step): 4.1600 µm

Segmentation thresholds and size filters were calibrated for this resolution; adjustments may be needed for other settings.

📊 Sample Group Sizes
SST / Reelin Panel:

Control (n = 16), SCZ (n = 19), BP (n = 19)

VIP / CCK Panel:

Control (n = 21), SCZ (n = 18), BP (n = 18)

🛠 How to Use
🔄 Batch Mode (Recommended for large datasets)
Launch Fiji and open Postmortem_FISH_CellQuant_revised.ijm.

The macro will prompt for a folder containing .tif images, DAPI masks, and ROI .zip files.

It will automatically run segmentation, DAPI filtering, colocalization, and per-layer quantification for:

SST/Reelin (default version)

To run VIP/CCK, adjust the filterImages() and thresholdImages() lines to use "VIP" and "CCK" respectively, or duplicate and rename the macro accordingly.

⚠️ Ensure ROI files and DAPI masks match image base names.

🧪 Manual Mode (Useful for QC or tuning)
For manual inspection:

Load images individually.

Modify the macro to prompt for ROI drawing or segmentation adjustments interactively.

📂 Output
For each image, the macro saves:

*_counts.csv – cell counts per cortical layer

*_area.csv – ROI areas for density normalization

Optional: binary mask images for segmented populations

📚 Citations
If you use this macro or methodology in your work, please cite:

Phansalkar N. et al. (2011). Adaptive local thresholding for detection of nuclei in diversity stained cytology images. ICCSP, 218–220.

Schmidt U. et al. (2018). Cell Detection with Star-convex Polygons. MICCAI, 265–273.

🔗 Repository Contents
Postmortem_FISH_CellQuant_revised.ijm – Main macro for SST/Reelin panel

StarDist_DAPI_Segmentation.ijm – DAPI nuclear segmentation via StarDist

ROI_Draw_Save.ijm – Manual ROI drawing tool for cortical layer annotation
