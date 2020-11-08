#!/bin/bash
#Written by Andrea Di Iorio
TRGT_CONCAT_LIST="concat.list"
TRGT_EXCLUDED_LIST="excluded.list"
if [[ $1 ]];then TRGT_CONCAT_LIST=$1; fi
if [[ $2 ]];then TRGT_EXCLUDED_LIST=$2; fi
corrupted=0
for f in $(find -iname "*mp4"); do 
       if ffprobe -loglevel warning $f; then 
         printf 'file %s\n' $(realpath $f) >> $TRGT_CONCAT_LIST
       else 
         corrupted=$((corrupted+1)) 
	 echo $f >> $TRGT_EXCLUDED_LIST
       fi
done 
echo "founded corrupted: $corrupted"
