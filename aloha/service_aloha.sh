#!/bin/bash
ROOT=$(dirname $0)
ROOT=$ROOT/..
source $ROOT/dss_common.sh

# Set the path to ALOHA
export ALOHA_ROOT=/home/srdas/aloha

# Get the command-line arguments
TICKET_ID=${1?}
WORKDIR=${2?}
WSFILE=${3?}
WSRESULT=${4?}

# Identify the baseline and followup T1 images
T1_BL_FILE=$(itksnap-wt -P -i $WSFILE -llf T1-MRI-BL)
if [[ $(echo $T1_BL_FILE | wc -w) -ne 1 || ! -f $T1_BL_FILE ]]; then
  fail_ticket $TICKET_ID "Missing tag 'T1-MRI-BL' in ticket workspace"
  exit -1
fi

T1_FU_FILE=$(itksnap-wt -P -i $WSFILE -llf T1-MRI-FU)
if [[ $(echo $T1_FU_FILE | wc -w) -ne 1 || ! -f $T1_FU_FILE ]]; then
  fail_ticket $TICKET_ID "Missing tag 'T1-MRI-FU' in ticket workspace"
  exit -1
fi

# Identify the baseline T1 segmentation
T1_BL_SEG=$(itksnap-wt -P -i $WSFILE -ll | grep Segmentation | grep HARP | awk '{print $4}')
if [[ $(echo $T1_BL_SEG | wc -w) -ne 1 || ! -f $T1_BL_SEG ]]; then
  fail_ticket $TICKET_ID "Missing tag 'T1-MRI-SEG' in ticket workspace"
  exit -1
fi

if 0; then
export ASHS_ROOT=/home/ashs/tk/ashs-fast
ASHS_HARP_ATLAS=/home/ashs/tk/ashs_atlas_harp30/final
ASHS_ICV_ATLAS=/home/ashs/tk/ashs_atlas_icv/final

# Run HarP to get hippocampus segmentation
$ASHS_ROOT/bin/ashs_main.sh \
  -a $ASHS_ICV_ATLAS \
  -g $T1_FILE -f $T1_FILE \
  -w $WORKDIR/ashs_icv \
  -I $IDSTRING \
  -H -B -Q -z $SCRIPTDIR/ashs_qsub_opts.sh


fi

# Provide callback info for ALOHA to update progress and send log messages
export ALOHA_HOOK_SCRIPT=$ROOT/aloha_dss_hook.sh
export ALOHA_HOOK_DATA=$TICKET_ID

# For qsub fine-tuning
ALOHA_QSUB_SCRIPT=$SCRIPTDIR/aloha_qsub_opts.sh

# The 8-digit ticket id string
IDSTRING=$(printf %08d $TICKET_ID)

# Split segmentation -- assume that we got HarP segmentation
T1_BL_LSEG=$WORKDIR/aloha_${TICKET_ID}_lseg.nii.gz
T1_BL_RSEG=$WORKDIR/aloha_${TICKET_ID}_rseg.nii.gz
$ALOHA_ROOT/ext/Linux/bin/c3d $T1_BL_SEG -thresh 102 102 1 0 -o $T1_BL_LSEG
$ALOHA_ROOT/ext/Linux/bin/c3d $T1_BL_SEG -thresh 103 103 1 0 -o $T1_BL_RSEG


# Ready to roll!
$ALOHA_ROOT/scripts/aloha_main.sh -Q \
  -b $T1_BL_FILE \
  -f $T1_FU_FILE \
  -r $T1_BL_LSEG \
  -s $T1_BL_RSEG \
  -w $WORKDIR \
  -H 

# Check the error code
if [[ $? -ne 0 ]]; then
  # TODO: we need to supply some debugging information, this is not enough
  # ALOHA crashed - report the error
  fail_ticket $TICKET_ID "ALOHA execution failed"
  exit -1 
fi


# Create a new workspace
# itksnap-wt -i $WSFILE -labels-clear \
itksnap-wt \
  -lsm $WORKDIR/deformable/blmptrim_left_to_hw.nii.gz -psn "Global left BL" \
  -laa $WORKDIR/deformable/fumptrim_om_leftto_hw.nii.gz -psn "Global left FU" \
  -laa $WORKDIR/deformable/blmptrim_right_to_hw.nii.gz  -psn "Global right BL" \
  -laa $WORKDIR/deformable/fumptrim_om_rightto_hw.nii.gz -psn "Global right FU" \
  -laa $WORKDIR/deformable/fumptrim_om_to_hw_warped_3d_left.nii.gz -psn "Deformable left FU" \
  -laa $WORKDIR/deformable/fumptrim_om_to_hw_warped_3d_right.nii.gz -psn "Deformable right FU" \
  -o $WSRESULT
:<<'NOATTACH'
NOATTACH

bash $ALOHA_HOOK_SCRIPT attach  "Left volumes" $WORKDIR/results/volumes_left.txt
bash $ALOHA_HOOK_SCRIPT attach  "Right volumes" $WORKDIR/results/volumes_right.txt

# $ALOHA_HOOK_SCRIPT  $TICKET_ID
bash $ALOHA_HOOK_SCRIPT  info "Successfully completed"

exit
