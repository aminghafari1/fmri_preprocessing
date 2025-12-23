#!/bin/bash
set -euo pipefail
source config.sh
## epi ap and epi pa scans, if available, can make your b0_ap and b0_pa files which are needed for topup (susceptibility correction)
## slice timing correction
func="${base}/func"
echo "Working directory is $base"
anatomical="${base}/anatomical"
conv_dir="${base}/conversions"
mkdir -p "$func" "$anatomical" "$conv_dir"
cp "$fmri_input" "${func}/raw_file.nii.gz"
cp "$T1_input" "${anatomical}/T1.nii.gz"

echo "⏱️🧠 Starting Slice-Timing Correction... 🔧🎬"
slicetimer -i ${func}/raw_file.nii.gz -o ${func}/inter_tc.nii.gz -r $TR --tcustom=$slice_order_file 

echo "Motion correction using the middle volume."
num_of_vols=$(fslval ${func}/inter_tc.nii.gz dim4)
mid_vol=$((num_of_vols/2))
3dcalc -a ${func}/inter_tc.nii.gz[$mid_vol] -expr 'a'  -prefix ${func}/inter_tc_mid.nii.gz
## You get the slice_timing_corrected mid volume in this way

echo "🧠⏱️ Now doing the motion correction... 🚀"
3dvolreg -Fourier -twopass -maxdisp1D mm -base ${func}/inter_tc_mid.nii.gz -zpad 4 \
 -prefix ${func}/inter_mc.nii.gz -1Dfile ${func}/inter_mc.1D ${func}/inter_tc.nii.gz

echo "Splitting motion parameters, you can use them later for regression if needed."
awk '{print $1}' ${func}/inter_mc.1D > ${func}/mc1.1D
awk '{print $2}' ${func}/inter_mc.1D > ${func}/mc2.1D
awk '{print $3}' ${func}/inter_mc.1D > ${func}/mc3.1D
awk '{print $4}' ${func}/inter_mc.1D > ${func}/mc4.1D
awk '{print $5}' ${func}/inter_mc.1D > ${func}/mc5.1D
awk '{print $6}' ${func}/inter_mc.1D > ${func}/mc6.1D

echo "Get the motion outliers"
fsl_motion_outliers -i ${func}/inter_mc -o ${func}/motion_confounds.txt -p motion.png --nomoco

if [[ -f ${base}/b0_ap.nii.gz && -f ${base}/b0_pa.nii.gz ]]; then
mv ${base}/b0_ap.nii.gz ${func}/b0_ap.nii.gz
mv ${base}/b0_pa.nii.gz ${func}/b0_pa.nii.gz
echo "🧲⚡ Initiating Susceptibility Distortion Correction… Stabilizing spacetime grid... 🌌🛰️"
fslmerge -t ${func}/b0_all.nii.gz ${func}/b0_ap.nii.gz ${func}/b0_pa.nii.gz
topup --imain=${func}/b0_all.nii.gz --datain=$acq_parameters\
 --config=b02b0.cnf --out=${func}/my_topup_results --iout=${func}/b0_corr
applytopup --imain=${func}/inter_mc.nii.gz --inindex=1 --datain=$acq_parameters \
 --topup=${func}/my_topup_results --out=${func}/inter_sc.nii.gz --method=jac -v
else
echo "No b0 pairs found, skipping susceptibility distortion correction..."
cp ${func}/inter_mc.nii.gz ${func}/inter_sc.nii.gz
fi

fmri_ts="$func/inter_sc.nii.gz"
fslmaths $fmri_ts -Tmean ${func}/inter_sc_avg.nii.gz
fmri_ts_avg="$func/inter_sc_avg.nii.gz"

echo "🧠🔄 Brain Extraction in Progress... Carving out the cerebral core... 🧩🧠"
echo "You need to have ANTs installed for this step, it is very easy to install that via conda.
Just make a new conda environment and install ants in it."


N4BiasFieldCorrection -d 3 -i "${anatomical}/T1.nii.gz" \
-o "${anatomical}/T1_n4.nii.gz" -r 1 -s 4 -v > /dev/null 2>&1
t1="${anatomical}/T1_n4.nii.gz"

antsBrainExtraction.sh -d 3 -a $t1 -e $MNI\
      -m $MNIbrainmask -o "${anatomical}/T1_" > /dev/null 2>&1
t1_brain="$anatomical/T1_BrainExtractionBrain.nii.gz"
t1_brain_mask=$anatomical/T1_BrainExtractionMask.nii.gz
echo "🧠🔄 Aligning Anatomical brain to MNI brain 🔄🧩"

antsRegistration -d 3 \
-o "${anatomical}/_T1_to_MNIants_" \
-v -u 1 -z 1 \
--winsorize-image-intensities [0.005,0.995] \
-r [$MNI, $t1, 1] \
-m MI[$MNI, $t1, 1, 32, regular, 0.25] \
-c [1000x500x250x100,1e-7,5] \
-t Rigid[0.1] \
-f 8x4x2x1 -s 4x2x1x0 \
-x [","] \
-m MI[$MNIbrain, $t1_brain, 1, 32, regular, 0.25] \
-c [1000x500x250x100,1e-7,5] \
-t Affine[0.1] \
-f 8x4x2x1 -s 4x2x1x0 -x [","] \
-m cc[$MNIbrain, $t1_brain, 1, 4] \
-m MI[$MNI, $t1, 0.1, 32, regular, 0.25] \
-c [100x70x50,1e-7,5] \
-t SyN[0.04,3,0] \
-f 4x2x1 -s 2x1x0 \
-x [$MNIbrainmask, $t1_brain_mask] > /dev/null 2>&1

antsApplyTransforms -d 3 -i $t1 -r $MNI -t ${anatomical}/_T1_to_MNIants_1Warp.nii.gz \
    -t ${anatomical}/_T1_to_MNIants_0GenericAffine.mat -o ${anatomical}/T1_in_MNIants.nii.gz


echo "segmentation"
fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 -o "${anatomical}/T1_seg" $t1_brain > /dev/null 2>&1
mv ${anatomical}/T1_seg_pve_0.nii.gz ${anatomical}/T1_CSF.nii.gz
mv ${anatomical}/T1_seg_pve_1.nii.gz ${anatomical}/T1_GM.nii.gz
mv ${anatomical}/T1_seg_pve_2.nii.gz ${anatomical}/T1_WM.nii.gz

echo "move the segmentation files to the mni space"
for tissue in CSF GM WM; do
    input_seg="${anatomical}/T1_${tissue}.nii.gz"
    output_seg="${anatomical}/T1_${tissue}_MNI.nii.gz"
    antsApplyTransforms -d 3 -i $input_seg -r $MNI \
        -t ${anatomical}/_T1_to_MNIants_1Warp.nii.gz \
        -t ${anatomical}/_T1_to_MNIants_0GenericAffine.mat \
        -o $output_seg
    fslmaths $output_seg -thr 0.8 -bin $output_seg
done

echo "🧠🔄 Registering Functional to Anatomical Space... "
echo "Synthstrip is a machine learning based tool from freesurfer for brain extraction, works well for functional data."
echo "We are using the singularity version here, you can also install freesurfer and use that, or use docker."
 
 ~/synthstrip-singularity -i $fmri_ts_avg -o $func/inter_sc_avg_brain.nii.gz -m $func/inter_sc_avg_brain_mask.nii.gz
 fmri_avg_brain="$func/inter_sc_avg_brain.nii.gz"

 echo "🧠🔄 Now registering functional to anatomical... 🔄"
    antsRegistrationSyNQuick.sh -d 3 -f $t1_brain -m $fmri_avg_brain -o ${conv_dir}/fmri2T1ants_ -t a > /dev/null 2>&1

echo "Look at fMRI in T1 space as QC"
antsApplyTransforms -d 3 -i $fmri_avg_brain -r $t1_brain -t ${conv_dir}/fmri2T1ants_0GenericAffine.mat -o $func/fmri_avg_in_T1ants.nii.gz

aff_fmri_to_t1=${conv_dir}/fmri2T1ants_0GenericAffine.mat
t1_to_MNI_init=${anatomical}/_T1_to_MNIants_0GenericAffine.mat
t1_to_MNI_warp=${anatomical}/_T1_to_MNIants_1Warp.nii.gz
fmri_ts="$func/inter_sc.nii.gz"
antsApplyTransforms -d 3 -i $fmri_avg_brain -r $MNIbrain \
    -t $t1_to_MNI_warp -t $t1_to_MNI_init -t $aff_fmri_to_t1 -o $func/fmri_avg_in_MNIants.nii.gz

echo "🧠🔄 Transforming the entire fMRI time series to MNI space... 🔄"
input_4d="$fmri_ts"
output_4d="$func/fmri_ts_MNIants.nii.gz"
ref="$MNI"
tempdir="$func/tempdir_fmri_MNIants"
mkdir -p $tempdir
cd "$tempdir"
echo "Splitting 4D fmri data into 3D volumes..."
fslsplit "$input_4d" vol_ -t

echo "Applying transforms to each volume..."
for vol in vol_*.nii.gz; do
    echo "Processing $vol"
    antsApplyTransforms -d 3 -i "$vol" -r "$ref" \
    -t "$t1_to_MNI_warp" -t "$t1_to_MNI_init" -t "$aff_fmri_to_t1" \
    -o "${vol%.nii.gz}_MNI.nii.gz"
done

echo "Merging transformed volumes back into 4D fmri data..."
fslmerge -t "$output_4d" vol_*_MNI.nii.gz
cd ..
echo "cleaning"
rm -rf "$tempdir"

for tissue in WM CSF GM; do
    echo "Extracting time series for $tissue"
    tissue_mask="${anatomical}/T1_${tissue}_MNI.nii.gz"
    fslmeants -i $output_4d -o ${func}/fmri_ts_${tissue}.txt -m $tissue_mask
done

echo "✅🧠 Spatial smoothing. 🎉📊"
fwhm=$fwhm # Set your desired FWHM in mm
sigma=`echo "scale=4; ${fwhm}/2.3548" | bc`
fslmaths $output_4d -kernel gauss $sigma ${func}/fmri_ts_smooth.nii.gz

fslmerge -tr "${func}/fmri_preprocessed.nii.gz" "${func}/fmri_ts_smooth.nii.gz" $TR 

