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

#####Script options:

The script can read options from mpv's [--script-opts](http://mpv.io/manual/master/#options-script-opts) option.

Valid options are:

    autospeed-xrandr=false     true/false - Use xrandr.

Xrandr will be used to change the refresh rate of your monitor and find the refresh rate of your monitor using the modeline.

    autospeed-ffprobe=false    true/false - Use ffprobe.
Ffprobe will be used to fetch the video frame rate.

    autospeed-display=HDMI1
Tell xrandr to use the specified display when changing the refresh rate, find these using this command: `xrandr | grep -Poi '^.+connected'`

    autospeed-exitmode=0x48
Revert to this mode when exiting mpv. Find using this command `xrandr --verbose`
For example, "0x48" in the following string is the mode: 1920x1080 (0x48) 148.500MHz +HSync +VSync *current +preferred

    autospeed-minspeed=0.9     Number - Minimum allowable speed to play video at.
Do not change speed setting if the calculated speed is lower than this.
This is to prevent the video looking like it is in slow motion.

    autospeed-maxspeed=1.1     Number -Maximum allowable speed to play video at.
Do not change speed setting if the calculated speed is higher than this.
This is to prevent the video looking like it is in fast forward.

    autospeed-osd=false         true/false - Enable OSD.
This enables/disables the other autospeed-osd settings.

    autospeed-osdstart=false   true/false - Show OSD output when a video starts.
When a new video is played, the autospeed OSD will be displayed.

    autospeed-osdtime=10       Number     - How many seconds the OSD will be shown.


    autospeed-osdkey=y                    - Key to press to show the OSD.
Pressing this key will display the autospeed OSD.

    autospeed-logfps=false     true/false - Log non known ffprobe fps's to ~/mpv_unk_fps.log
If a ffprobe fps is not in [this list](https://github.com/kevinlekiller/mpv_scripts/blob/master/autospeed2/auto_speed.lua#L45), log it, so you or I can add it to the list, which prevents calling ffprobe and speeds up the script.

Example in `mpv.conf` : script-opts=autospeed-xrandr=true,autospeed-ffprobe=true,autospeed-display=HDMI1,autospeed-exitmode=0x48,autospeed-minspeed=0.9,autospeed-maxspeed=1.1,autospeed-osd=true,autospeed-osdstart=false,autospeed-osdtime=10,autospeed-osdkey=y,autospeed-logfps=false

--------------

#####Installation:

Put the file inside the mpv/scripts folder, see the [mpv man page](https://github.com/mpv-player/mpv/blob/master/DOCS/man/mpv.rst#files) for the correct path.


Download link:  
[auto_speed.lua](https://raw.githubusercontent.com/kevinlekiller/mpv_scripts/master/autospeed2/auto_speed.lua)  

You can use programs like `wget` or `curl` to download from the command line.

--------------

#####Detailed Description:

This is roughly the order of events that happen:

Fetches your monitor refresh rate and video fps from mpv.

If you have xrandr enabled in the config file:

The supported modes for your monitor and resolution will be  
parsed using your display name (changed using the --script-opts mentioned above), your monitor will be over or under clocked to the most appropriate refresh rate based on  
the video speed thresholds (changed using the --script-opts mentioned above).

Accurate monitor refresh rates will be calculated from the modelines of the found xrandr modes, we
will use this instead of the refresh rate given by mpv.

If you have ffprobe enabled in the config file:

If the video is local, ffprobe will be executed on the video file, a more accurate fps will 
be calculated from this. Some of the ffprobe fps's I've found are added to the script so we
don't have to call ffprobe for those.  
If the video is not local, we can still use those known ffprobe fps values.

The speed is then calculated based on the video fps / display refresh rate.

If the speed is within range of the settings specified in the config file, the mpv speed property is set.

The OSD string is set/printed (configured using the --script-opts mentioned above).

If specified with the --script-opts option, when mpv exits xrandr is called to set that exit mode.

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
