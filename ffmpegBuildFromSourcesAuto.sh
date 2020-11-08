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

#Written by Andrea Di Iorio
#based on  ffmpeg guide at https://trac.ffmpeg.org/wiki/CompilationGuide/Centos
#minimal build for what I need... x264 aac/mp3/opus :)
#work on aws ec2 rad hat based AMI

set -e 			#stop on failure line
#all depencies mentioned at https://trac.ffmpeg.org/wiki/CompilationGuide/Centos ... for sure too mutch
sudo yum install -y git make autoconf automake bzip2 bzip2-devel cmake freetype-devel gcc gcc-c++ git libtool make mercurial pkgconfig zlib-devel curl
mkdir ffmpeg_sources ffmpeg_build bin
cd ffmpeg_sources
SRC=$(realpath .)		#SOURCES
H=$(realpath ..)		#HOME
MAKE_CONCURRENCY=7		#concurrency in make process
#downloads
# first block of building jobs
git clone --depth=1 https://code.videolan.org/videolan/x264.git x264_src		&
curl -O -L https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.bz2	&
curl -O -L https://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz		&
wait
#concurrent download ended just after x264
git clone --depth=1 https://git.ffmpeg.org/ffmpeg.git ffmpeg 				&
git clone --depth 1 https://github.com/mstorsjo/fdk-aac aac_src				&
curl -O -L https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz 	&
curl -O -L https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz			&

#yasm
echo -e  "\n\n\n\nYASM"
cd $SRC
tar xzvf yasm-1.3.0.tar.gz
cd yasm-1.3.0
./configure --prefix="$H/ffmpeg_build" --bindir="$H/bin"
make -j $MAKE_CONCURRENCY && make install

#nasm
cd $SRC
tar xjvf nasm-2.14.02.tar.bz2
cd nasm-2.14.02
./autogen.sh
./configure --prefix="$H/ffmpeg_build" --bindir="$H/bin"
make -j $MAKE_CONCURRENCY && make install
PATH=$H/bin/:$PATH

#libx264
echo -e  "\n\n\n\nlibx264"
cd $SRC/x264_src
PKG_CONFIG_PATH="$H/ffmpeg_build/lib/pkgconfig" ./configure --prefix="$H/ffmpeg_build" --bindir="$H/bin" --enable-static
make -j $MAKE_CONCURRENCY && make install

wait			#end concurrent downloads
#lib-aac
echo -e  "\n\n\n\nlib-aac"
cd $SRC/aac_src
autoreconf -fiv
./configure --prefix="$H/ffmpeg_build" --disable-shared
make -j $MAKE_CONCURRENCY && make install

#libmp3lame
echo -e  "\n\n\n\nlibmp3lame"
cd $SRC
tar xzvf lame-3.100.tar.gz
cd lame-3.100
./configure --prefix="$H/ffmpeg_build" --bindir="$H/bin" --disable-shared --enable-nasm
make -j $MAKE_CONCURRENCY && make install

#libopus
echo -e  "\n\n\n\nlibopus"
cd $SRC
tar xzvf opus-1.3.1.tar.gz
cd opus-1.3.1
./configure --prefix="$H/ffmpeg_build" --disable-shared
make -j $MAKE_CONCURRENCY && make install
#FFMPEG!
echo -e  "\n\n\n\nFFMPEG FINALLY"
cd $SRC/ffmpeg
PATH="$H/bin:$PATH" PKG_CONFIG_PATH="$H/ffmpeg_build/lib/pkgconfig" ./configure \
  --prefix="$H/ffmpeg_build" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$H/ffmpeg_build/include" \
  --extra-ldflags="-L$H/ffmpeg_build/lib" \
  --extra-libs=-lpthread \
  --extra-libs=-lm \
  --bindir="$H/bin" \
  --enable-gpl \
  --enable-libfdk_aac \
  --enable-libfreetype \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libx264 \
  --enable-nonfree
make -j $MAKE_CONCURRENCY  && make install 
echo -e "\n\n\n\n\n\n DONE :)"
