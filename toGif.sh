#!/bin/bash
#Copyright Andrea Di Iorio 2020
#This file is part of FFmpegFastTrimConcat
#FFmpegFastTrimConcat is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#FFmpegFastTrimConcat is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with FFmpegFastTrimConcat.  If not, see <http://www.gnu.org/licenses/>.

#create a gif preview of a 2 blocks of a video using exploiting cuda hw accelaration
set -e 
#try to get blkFrames every srcSamplingDistSec, picking in each block every 1/srcSampling secs, for blocksN blocks

dur=$(ffprobe -loglevel error -show_entries stream=duration -select_streams v:0 -of csv=p=0 $1 2>&1) 
dur=${dur%.*} #vid duration rounded in secs
start=$(( dur / 4 )) #1st block start
nameID="${1##*/}"
nameID="${nameID%%.*}"
dstFolder="/tmp/$nameID"
mkdir -p $dstFolder 

blocksN=3
blkFrames=4			  #totNum of frames=blkFrames * blocksN
srcSampling=0.3
srcSamplingDistSec=20 #1/srcSampling * blkFrames < srcSamplingDistSec ==> ensure sampled frames's time monotonic
outFps=2
seekCmd="-ss"
#SIMPLE NON HWACCELERATED
#ffmpeg -ss $start -i $1 -vf "scale=$res" -r srcSampling $dstFolder/out.gif
#if not enough time try to reconfig to save time
if [ $(( start + (srcSamplingDistSec * blocksN) )) -gt $dur ];then #try get 1!
		srcSampling=1; blkFrames=$((blocksN*blkFrames)); blocksN=1;start=-$blkFrames;seekCmd="-sseof"
		echo -e '\033[0;31m' $(( start + (srcSamplingDistSec * blocksN) ))  $dur -short $1 '\033[0m' #red print of short vid
fi 

for (( i=0; i<$blocksN; i+=1));do
	#extract the frames using thumbnail_cuda also resizing the video stream to 300x300
	s=$(( start + (i* srcSamplingDistSec) ))
	~/ffmpeg/bin/nv/ffmpeg_g -hide_banner -loglevel error -y -hwaccel cuvid -c:v h264_cuvid -resize 300x300 $seekCmd $s -i $1 -vf	thumbnail_cuda=2,hwdownload,format=nv12 \
		-vframes $blkFrames -r $srcSampling  $dstFolder/frame$i%02d.jpg &
done
wait 
#merge extracted frames with desired speed
ffmpeg  -hide_banner -loglevel error  -y  -framerate $outFps -pattern_type glob   -i "$dstFolder/*.jpg"   -r $outFps     $dstFolder/$nameID.gif && rm $dstFolder/*jpg
