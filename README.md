fMRI Preprocessing Pipeline (FSL + AFNI + ANTs)

A bash-based fMRI preprocessing pipeline that combines FSL, AFNI, and ANTs (plus SynthStrip for functional brain extraction) to produce an fMRI time series in MNI152 space.

What this pipeline does

For each subject/session, the script performs:

Slice-timing correction (FSL slicetimer, custom slice timing file)

Motion correction (AFNI 3dvolreg, using the middle volume as reference)

Motion outlier/confounds extraction (FSL fsl_motion_outliers)

Susceptibility distortion correction (FSL topup + applytopup) using AP/PA b0s

T1 preprocessing

N4 bias correction (ANTs N4BiasFieldCorrection)

Brain extraction (ANTs antsBrainExtraction.sh using MNI templates)

T1 → MNI registration (ANTs antsRegistration) and saving T1_in_MNIants.nii.gz

Functional → Anatomical registration

Functional mean brain extraction (SynthStrip)

EPI(mean) → T1 brain registration (ANTs antsRegistrationSyNQuick.sh)

Transform functional to MNI

Apply transforms to mean fMRI

Apply transforms to full 4D time series by splitting to 3D volumes, transforming each, then merging back (FSL fslsplit/fslmerge + antsApplyTransforms)

(Planned/placeholder) spatial smoothing + temporal filtering

Requirements
Software

FSL (slicetimer, fslmerge, fslmaths, fslinfo, fslsplit, fsl_motion_outliers)

AFNI (3dcalc, 3dvolreg)

ANTs (N4BiasFieldCorrection, antsBrainExtraction.sh, antsRegistration, antsApplyTransforms, antsRegistrationSyNQuick.sh)

SynthStrip (used for functional brain extraction; script uses a singularity wrapper/binary)

OS

Tested on: Linux (recommended). macOS may work but is less common for FSL/AFNI/ANTs pipelines.

Tested versions (fill these in)

Please record what you tested with:

FSL: _____

AFNI: _____

ANTs: _____

SynthStrip: _____

Inputs expected

The script assumes you have the following (paths are configured at the top of the script):

Functional

raw_file.nii.gz
Raw 4D fMRI time series.

slice_timings.txt
Custom slice timing file for slicetimer --tcustom.

Optional but recommended for distortion correction:

b0_ap.nii.gz

b0_pa.nii.gz

acq_parameters.txt
Topup acquisition parameters file used with topup/applytopup (--datain).

Anatomical

T1.nii.gz
Subject T1 (3D)

Templates

Uses FSL’s standard MNI files:

$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz

$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz

$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask.nii.gz

Outputs produced

Outputs are written inside your configured directories (typically under your func/, anatomical/, and conv_dir/).

Functional intermediates

inter_tc.nii.gz — slice-timing corrected

inter_tc_mid.nii.gz — middle-volume reference for motion correction

inter_mc.nii.gz — motion corrected

inter_mc.1D + mc1.1D ... mc6.1D — motion parameters

motion_confounds.txt — motion outliers/confounds (from fsl_motion_outliers)

b0_all.nii.gz — merged b0s (AP/PA)

my_topup_results* + b0_corr — topup outputs

inter_sc.nii.gz — susceptibility corrected fMRI series

inter_sc_avg.nii.gz — mean functional image

Anatomical outputs (ANTs)

T1_n4.nii.gz — N4 corrected T1

T1_BrainExtractionBrain.nii.gz — extracted T1 brain

T1_BrainExtractionMask.nii.gz — T1 brain mask

_T1_to_MNIants_* — registration transforms

T1_in_MNIants.nii.gz — T1 warped into MNI space

Registration / MNI space fMRI

inter_sc_avg_brain.nii.gz + inter_sc_avg_brain_mask.nii.gz — SynthStrip outputs

fmri2T1ants_0GenericAffine.mat — EPI(mean)→T1 affine

fmri_avg_in_MNIants.nii.gz — mean fMRI in MNI

fmri_ts_MNIants.nii.gz — full 4D fMRI in MNI space

Typical parameter choices you must set

These are user-defined in the script and should be documented for each dataset:

TR (seconds) for slice-timing: slicetimer -r <TR>

Slice timing file: --tcustom=/path/to/slice/timings.txt

Topup acquisition parameters: --datain=acq_parameters.txt

Topup config: --config=b02b0.cnf

applytopup method: --method=jac

(Later) smoothing FWHM and high-pass cutoff (if you add those steps)

How to run
1) Set paths in the script (or in a config.sh)

You need to define at least:

func=/path/to/functional_directory

anatomical=/path/to/anatomical_directory

conv_dir=/path/to/conversion_directory

acq_parameters=/path/to/acquisition_parameters.txt

2) Make executable
chmod +x preprocess.sh
3) Run
./preprocess.sh
