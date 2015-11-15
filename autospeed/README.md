# autospeed

######Lua script for mpv to adjust monitor refresh rate and video speed for almost 1:1 playback.

--------------

#####Notes:

* Should work on all operating systems supported by mpv.

* Can use (recommended) [xrandr](http://www.x.org/wiki/Projects/XRandR/) (*nix only) To set your monitor refresh rate closer to the video playback speed based on which refresh rates your monitor supports for the current resolution.

* By default mpv will adjust the audio pitch to match the speed difference. You can read the [mpv manual](http://mpv.io/manual/master/#options-audio-pitch-correction) for more information on this.

--------------

#####Basic Description:

Optionally changes the monitor refresh rate to be closer to the video fps, then sets
the speed of the video to be closer to the monitor refresh rate.

Lower resource usage than using interpolation.

--------------

#####Script options:

The script can read options from mpv's [--script-opts](http://mpv.io/manual/master/#options-script-opts) option.

Valid options (and examples):

    autospeed-xrandr=false     true/false - Use xrandr.
        Xrandr will be used to change the refresh rate of your monitor based on available
        refresh rates for the current resolution.
    autospeed-display=HDMI1
        Tell xrandr to use the specified display when changing the refresh
        rate, find these using this command: xrandr | grep -Poi '^.+connected'
    autospeed-exitmode=0x48
        Revert to this mode when exiting mpv. Find using this command: xrandr --verbose
        For example, "0x48" in the following string is the
        mode: 1920x1080 (0x48) 148.500MHz +HSync +VSync *current +preferred
    autospeed-minspeed=0.9     Number - Minimum allowable speed to play video at.
        Do not change speed setting if the calculated speed is lower than this.
        This is to prevent the video looking like it is in slow motion.
    autospeed-maxspeed=1.1     Number - Maximum allowable speed to play video at.
        Do not change speed setting if the calculated speed is higher than this.
        This is to prevent the video looking like it is in fast forward.
    autospeed-osd=false        true/false - Enable OSD.
        This enables/disables the other autospeed-osd settings.
    autospeed-osdtime=10       Number     - How many seconds the OSD will be shown.
        Self-explanatory.
    autospeed-osdkey=y                    - Key to press to show the OSD.
        Pressing this key will display the autospeed OSD.
    autospeed-estfps=false     true/false - Calculate/change speed if a video has a variable fps
                                            at the cost of higher CPU usage
        If a video has a variable fps (frames per second),
        calculate / set the mpv speed based on the current video fps.
        This option will do nothing for most because, because only few videos have variable fps.
        Because the speed calulation must be done every time the video fps changes,
        this increases CPU load slightly.
        On my CPU, mpv goes from ~10% to ~16% with this option enabled.
    
    Examples:
        Setting the options at the command line:
            mpv file.mkv --script-opts=autospeed-xrandr=true,autospeed-minspeed=0.8
        Setting the options in ~/mpv/mpv.conf:
            script-opts=autospeed-xrandr=true,autospeed-display=HDMI1,autospeed-exitmode=0x48,autospeed-minspeed=0.9,autospeed-maxspeed=1.1,autospeed-osd=true,autospeed-osdtime=10,autospeed-osdkey=y,autospeed-estfps=true

--------------

#####Installation:

Put the file inside the mpv/scripts folder, see the [mpv man page](https://github.com/mpv-player/mpv/blob/master/DOCS/man/mpv.rst#files) for the correct path.


Download link:  
[autospeed.lua](https://raw.githubusercontent.com/kevinlekiller/mpv_scripts/master/autospeed/autospeed.lua)  

You can use programs like `wget` or `curl` to download from the command line.

For example, to download using curl on *nix:

`mkdir -p ~/.mpv/scripts && curl -o ~/.mpv/scripts/autospeed.lua https://raw.githubusercontent.com/kevinlekiller/mpv_scripts/master/autospeed/autospeed.lua`

--------------

#####Detailed Description:

This is roughly the order of events that happen:

Fetches your monitor refresh rate and video fps from mpv.

If you have xrandr enabled in the config file:

The supported modes for your monitor and resolution will be  
parsed using your display name (set using the --script-opts mentioned above), your monitor will be over or under clocked to the most appropriate refresh rate based on  
the video speed thresholds (set using the --script-opts mentioned above).

The speed is then calculated based on the video fps / display refresh rate.

If the speed is within range of the settings specified in the config file, the mpv speed property is set.

When mpv exits, the mode will be set to a user specified mode (set using the --script-opts mentioned above)

--------------

#####Examples:

* >
The display supports 72hz.  
The video is 23.97602397602398fps.  
The display is currently 60hz.  
The display is set to 72hz.  
The mpv speed setting is set to 1.001.  
The video now plays at 24fps (23.97602397602398fps * 1.001 = 24).  
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
