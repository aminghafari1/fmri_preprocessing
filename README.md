**fMRI Preprocessing Pipeline (FSL + AFNI + ANTs)**

***A bash-based fMRI preprocessing pipeline that combines FSL, AFNI, and ANTs (plus SynthStrip for functional brain extraction) to produce an fMRI time series in MNI152 space.***

## 🧠❓ What does this pipeline do:?

For each subject/session, the script performs:

Slice-timing correction (FSL slicetimer, custom slice timing file)

Motion correction (AFNI 3dvolreg, using the middle volume as reference)

Motion outlier/confounds extraction (FSL fsl_motion_outliers)

Susceptibility distortion correction (FSL topup + applytopup) using AP/PA b0s

**🧠 Structural (T1) Preprocessing:**

N4 bias correction (ANTs N4BiasFieldCorrection)

Brain extraction (ANTs antsBrainExtraction.sh using MNI templates)

T1 → MNI registration (ANTs antsRegistration) and saving T1_in_MNIants.nii.gz

**🧠 Native (fMRI) standardization (Registration to the standard MNI template):**

Functional → Anatomical registration

Functional mean brain extraction (skull stripping, SynthStrip)

Functional(mean) → T1 brain registration (ANTs antsRegistrationSyNQuick.sh)

Transform functional to MNI (QC here for alignment between functional and MNI template)

Apply derived transforms to full 4D time series by splitting to 3D volumes, transforming each, then merging back (FSL fslsplit/fslmerge + antsApplyTransforms)

**🧠 fMRI preprocessing in MNI space:**

spatial smoothing (FSLmaths, set the FWHM as desired)

temporal filtering (FSLmaths, set cutoff as desired, please refer to X for some guidance on this)

## 📦 Requirements

**Software**

FSL (slicetimer, fslmerge, fslmaths, fslinfo, fslsplit, fsl_motion_outliers)

AFNI (3dcalc, 3dvolreg)

ANTs (N4BiasFieldCorrection, antsBrainExtraction.sh, antsRegistration, antsApplyTransforms, antsRegistrationSyNQuick.sh)

SynthStrip (used for functional brain extraction; script uses a singularity wrapper/binary)

OS

*Processing tools were selected based on performance and output quality. Commented alternatives are provided for several steps, enabling flexibility in software requirements.*

**Tested on:** Linux (recommended). macOS may work but is less common for FSL/AFNI/ANTs pipelines.

*Tested versions:*

FSL: 6.0.3

AFNI: AFNI_22.1.06

ANTs: 2.6.2

SynthStrip: 1.8 (singularity)

## 📥 Inputs expected

The script assumes you have the following (paths are configured at the top of the script):

***Functional:***

*raw_file.nii.gz* --> This is the raw 4D fMRI time series.

*slice_timings.txt* --> Custom slice timing file for slicetimer --tcustom, suitable for multiband and other irregular acquisition schemes.
See the script comments and step-by-step documentation for interleaved acquisitions.

*Optional but necessary for distortion correction:*

b0_ap.nii.gz -->  Single-band reference image with anterior-to-posterior phase encoding (used for fieldmap estimation / distortion correction).

b0_pa.nii.gz --> Single-band reference image with posterior-to-anterior phase encoding (used for fieldmap estimation / distortion correction).

*acq_parameters.txt* --> the text file describing phase-encoding directions and readout times for distortion correction.

***Anatomical:***

T1.nii.gz
Subject T1 (3D)

***Templates (FSL’s standard MNI files):***

$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz --> Standard MNI152 T1 template (2 mm isotropic).

$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz --> Brain-extracted version of the MNI152 T1 template.

$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask.nii.gz --> Binary brain mask for the MNI152 template.

## 📤 Outputs Produced

Outputs are written inside your configured directories (typically under your func/, anatomical/, and conv_dir/).

***Functional intermediates:***

| File | Description |
|------|-------------|
| *inter_tc.nii.gz* | Slice-timing corrected fMRI |
| *inter_tc_mid.nii.gz* | Middle-volume reference for motion correction |
| *inter_mc.nii.gz* | Motion corrected fMRI |
| *inter_mc.1D, mc1.1D ... mc6.1D* | Motion parameters |
| *motion_confounds.txt* | Motion outliers / confounds (from `fsl_motion_outliers`) |
| *b0_all.nii.gz* | Merged b0 images (AP/PA) |
| *my_topup_results* + *b0_corr* | Topup outputs |
| *inter_sc.nii.gz* | Susceptibility-corrected fMRI series |
| *inter_sc_avg.nii.gz* | Mean functional image after susceptibility correction |
| *T1_n4.nii.gz* | N4 bias-corrected T1 anatomical image |
| *T1_BrainExtractionBrain.nii.gz* | Extracted T1 brain |
| *T1_BrainExtractionMask.nii.gz* | T1 brain mask |
| *_T1_to_MNIants_* | ANTs registration transforms |
| *T1_in_MNIants.nii.gz* | T1 warped into MNI space |
| *inter_sc_avg_brain.nii.gz, inter_sc_avg_brain_mask.nii.gz* | SynthStrip outputs (brain & mask) |
| *fmri2T1ants_0GenericAffine.mat* | EPI (mean) → T1 affine transform |
| *fmri_avg_in_MNIants.nii.gz* | Mean fMRI in MNI space |
| *fmri_ts_MNIants.nii.gz* | Full 4D fMRI in MNI space |

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
