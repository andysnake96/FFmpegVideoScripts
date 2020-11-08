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

#identify $1 $2 $3 $4
echo "configurable overlay with env exportable vars: W H OVERLAY_SIZE (either 2x2(dlft) 3x3) and offset from botton OFFB (dflt 0)"
echo "usage: vids inputs [outFname (dflt output.mp4)]"
w=400
h=225
offb=0
offl=0		#TODO NOT DONE. .. sensitive image loss :(
if [[ $W ]];then w=$W;fi
if [[ $H ]];then h=$H;fi
if [[ $OFFB ]];then offb=$OFFB;fi
if [[ $OFFL ]];then offl=$OFFL;fi
ffmpegBuildPath="/home/andysnake/ffmpeg/bin/ffmpeg_nv"
encoder="h264_nvenc"
outName="output.mp4"
#LOGLEVEL="-loglevel debug"

if [[ ! $OVERLAY_SIZE ]];then OVERLAY_SIZE="2x2";fi #dflt overlay size
#timeStamp="$(date --iso-8601=minutes | perl -pe 's/[^0-9]+//g')"

if [[ $OVERLAY_SIZE == "2x2" ]];then
	if [[ $5 ]];then outName=$5;fi
	/home/andysnake/ffmpeg/bin/ffmpeg_nv -y $LOGLEVEL  -hide_banner -i $1 -i $2 -i $3 -i $4  -filter_complex " \
		nullsrc=size=$(( $w * 2))x$(( ($h - $offb) * 2)) 		[base];\
		[base][0:v] overlay=shortest=1 					[tmp1];\
		[tmp1][1:v] overlay=shortest=1:x=$w				[tmp2];\
		[tmp2][2:v] overlay=shortest=1:y=$(( $h - $offb ))		[tmp3];\
		[tmp3][3:v] overlay=shortest=1:x=$w:y=$(( $h - $offb ))			"\
		-c:v $encoder $outName
elif [[ $OVERLAY_SIZE == "3x3" ]];then
	if [[ ${10} ]];then outName=${10};fi
	/home/andysnake/ffmpeg/bin/ffmpeg_nv -y $LOGLEVEL -hide_banner -i $1 -i $2 -i $3 -i $4 -i $5 -i $6 -i $7  -i $8 -i $9 -filter_complex " \
		nullsrc=size=$(( $w * 3))x$(( ($h - $offb ) * 3 ))			[base];\
		[base][0:v] overlay=shortest=1:						[tmp1];\
		[tmp1][1:v] overlay=shortest=1:x=$(($w - 40))				[tmp2];\
		[tmp2][2:v] overlay=shortest=1:x=$((2 * $w))				[tmp3];\
		[tmp3][3:v] overlay=shortest=1:y=$(($h - $offb))			[tmp4];\
		[tmp4][4:v] overlay=shortest=1:x=$w:y=$(( $h - $offb ))			[tmp5];\
		[tmp5][5:v] overlay=shortest=1:x=$((2*$w)):y=$(($h - $offb))		[tmp6];\
		[tmp6][6:v] overlay=shortest=1:y=$((2 * ($h - $offb)))			[tmp7];\
		[tmp7][7:v] overlay=shortest=1:x=$w:y=$((2* ($h - $offb)))		[tmp8];\
		[tmp8][8:v] overlay=shortest=1:x=$((2*$w)):y=$((2*($h - $offb)))		"\
		-c:v $encoder $outName
else
	echo "either 2x2 , 3x3 "
fi
