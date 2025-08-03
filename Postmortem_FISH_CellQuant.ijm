// ------------------------ Image Processing Pipeline For REELIN-SST HCR-FISH Images------------------------
// Batch processing of TIFF images exported from Olympus FV3000 (.oir).
// Recommended: Convert .oir to .tif via Fiji > Plugins > Batch > Macro for compatibility.
//
// Input: TIFF images and associated DAPI masks and ROI zip files.
// Output: Cell segmentation, DAPI filtering, colocalization analysis, and per-layer counts.

input = getDirectory("Choose a folder with TIFF images");

// Define output directory
outputPath = input + "results/";
File.makeDirectory(outputPath);

// Retrieve list of input files
list = getFileList(input);

// Note: setBatchMode(true) may improve performance by hiding image windows,
// but may cause LUT/display issues on some systems. Adjust as needed.
setBatchMode(false);

for (i = 0; i < list.length; i++) {
    if (!endsWith(list[i], ".tif")) continue;

    open(input + list[i]);
    title = getTitle();
    name = substring(title, 0, lengthOf(title) - 4); // Remove .tif extension

    // Step 1: Preprocessing — Projection, Background Subtraction, and Channel Separation
    prepareImages();

    // Step 2: Denoise and Segment Individual Markers (Sst, Reelin)
    filterImages("Sst");
    thresholdImages("Sst", 40);

    filterImages("Reelin");
    thresholdImages("Reelin", 30);

    // Step 3: Segment DAPI chhanel
	selectImage("DAPI");
	run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], args=['input':'DAPI', 'modelChoice':'Versatile (fluorescent nuclei)', 'normalizeInput':'true', 'percentileBottom':'0.0', 'percentileTop':'97.9', 'probThresh':'0.4', 'nmsThresh':'0.6000000000000001', 'outputType':'Label Image', 'nTiles':'1', 'excludeBoundary':'0', 'roiPosition':'Stack', 'verbose':'false', 'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]");
	selectImage("Label Image");
	run("Separate Labels (2D/3D)");
	setOption("ScaleConversions", true);
	run("8-bit");
	setAutoThreshold("Default dark");
	setThreshold(1, 255);
	run("Convert to Mask");
	rename("DAPI_Objects");

    extractDAPIOverlap("Sst");
    extractDAPIOverlap("Reelin");

    // Step 4: Identify and refine overlapping Reelin+Sst cells
    imageCalculator("AND create", "Reelin_cells", "Sst_cells");
    run("Analyze Particles...", "size=20-500 circularity=0.0-1.00 show=Masks exclude");
    run("Convert to Mask");
    rename("Reelin_Sst_cells");

    // Step 5: 
    //Import ROI layers (drawn manually and saved as default list of ROIs in '.zip' format, see below for batch drawing and saving)
    roiManager("open", input + name + ".zip");
    // {Alternatively, draw ROIs on the fly, first create Composite then RGB image!
	//run("Z Project...", "projection=[Max Intensity]");
	//run("Make Composite");
	//run("RGB");
	//-----------------------------------
	// ROI draw!
	//setTool("freehand");
	//waitForUser("draw ROI layers 1-7 then add to ROI manager; then click \"OK\" in this dialog to continue.");}
	//roiManager("save", input + name + ".zip");
    
    //Label cortical layers and perform per-layer cell quantification
    label_Cortical_layers();

    countCells("Sst");
    countCells("Reelin");
    countCells("Reelin_Sst");

    // Step 6: Estimate area of each cortical layer to be used for cell-density normalization
    selectWindow("Sst");
    run("Duplicate...", " ");
    setOption("ScaleConversions", true);
    run("8-bit");
    run("Convert to Mask");

    roiManager("Select", newArray(0, 1, 2, 3, 4, 5, 6));
    run("Select All");
    roiManager("measure");

    // Save results
    selectWindow("Results");
    saveAs("Results", outputPath + name + "_area.csv");

    selectWindow("Summary");
    saveAs("Results", outputPath + name + "_counts.csv");

    // Step 7: Clean up for next image
    close("*");
    roiManager("reset");
    close(name + "_counts.csv");
    close(name + "_area.csv");
}


// ------------------------ Function Definitions ------------------------

// Step 1: Z-project, subtract background, split channels, and rename appropriately
function prepareImages() {
    run("Z Project...", "projection=[Standard Deviation]");
    run("Subtract Background...", "rolling=50 stack");

    run("Split Channels");

    selectImage("C1-STD_" + title); rename("DAPI");
// The C2 channel, acquired using 488 nm excitation, was used to verify the effectiveness of TrueBlack-based lipofuscin suppression.
// In cases where residual lipofuscin signal was visible, the C2 image was used to subtract autofluorescence from the target channels (C3 and C4).
    selectImage("C3-STD_" + title); rename("Reelin");
    selectImage("C4-STD_" + title); rename("Sst");
}

// Step 2: Apply median + Gaussian smoothing filters
function filterImages(target) {
    run("Duplicate...", " ");
    resetMinAndMax();
    run("Median...", "radius=2");
    run("Gaussian Blur...", "sigma=1");
}

// Step 3: Thresholding and mask refinement with exclusion of artifacts
function thresholdImages(target, minSize) {
    rename(target + "_Med_GB");
    run("Duplicate...", "title=" + target + "_Dup");

    setOption("ScaleConversions", true);
    run("8-bit");
    run("Auto Local Threshold", "method=Phansalkar radius=15 parameter_1=0 parameter_2=0");
    run("Grays");
    setAutoThreshold("Default");
    setOption("BlackBackground", false);
    run("Convert to Mask");

    run("Analyze Particles...", "size=" + minSize + "-500.00 circularity=0.45-1.00 show=Masks");
    run("Convert to Mask");
	rename(target + "_Phansalkar");
    
    //Filter and dialte smaller objects (neurons)
    run("Analyze Particles...", "size=" + minSize + "-60 circularity=0.45-1.00 show=Masks exclude");
    run("Convert to Mask");
    rename(target + "_SmallObjects");
    run("Dilate");

    //Combine masks to get final objects
    imageCalculator("Add create", target + "_SmallObjects", target + "_Phansalkar");
    run("Convert to Mask");
    rename(target + "_Objects");
}

// Step 4: Extract and keep only objects overlapping with DAPI signal
function extractDAPIOverlap(target) {
    run("Overlap Extractor (2D/3D)", 
        "image_plus_1=[" + target + "_Objects] " +
        "image_plus_2=[DAPI_Objects] " +
        "volume_range=5-100.0 " +
        "exclude_edge_objects=false " +
        "show_original_primary_statistics=false " +
        "show_extracted_objects=true " +
        "show_count_statistics=false " +
        "show_volume_statistics=false " +
        "show_percent_volume_map=false " +
        "treat_binary_objects_as_one=false");

    setThreshold(1, 255);
    run("Convert to Mask");
    rename(target + "_cells");
}

// Step 5: Rename ROIs to cortical layer identifiers
// Function: Assign standard names to 7 cortical layer ROIs
function label_Cortical_layers() {
    roiManager("Select", 0); roiManager("Rename", title + "_Cortical_Layer_1");
    roiManager("Select", 1); roiManager("Rename", title + "_Cortical_Layer_2");
    roiManager("Select", 2); roiManager("Rename", title + "_Cortical_Layer_3");
    roiManager("Select", 3); roiManager("Rename", title + "_Cortical_Layer_4");
    roiManager("Select", 4); roiManager("Rename", title + "_Cortical_Layer_5a");
    roiManager("Select", 5); roiManager("Rename", title + "_Cortical_Layer_5b");
    roiManager("Select", 6); roiManager("Rename", title + "_Cortical_Layer_6");
}



// Step 6: Count number of cells per ROI for a given marker or overlap
function countCells(target) {
    selectWindow(target + "_cells");
    rename(getTitle() + target + "_cells");

    for (i = 0; i <= 6; i++) {
        roiManager("Select", i);
        run("Analyze Particles...", "exclude summarize");
    }
}
