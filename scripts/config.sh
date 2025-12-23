# config.sh
subj="BAP201"
ses="session2_auditory"
run="testrun3"
base="/path/to/subject/files"

fmri_input="${base}/raw_file.nii.gz"
T1_input="${base}/T1.nii.gz"

acq_parameters="/path/to/acquisition/parameters"
MNI="${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz" ## or your MNI template directory if different
MNIbrain="${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz"
MNIbrainmask="${FSLDIR}/data/standard/MNI152_T1_2mm_brain_mask.nii.gz"
TR="1.75" ## change this based on your TR
slice_order_file="/path/to/slice/order/timings"
fwhm="6" ## change this based on mm of your desired kernel for smoothing
