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

#various ffmpeg scripts as bash functions 

echo -e "ffmpeg video utilis\nenv variables usable:\tFFMPEG<- path to custom ffmpeg binary \t CONCURRENCY_LEV <- concurrency in some OPs"
NVIDIA_H264_ENCODE=" -c:v h264_nvenc -preset slow -coder vlc "
#NVIDIA_CUVID_DECODE="-vsync 0 -hwaccel cuvid -c:v h264_cuvid "
NVIDIA_CUVID_DECODE=" -hwaccel cuvid -c:v h264_cuvid "
VIDEO_ENCODE=$NVIDIA_H264_ENCODE
VIDEO_DECODE=$NVIDIA_CUVID_DECODE
DEFLT_FFMPEG_START_FLAGS=' -hide_banner -y -loglevel verbose '
concurrency_lev=4
if [[ $CONCURRENCY_LEV ]];then concurrency_lev=$CONCURRENCY_LEV;fi
echo -e "ENVIRON SETTABLE\n FFMPEG [= deflt target ffmpeg bin reachable from shell]\n VIDEO_ENCODE [= deflt nvidia h264 ]\n VIDEO_DECODE [=NVIDIA_CUVID_DECODE]"
echo -e "DEFLT_FFMPEG_START_FLAGS [=-hide_banner -y -loglevel 'verbose' ]\n"
if [[ ! $FFMPEG ]];then FFMPEG="~/ffmpeg/bin/nv/ffmpeg_g"; fi
#FFMPEG="${FFMPEG} ${DEFLT_FFMPEG_START_FLAGS}"
isVideoCorrupted(){
	#if ffprobe -loglevel warning $1; then 
	if ffmpeg -v error -i $1 -f null - >/dev/null;then
        	return 1;
       	 else 
			echo "ERR AT  $1"
			return 0;
	fi
}
genTumbrls(){
	#args videosListFile,seekTime,tumbrlSize,[output format]
	#will save in videosBaseDir tumbrls
	videosListFile=$1 	#find output like 
	tumbrlRes="500x500"
	tmbrlFormat="jpg"	#DOTLESS
	if [[ $2 ]];then tumbrlRes=$2;fi
	if [[ $3 ]];then tmbrlFormat=$3;fi
	if [[ $thumbnail_time ]];then 
		tumbrlTime=$thumbnail_time;
		#cat $videosListFile| xargs -n 1  echo "ffmpeg -ss $tumbrlTime -i $0  -vframes 1 -s $tumbrlRes -y %.$tmbrlFormat" >> $outBashScript
	else
		i=0
		for v in $(cat $videosListFile);do
			#if isVideoCorrupted $v;then continue;fi
			echo "tumbrl for $v "
			vidDuration=$(ffprobe -loglevel error -show_entries stream=duration -select_streams v:0 -of csv=p=0 $v 2>&1)
			vidDuration=${vidDuration%.*}
			tumbrlTime=$(( vidDuration / 2 ))
			eval $FFMPEG -ss $tumbrlTime -i $v  -vframes 1 -s $tumbrlRes -y $v.$tmbrlFormat || echo "err  $v"
		#if $(( ++i% concurrency_lev ==0));then wait;fi
		done;
	fi
}

genTumbrlsScript(){
	outBashScript="genTumbrls.sh"
	rm $outBashScript
	videosListFile=$1 	#find output like 
	tumbrlRes="300x300"
	tmbrlFormat="jpg"	#DOTLESS
	if [[ $2 ]];then tumbrlRes=$2;fi
	if [[ $3 ]];then tmbrlFormat=$3;fi
	if [[ $thumbnail_time ]];then 
		tumbrlTime=$thumbnail_time;
		cat $videosListFile| xargs  -n 1 -I % echo "$FFMPEG -hwaccel cuvid -c:v h264_cuvid -resize $tumbrlRes -ss $thumbnail_time -i %  -vf \"thumbnail_cuda=2,hwdownload,format=nv12\" -vframes 1  %.$tmbrlFormat" >> $outBashScript
	else
		i=0
		echo "extracting vid duration with ffprobe from $(cat $videosListFile | wc -l ) files "
		for v in $(cat $videosListFile);do
			#if isVideoCorrupted $v;then continue;fi
			vidDuration=$(ffprobe -loglevel error -show_entries stream=duration -select_streams v:0 -of csv=p=0 $v 2>&1)
			if [[ $vidDuration > 4 ]];then
				vidDuration=${vidDuration%.*}
				tumbrlTime=$(( vidDuration - 3 ))
			else
				vidDuration=6	#dflt duration
			fi
			#tumbrlTime=$(( vidDuration / 2 ))
			#~/ffmpeg/bin/nv/ffmpeg_g -hwaccel cuvid -c:v h264_cuvid -resize 300x300 -i  -vf "thumbnail_cuda=2,hwdownload,format=nv12" -vframes 1 frame.jpg
			echo "$FFMPEG -hwaccel cuvid -c:v h264_cuvid -resize $tumbrlRes -ss $tumbrlTime -i $v  -vf \"thumbnail_cuda=2,hwdownload,format=nv12\" -vframes 1  $v.$tmbrlFormat" >> $outBashScript
		#if $(( ++i% concurrency_lev ==0));then wait;fi
		done;
	fi

}
VIDEO_INFO_EXTENSION="info"
#extract videos infos in separated files  -- ffprobe output --- into calling dir
getVideosInfos(){
	#args videosListFile
	for f in $(cat $1);do
		ffprobe $f 2>&1 | grep "Video :"  > $f.$VIDEO_INFO_EXTENSION ;
		2>&1 ffprobe -loglevel error -show_entries stream=time_base -select_streams v:0 -of csv=p=0 $f 2>&1>> $f.$VIDEO_INFO_EXTENSION;
	done
}
genVideoMetadataJson(){
	#agen videos metadata in json from a given list of files in arg1
	cat $1 | xargs -n 1 -P $concurrency_lev  bash -c 'ffprobe -v quiet -print_format json -show_format -show_streams -show_error  $0 2>&1 > $0.json'
}
getVideoResolution(){

	ffprobe -hide_banner -loglevel error  -show_entries stream=width,height -of csv=p=x:p=0  $1
}
#SEEM SAME EFFECT FROM OUTPUTs DIFF
trimVideo(){
	#input input video,startTime,endTime,outFpath
	eval $FFMPEG -i $1 -filter_complex "[0:v]trim=$2:$3,setpts=PTS-STARTPTS[v0];[0:a]atrim=$2:$3,asetpts=PTS-STARTPTS[a0]" -map "[v0]" -map "[a0]" $4
}
trimVideoSST(){
	#input input video,startTime,endTime,outFpath
	eval $FFMPEG -i $1 -ss $2 -to $3 $4
}

auditRecursiveVideosMetadata(){
	#audit videos metadata recursivelly from source folder or the one given in arg1
	#will be printed: @fileName\nffprobe of fileName
	find $1 -iname "*mp4" | xargs -n 1 bash -c 'echo -e "\n @ $0\n" && ffprobe -loglevel verbose -hide_banner $0 ' 2>&1  
	echo wildcard names @
}
extractAudioStream(){
	#extract audio from input video in output video without re encoding
	#will be saved audio in inVideoFilePath.DEFAULT_OUT_FORMAT
	audioStreamFormat=$( getVideoMetadataJson $1 |& python3 -c $'import sys, json; print(json.load(sys.stdin)["streams"][1]["codec_name"])' )
	eval $FFMPEG -i $1 -vn -acodec copy $1.$audioStreamFormat
}
replaceAudio(){
	#replace audio (arg 2) in given video (arg 1 ) re encoding audio to aac or given format in arg 3 
	#re encoding format given as "-c:a ..."
	audioReencode=$( getVideoMetadataJson $2 |& python3 -c $'import sys, json; print(json.load(sys.stdin)["streams"][1]["codec_name"])' )
	if [[ $3 ]];then audioReencode=$3;fi
	eval $FFMPEG -i $1 -i $2 -c:v copy $audioReencode -map 0:v -map 1:a -shortest "audioSubstituted".$1
}
speedUpVideo_setpts(){
	#speed up video (arg 1 )with setpts filter with new PTS in 
	#target pts in terms of source pts has to be speecified as 0.25*PTS arg 2
	#[specify in arg 3 multiply factor of actual framrate ] otherwise ifnore -r option
	#optional audioReplace in arg 4
	#output as speededUp[framerateScaling]arg1
	newFrameRate=""	#overwritten just in case specified scaling factor for actual framerate
	if [[ $3 ]];then
		actualFrameRate=$(ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate $1 )
		newFrameRate="-r "$(( $actualFrameRate * $3 ))
	fi
	if [[ ! $4 ]];then
		eval $FFMPEG $VIDEO_DECODE -i $1 $newFrameRate  -filter:v "setpts="$2 $VIDEO_ENCODE -an speededUp$3$1
	else
		audioReencode=$( getVideoMetadataJson $2 |& python3 -c $'import sys, json; print(json.load(sys.stdin)["streams"][1]["codec_name"])' )
		eval $FFMPEG $VIDEO_DECODE -i $1 $newFrameRate -i $4 -filter:v "setpts="$2 $VIDEO_ENCODE $audioReencode -map 0:v -map 1:a -shortest speededUpAudioReplced$3$1
	fi

}
speedUpVideo_minterpolate(){
	#speedup video (arg 1) to given framerate (arg 2 ) even in rational format "a/b"
	#output written as speededUpMinterpolate$1 
	eval $FFMPEG -i $1  -filter:v "minterpolate='mi_mode=mci:mc_mode=aobmc:vsbmc=1:fps=$2'" $VIDEO_ENCODE speededUpMinterpolate$1
	##SW ENC DEC
	#eval $FFMPEG -i $1  -filter:v "minterpolate='mi_mode=mci:mc_mode=aobmc:vsbmc=1:fps=$2'" speededUpMinterpolate$1 
}

trailerize_select_vf(){
	set -x
	#build a trailer of videoa t arg1 as a set of segment at t % arg2 ==0 long arg3
	eval $FFMPEG $VIDEO_DECODE -i $1 \
	-vf 'select="lt(mod(t\,$2)\,$3)",setpts=N/FRAME_RATE/TB'  -af 'aselect="lt(mod(t\,$2)\,$3)",asetpts=N/SR/TB' $VIDEO_ENCODE  trailer_tmod_$2_for_$3_$1
	set +x
}

concatFilter(){
	#invoke concat filter, filtering all video.mp4 founded at arg1 saving result in arg2
	set +x
	trgDir=$1
	outFname=$2
	concatFilterCmd=$FFMPEG
	concatFilter_list=""
	i=0
	for f in $( find $trgDir -iname "*mp4" );do
		concatFilterCmd+=" -i "$f
		concatFilter_list+="[$i]"
		let $(( i++ ))
	done
	concatFilterCmd+=" -filter_complex \" "$concatFilter_list"concat=n=$i:v=1:a=1[vv][aa]\" -map \"[vv]\" -map \"[aa]\" $VIDEO_ENCODE $outFname "
	eval $concatFilterCmd
	set +x
}
trailerize_quick(){
	set -x
	#build a trailer of videoa t arg1 as a set of segment at t % arg2 ==0 long arg3 [arg 4 concurrency level ]
	#will be generated intermediate segments concurrently in a new dir in /tmp via an itermediate script generated
	#Options enable ReEncoding with REENCODE env Var 	#disable clean segments with DISABLE_CLEAN_SEGS_GENERATED, MAX_SEGS max num of segs to build (dflt 96)
	FFMPEG=~/ffmpeg/bin/ffmpeg_nv
	dstDirSegs="/tmp/""${1%%.*}/"
	mkdir $dstDirSegs
	rm $dstDirSegs/*
	vidDuration=$(ffprobe -loglevel error -show_entries stream=duration -select_streams v:0 -of csv=p=0 $1 2>&1)
	vidDuration=${vidDuration%.*}
	### generation segmenets stored in dstDirSegs
	concurrency=2
	#max_segs=196
	if [[ $MAX_SEGS ]];then max_segs=$MAX_SEGS;fi ##TODO ADD && i<$max_segs
	if [[ $4 ]];then concurrency=$4;fi	#override concurrency level
	for (( ss = $2,i=1 ; ss < ${vidDuration}   ; ss += $2,i++ ));do
		if [[ ! $REENCODE ]];then 
			echo $FFMPEG  -i $1 -ss $ss -t $3 -c copy -avoid_negative_ts 1 $dstDirSegs"_cut_"$ss"_"$3"_"$1   >> $dstDirSegs"cutBatch.sh"
		else  ### RE ENCODING
			echo "$FFMPEG $VIDEO_DECODE -ss $ss -t $3 -i $1 $VIDEO_ENCODE  $dstDirSegs"_cut_"$ss"_"$3"_"$1 &" >> $dstDirSegs"cutBatch.sh"
		fi
		# handle concurrent seg cuts
		if [ $(( i % concurrency )) == 0 ]; then
			echo "wait" >> $dstDirSegs"cutBatch.sh" ;	
		fi
	done
	bash $dstDirSegs"cutBatch.sh"
	##### merge up segements with concat demuxer 
	CONCAT_LIST=$dstDirSegs"concat.list"
	find $dstDirSegs -name "*mp4" -printf "file '%P'\n" | shuf > $CONCAT_LIST
	eval $FFMPEG -f concat -safe 0 -i $CONCAT_LIST -c:v copy trailer_tmod_$2_for_$3_$1
	
	#or concatFilter of generated segments
	###concatFilter $dstDirSegs trailer_tmod_$2_for_$3_$1
	
	if [[ ! $DISABLE_CLEAN_SEGS_GENERATED ]];then rm -r $dstDirSegs;fi
	set +x
}

concatDemuxerRecoursiveRnd(){
	#generate a concatenation of videos mp4 founded in each subdirs (must be compatible) into out file in arg 1
	find -name "*mp4" -printf "file %p\n"| shuf | eval $FFMPEG -protocol_whitelist file,pipe -f concat -safe 0 -i pipe: -c copy $1
}

concatDemuxerFFplayRnd(){
	#generate a concatenation of all file mp4 in current sub dirs on the fly to ffplay
	#of course each sub dirs  must contains compatible videos
	#find -name "*mp4" -printf "file %p\n"| shuf | eval $FFMPEG -protocol_whitelist file,pipe -f concat -safe 0 -i pipe: -c copy -f h264 - | ffplay -


	#speed up video (arg 1 )with setpts filter with new PTS in 
	#target pts in terms of source pts has to be speecified as 0.25*PTS arg 2
	#[specify in arg 3 multiply factor of actual framrate ] otherwise ifnore -r option
	#output as speededUp[framerateScaling]arg1
	newFrameRate=""	#overwritten just in case specified scaling factor for actual framerate
	if [[ $2 ]];then
		#actualFrameRate=$(ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate $1 )
		newFrameRate="-r "$(( $actualFrameRate * $2 ))
	fi
	find -name "*mp4" -printf "file %p\n"| shuf | eval $FFMPEG -protocol_whitelist file,pipe -f concat -safe 0 -i pipe: $newFrameRate  -filter:v "setpts="$1 $VIDEO_ENCODE -an -f h264 - | ffplay -
}
#DELOGO EXAMPLE : ffmpeg -i 9.mp4    -vf delogo=x=170:y=289:w=76:h=58 99.mp4
#CROP EXAMPLE BASIC : ffmpeg -i 99.mp4 -vf "crop=iw:375:0:262" coronaVTJLOGOLESS.mp4

#HW DECODING CUVID CROP + SCALING TO CUSTOM SIZE WITH NPP HW FILTER
#~/ffmpeg/bin/ffmpeg_nv -y -vsync 0 -hwaccel cuvid  -crop 0x40x0x0 -c:v h264_cuvid -i sofia.mp4 -ss 9 -vf scale_npp=852:480  -c:a copy -c:v h264_nvenc  -b:v 2M /tmp/output.mp4
##NEW VERSIONE OF ABOVE
# ~/ffmpeg/bin/nv/ffmpeg_g  -y -vsync 0 -hwaccel cuvid -hwaccel_output_format cuda -c:v h264_cuvid -ss 596 -t 5 -i 1080P_4000K_327964172.mp4  -vf scale_npp=640:480  -an -c:v h264_nvenc -avoid_negative_ts make_zero  /tmp/output.mp4
#GEN  thumbnail HW DECODING + FILTERING
#~/ffmpeg/bin/nv/ffmpeg_g -hwaccel cuvid -c:v h264_cuvid -resize 300x300 -i  -vf "thumbnail_cuda=2,hwdownload,format=nv12" -vframes 1 frame.jpg

#from 1 video -> crop a core portion ( take colums [315,830] )-> duplicate the stream, on 1 mirror horiz. then overlay the 2 streams; slowPreset 
#~/ffmpeg -i aa.mp4 -to 27.6 -filter_complex 'nullsrc=size=1028x720[base]; [0:v] crop=515:ih:315:0 [cropped] ; [cropped] split [tmp1][tmp2]; [tmp2] hflip [tmp2Mirr];[base][tmp1] overlay=shortest=1 [lx];[lx][tmp2Mirr] overlay=shortest=1:x=514' -preset veryslow -crf 11 /tmp/out.mp4

