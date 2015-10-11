# autospeed

######Lua script for mpv to adjust monitor refresh rate and video speed for almost 1:1 playback.

--------------

#####Notes:

* Should work on all operating systems supported by mpv.

* Can use (recommended) [xrandr](http://www.x.org/wiki/Projects/XRandR/) (*nix only)

* Can use (recommended) [ffprobe](https://www.ffmpeg.org/download.html) to get a more accurate video frame rate. When using the "get_property" command in mpv, the numbers are rounded or truncated (instead of returning 23.97602397602398, it returns 23.976025), 
ffprobe can be used to get the fps instead to calculate a more accurate speed setting.

* By default mpv will adjust the audio pitch to match the speed difference. You can read the [mpv manual](http://mpv.io/manual/master/#options-audio-pitch-correction) for more information on this.

--------------

#####Basic Description:

Optionally over or under clocks the monitor refresh rate to be closer to the video fps, then sets
the speed of the video to be closer to the monitor refresh rate.

Lower resource usage than using interpolation.

--------------

#####Installation:

Put the 2 files inside the mpv/scripts folder, see the [mpv man page](https://github.com/mpv-player/mpv/blob/master/DOCS/man/mpv.rst#files) for the correct path.

Rename `auto_speed_config.lua.example` to `auto_speed_config.lua`, edit the options.

Download links:  
[auto_speed.lua](https://raw.githubusercontent.com/kevinlekiller/mpv_scripts/master/autospeed2/auto_speed.lua)  
[auto_speed_config.lua.example](https://raw.githubusercontent.com/kevinlekiller/mpv_scripts/master/autospeed2/auto_speed_config.lua.example)

--------------

#####Detailed Description:

This is roughly the order of events that happen:

Fetches your monitor refresh rate and video fps from mpv.

If you have xrandr enabled in the config file:

The supported modes for your monitor and resolution (specified in the config file) will be  
parsed, your monitor will be over or under clocked to the most appropriate refresh rate based on  
the video speed thresholds (specified in the config file).

Accurate monitor refresh rates will be calculated from the modelines of the found xrandr modes, we
will use this instead of the refresh rate given by mpv.

If you have ffprobe enabled in the config file:

If the video is local, ffprobe will be executed on the video file, a more accurate fps will 
be calculated from this. Some of the ffprobe fps's I've found are added to the script so we
don't have to call ffprobe for those.  
If the video is not local, we can still use those known ffprobe fps values.

The speed is then calculated based on the video fps / display refresh rate.

If the speed is within range of the settings specified in the config file, the mpv speed property is set.

The OSD string is set/printed, based on settings in the config file.

When mpv exits xrandr is called to set the mode to the one specified in the config file.

--------------

#####Examples:

* >
The display supports 72hz.  
The video is (ffprobe: 24000 / 1001 aka 23.97602397602398fps, or mpv: 23.976025).  
The display is currently 60hz.  
The display is set to 72hz.  
The mpv speed setting is set to 1.001.  
The video now plays at 24fps (ffprobe: 23.97602397602398fps * 1.001 = 24 or mpv: 23.976025 * 1.001 = 24.000001025fps).  
Every frame is repeated 3 times, so 1:1 playback.

* >  
The display supports 50hz.  
The video is 24.95fps.  
The display is currently 60hz.  
The display is set to 50hz.  
The mpv speed setting is set to 1.002004008016032.  
The video now plays at 25fps.  

* >  
The display supports 60hz.  
The display is currently 144hz.  
The video is 60fps.  
The display is set to 60hz.

--------------

#####License:

GPL V2  
See [LICENSE](https://github.com/kevinlekiller/mpv_scripts/blob/master/LICENSE)
