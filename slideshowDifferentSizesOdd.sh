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

WIDTH=960
HEIGHT=1080
FRAMERATE=2
slideShowOnTheFly(){
	ffmpeg -framerate $FRAMERATE -pattern_type glob -i '*.jpg' -i a.opus -c:v libx264 -pix_fmt yuv420p  -vf "scale=$WIDTH:$HEIGHT:force_original_aspect_ratio=decrease,pad=$WIDTH:$HEIGHT:(ow-iw)/2:(oh-ih)/2,setsar=1" -c:a copy -shortest -f matroska - | ffplay -
}
slideShowSave(){
	ffmpeg -framerate $FRAMERATE -pattern_type glob -i '*.jpg' -i a.opus -c:v libx264 -pix_fmt yuv420p  -vf "scale=$WIDTH:$HEIGHT:force_original_aspect_ratio=decrease,pad=$WIDTH:$HEIGHT:(ow-iw)/2:(oh-ih)/2,setsar=1" -c:a aac -shortest out.mp4
}
