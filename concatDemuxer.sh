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

#concat demuxer wrap script, with both reencodingless and reencode with specific demuxer's filter reencoding
#filter reencoding work well, espcially with h264_nvenc (GPU) reencodnig. Some group of vids may concat better with this one

usage="usage < concatListFile || GEN_CONCAT_LIST (find *mp4 files recursivelly) , [outFpath], [REENCODE FLAG (dflt FALSE)] >"
config="config override with env vars:: FFMPEG=ffmpeg build target path;SUPPLMNT_OPT= trailing option to cmd[dflt -an] \n dflts: $CONCAT_LIST $OUT_FN [$AUDIO]  $ffmpegBuild"
##args andle
#(gen) concat list
if 	[ ! $1 ];then echo -e $usage \n $config  ; exit 1;fi
CONCAT_LIST=$1
#self generation of concat.list
if	[ "$1" == "GEN_CONCAT_LIST" ];then find -name "*mp4" -printf "file %p\n" | shuf > $CONCAT_LIST ;fi
#override dflt out fname
OUT_FN="out.mp4"
if [ $2 ];then OUT_FN=$2;fi
#(r)encoding
REECODE=0
if [ $3 ];then REENCODE=1;fi
#en override opts
ffmpegBuild="/home/andysnake/ffmpeg/bin/nv/ffmpeg_g"
if [ $FFMPEG ];then ffmpegBuild=$FFMPEG;fi
Suplmnt_opt="avoid_negative_ts make_zero" #"-fflags +genpts "
if [ $SUPPLMNT_OPT ];then Supplmnt_opt+=$SUPPLMNT_OPT; fi

###CONCATENATION###
if [ $REENCODE == 1 ];then	#SMART REENCODE -> limited overhead
	eval ${ffmpegBuild}  -f concat -safe 0  -segment_time_metadata 1 -i $CONCAT_LIST -vf select=concatdec_select -af aselect=concatdec_select,aresample=async=1 -c:v h264_nvenc -c:a aac -ac 1  $Supplmnt_opt  $OUT_FN
else				#NO REENCODE,Stream copy -> min overhead, max quality.	NB possible glitches /Non monotonous PTS if nn omogeneous vids
	eval ${ffmpegBuild}  -f concat -safe 0 -i $CONCAT_LIST -c:v copy $Supplmnt_opt  $OUT_FN	#RE ENCODE VIDEO IN CONCATENATION
fi
