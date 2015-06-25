#!/bin/sh

SPHINX_FE=./vendor/sphinxbase/src/sphinx_fe/sphinx_fe
SPHINX_CEPVIEW=./vendor/sphinxbase/src/sphinx_cepview/sphinx_cepview

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 INPUT_AUDIO MFCC_OUT_PATH UEM_SEG_OUT_PATH" >&2
  exit 1
fi

input_audio=$1 # (NIST Sphere formatted)
mfcc_out_path=$2
uem_seg_out_path=$3

input_audio_extension=`echo "${input_audio##*.}" | tr '[:upper:]' '[:lower:]'`
if [ "$input_audio_extension" != "sph" ]; then
  echo "argument '$input_audio' is invalid:\n  INPUT_AUDIO must be in NIST Sphere format (.sph)" >&2
  exit 1
fi

clip_name=`basename "$input_audio" .sph`



echo "generating features: $input_audio --> ($mfcc_out_path, $uem_seg_out_path)" >&2

$SPHINX_FE -nist yes -i "$input_audio" -o "$mfcc_out_path" 2> /dev/null
fe_status=$?
if [ "$fe_status" -ne 0 ]; then
  echo "Problem running sphinx_fe on $input_audio" >&2
  exit 1
fi

mfcc_vector_count=`$SPHINX_CEPVIEW -d 0 -e 1 -header 1 -f $mfcc_out_path 2>&1 | grep frames | awk '{print $4;}'`

#make a uem composed of one segment starting at feature 0 with $mfcc_vector_count features
echo "$clip_name 1 0 $mfcc_vector_count U U U 1" > $uem_seg_out_path