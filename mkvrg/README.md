# mkvrg

When a file is loaded into [mpv](https://mpv.io/), this script will check if it's a local mkv file.

If the file is missing replaygain tags, it will scan them with bs1770gain, using --ebu, --samplepeak (much faster than --truepeak) and --range options.

While bs1770gain scans the file, the video is paused, the time it takes varies based on CPU power, the amount of audio channels / length of the audio track in the audio stream in the mkv file.

On a laptop with a Intel Core i3, a 2 hour 6 audio channels mkv file can take around 2 minutes, while a desktop with a Intel Core i7 can take about 25 seconds.

If bs1770gain succeeds, replaygain tags are applied using mkvpropedit.

mpv will then see the replaygain tags, and use them if you have the appropriate setting : https://mpv.io/manual/master/#audio-filters-volume

For example : `mpv --af=volume:replaygain-track:detach example.mkv`

This script is based on https://github.com/kevinlekiller/mkvrg which can be used outside of mpv, so you can scan your files before playing them with mpv, avoiding the pause.

----
#Options

You can enable mkvrg.lua OSD messages in mpv by passing the script-opts option mkvrg-osd=true, like this: `mpv --script-opts=mkvrg-osd=true example.mkv`

----
#Requirements:

These programs are required for this script to function:

bs1770gain : http://bs1770gain.sourceforge.net/

mkvpropedit : https://mkvtoolnix.download/

----
#Download

Download link for the script: https://raw.githubusercontent.com/kevinlekiller/mpv_scripts/master/mkvrg/mkvrg.lua

----
#License:

https://github.com/kevinlekiller/mpv_scripts/blob/master/LICENSE
