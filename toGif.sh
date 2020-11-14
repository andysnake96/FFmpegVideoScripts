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
#try to get blkFrames every srcSamplingDistSec, picking in each block every 1/srcSampling secs, for blocksN blocks

#usage videoPath [FFMPEG, DISABLECUDA -> get the gif preview with standard reencoding ]
set -e 

ffmpeg=" ~/ffmpeg " #path to ffmpeg build (fine distro pkg bin, simply ffmpeg 
#ffmpeg="/bin/nv/ffmpeg_g"
if [ $FFMPEG ];then ffmpeg=$FFMPEG;fi #custom path
ffmpeg+=" -hide_banner -loglevel error -y "
dur=$(ffprobe -loglevel error -show_entries stream=duration -select_streams v:0 -of csv=p=0 $1 2>&1) 
dur=${dur%.*} #vid duration rounded in secs
start=$(( dur / 4 )) #1st block start
SMALL_VID=33

nameID="${1##*/}"
nameID="${nameID%%.*}"
#output in ./gif/nameID/nameID.gif (if CUDA also src tumbnails)
mkdir -p "gifs"
dstFolder=$(realpath gifs)/$nameID		#"/tmp/$nameID"
mkdir -p $dstFolder 

blocksN=4
blkFrames=24			  #totNum of frames=blkFrames * blocksN
srcSampling=0.3
srcSamplingDistSec=20 #1/srcSampling * blkFrames < srcSamplingDistSec ==> ensure sampled frames's time monotonic
outFps=2
seekCmd="-ss"

if [ $dur -lt $SMALL_VID ];then 	#reconfigure for small videos
		start=0 srcSampling=1.69 srcSamplingDistSec=4 srcSamplingDistSec=7 smallVid=1
fi
	
resize=" -resize 300x300 "  #cuda
if [ $DISABLECUDA ];then	#SIMPLE NON HWACCELERATED
	resize=" -vf scale=300x300 " #standard vid filter
	limitOutFrames="-vframes $(( $blkFrames * $blocksN ))"
	if [ $smallVid ];then limitOutFrames="" ;fi
	eval $ffmpeg -ss $start -i $1 $resize -r $srcSampling  $limitOutFrames $dstFolder/$nameID.gif
	exit $?
fi
#if not enough time try to reconfig to save time
if [ $(( start + (srcSamplingDistSec * blocksN) )) -gt $dur ];then #try get 1!
		srcSampling=1; blkFrames=$((blocksN*blkFrames)); blocksN=1;start=-$blkFrames;seekCmd="-sseof"
		echo -e '\033[0;31m' $(( start + (srcSamplingDistSec * blocksN) ))  $dur -short $1 '\033[0m' #red print of short vid
fi 

for (( i=0; i<$blocksN; i+=1));do
	#extract the frames using thumbnail_cuda also resizing the video stream to 300x300
	s=$(( start + (i* srcSamplingDistSec) ))
	eval $ffmpeg -hide_banner -loglevel error -y -hwaccel cuvid -c:v h264_cuvid $resize $seekCmd $s -i $1 -vf	thumbnail_cuda=2,hwdownload,format=nv12 \
		-vframes $blkFrames -r $srcSampling  $dstFolder/frame$i%02d.jpg &
done
wait 
#merge extracted frames with desired speed
eval $ffmpeg  -hide_banner -loglevel error  -y  -framerate $outFps -pattern_type glob   -i "$dstFolder/*.jpg"   -r $outFps     $dstFolder/$nameID.gif 
#rm $dstFolder/*jpg #remove src tumbnails
