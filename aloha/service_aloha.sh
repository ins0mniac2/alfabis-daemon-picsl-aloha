#!/bin/bash
ROOT=$(dirname $0)
ROOT=$ROOT/..
source $ROOT/dss_common.sh

# Set the path to ALOHA
export ALOHA_ROOT=/data/picsl/srdas/wd/aloha

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


# Provide callback info for ALOHA to update progress and send log messages
export ALOHA_HOOK_SCRIPT=$ROOT/aloha_dss_hook.sh
export ALOHA_HOOK_DATA=$TICKET_ID

# For qsub fine-tuning
ALOHA_QSUB_SCRIPT=$SCRIPTDIR/aloha_qsub_opts.sh

# The 8-digit ticket id string
IDSTRING=$(printf %08d $TICKET_ID)

# Split segmentation -- assume that we got HarP segmentation
T1_BL_LSEG=/tmp/aloha_${TICKET_ID}_lseg.nii.gz
T1_BL_RSEG=/tmp/aloha_${TICKET_ID}_rseg.nii.gz
c3d $T1_BL_SEG -thresh 102 102 1 0 -o $T1_BL_LSEG
c3d $T1_BL_SEG -thresh 103 103 1 0 -o $T1_BL_RSEG


# Ready to roll!
echo $ALOHA_ROOT/scripts/aloha_main.sh -Q \
  -b $T1_BL_FILE \
  -f $T1_FU_FILE \
  -r $T1_BL_LSEG \
  -s $T1_BL_RSEG \
  -w $WORKDIR

# Check the error code
if [[ $? -ne 0 ]]; then
  # TODO: we need to supply some debugging information, this is not enough
  # ALOHA crashed - report the error
  fail_ticket $TICKET_ID "ALOHA execution failed"
  exit -1 
fi


# Create a new workspace
itksnap-wt -i $WSFILE \
  -las $T1_BL_LSEG -psn "Baseline segmentation left" \
  -las $T1_BL_RSEG -psn "Baseline segmentation right" \
  -o $WSRESULT

