ffprobe -hide_banner -loglevel error -select_streams v:0 -show_entries stream=width,height,display_aspect_ratio,duration -of csv=p=x:p=0 $1
