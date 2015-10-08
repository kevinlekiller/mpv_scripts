# mixer

Remix audio based on audio channels of current playing track.
By default this will mix to stereo.
Change "map" variables in the script to alter number of output channels / input volumes.
Uses mpv's "pan" filter http://mpv.io/manual/master/#audio-filters-pan
Uses/requires ffprobe to detect current audio channel layout.

Default keybinds are ' to print to OSD, ; to disable/enable the script.

Download link for the script: https://raw.githubusercontent.com/kevinlekiller/mpv_scripts/master/mixer/mixer.lua
