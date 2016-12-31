# autospeed

######Lua script for [mpv](https://mpv.io/) to adjust monitor refresh rate and video speed for almost 1:1 playback.

--------------

#####Notes:

* This script is for *nix operating systems. [See here for the Microsoft Windows version](https://github.com/kevinlekiller/mpv_scripts/tree/master/autospeedwin).

* Can use (recommended) [xrandr](http://www.x.org/wiki/Projects/XRandR/) To set your monitor refresh rate closer to the video playback speed based on which refresh rates your monitor supports for the current resolution.

* By default mpv will adjust the audio pitch to match the speed difference. You can read the [mpv manual](http://mpv.io/manual/master/#options-audio-pitch-correction) for more information on this.

* Works better with mpv's [`--video-sync=display-resample`](https://mpv.io/manual/master/#options-video-sync)  
If using mpv's [`--video-sync=display-resample`](https://mpv.io/manual/master/#options-video-sync), do not use `autospeed-speed=true`  
If you have issues with mpv's [`--video-sync=display-resample`](https://mpv.io/manual/master/#options-video-sync), you can use `--video-sync=audio` and `autospeed-speed=true`, which still produces acceptable results.  

--------------

#####Basic Description:

Changes the monitor refresh rate to be closer to the video fps, then sets
the speed of the video to be closer to the monitor refresh rate.

Lower resource usage than using interpolation.

--------------

#####Script options:

The script can read options from mpv's [--script-opts](http://mpv.io/manual/master/#options-script-opts) option.

Valid options (and examples):

    autospeed-xrandr=true
        Default: false
        true/false - Use xrandr.
        Xrandr will be used to change the refresh rate of your monitor based on available
        refresh rates for the current resolution.
    autospeed-speed=false
        Default: false
        true/false - Adjust speed of the video?
        If set to true, the mpv speed setting will be changed based on the video
        fps and display refresh rate.
        Do not use this with mpv's --video-sync=display-resample
    autospeed-display=auto
        Default: auto
        If set to "auto", the primary connected monitor will be used with xrandr.
        If set to your monitors name, tell xrandr to use the specified display
        when changing the refresh rate.
        Find your monitor name using this command: xrandr | grep -Poi '^.+connected'
        It should look something like "HDMI-0".
    autospeed-exitmode=auto
        Default: auto
        Sets the refresh rate of the monitor when exiting mpv.
        autospeed-exitmode=auto
            Sets the monitor refresh rate back to the original refresh rate when mpv started.
        autospeed-exitmode=false
            Does not change the monitor refresh rate when exiting mpv.
            If you do not set autospeed-exitmode then this is the default.
        autospeed-exitmode=0x123
            This will set a specified mode when exiting.
            Find a mode using this command: xrandr --verbose
            For example, "0x48" in the following string is the
            mode: 1920x1080 (0x48) 148.500MHz +HSync +VSync *current +preferred
    autospeed-interlaced=false
        Default: false
        true/false - If set to false, the script will ignore a refresh rate if
                     it is interlaced.
        autospeed-interlaced=false Do not use interlaced modes.
        autospeed-interlaced=true  Use interlaced modes (and non-interlaced modes).
    autospeed-mblacklist=false
        Default: false
        Modes in this list will be ignored. Find modes with xrandr --verbose
        If more than one mode is specified, seperate them by semicolon.
        Examples:
            autospeed-mblacklist="0x128;0x2fa"
            autospeed-mblacklist=0x38d
    autospeed-minspeed=0.92
        Default: 0.9
        Number - Minimum allowable speed to play video at.
        Does not change mpv's speed setting if the calculated speed is lower than this.
        This is to prevent the video looking like it is in slow motion.
        A value of 0.9 allows playing the video at minimum, 10% slower.
    autospeed-maxspeed=1.08
        Default: 1.1
        Number - Maximum allowable speed to play video at.
        Does not change mpv's speed setting if the calculated speed is higher than this.
        This is to prevent the video looking like it is in fast forward.
        A value of 1.1 allows playing the video at maximum, 10% faster.
    autospeed-osd=true
        Default: false
        true/false - Enable OSD.
        This enables/disables the other autospeed-osd settings.
    autospeed-osdtime=15
        Default: 10
        Number - How many seconds the OSD will be shown.
    autospeed-osdkey="ctrl+y"
        Default: y
        This follows the same standard as mpv's input.conf for keybindgs.
        Key to press to show the OSD.
        Pressing this key will display autospeed information on mpv's OSD.
    autospeed-estfps=false
        Default: false
        true/false - Calculate/change speed if a video has a variable frame rate 
                     at the cost of higher CPU usage.
        If a video has a variable frame rate (fps),
        calculate / set the mpv speed based on the current video frame rate.
        This option will do nothing for most videos because, only few of them have variable fps.
        For example, most (all?) bluray videos have variable frame rates.
        Since the speed calulation must be done every time the video fps changes,
        this increases CPU load slightly.
        On my computer, mpv goes from ~10% to ~16% CPU usage with this option enabled.
    autospeed-spause=4
        Default: false
        true/false - Pause video while switching display modes.
                     true:  This will pause the video before and after switching the mode.
                     false: Disables this option.
        Number     - This enables the pause like true and sleeps for this amount of seconds.
                     If bigger than 0: After switching the mode, we will wait this amount
                     of seconds before unpausing the video.
                     If set to 0:      It disables the option, like false.
        Before switching the display mode (refresh rate), pause the video, unpause after
        it is switched. This can be used if you don't want to miss
        some of the video while your display is blank (my display is blank for ~5 seconds
        while switching modes).
    
    Examples:
        Setting the options at the command line:
            mpv file.mkv --script-opts=autospeed-xrandr=true,autospeed-speed=false,autospeed-minspeed=0.8
        Setting the options in ~/.config/mpv/mpv.conf :
            script-opts=autospeed-xrandr=true,autospeed-speed=false,autospeed-display=auto,autospeed-exitmode=auto,autospeed-minspeed=0.9,autospeed-maxspeed=1.1,autospeed-osd=true,autospeed-osdtime=10,autospeed-osdkey=y,autospeed-estfps=true,autospeed-spause=4

--------------

#####Installation:

Put the file inside the mpv/scripts folder, see the [mpv man page](https://github.com/mpv-player/mpv/blob/master/DOCS/man/mpv.rst#files) for the correct path, by default this should be `~/.config/mpv/scripts/`.


Download link:  
[autospeed.lua](https://raw.githubusercontent.com/kevinlekiller/mpv_scripts/master/autospeed/autospeed.lua)  

You can use programs like `wget` or `curl` to download from the command line.

For example, to download using curl:

`mkdir -p ~/.config/mpv/scripts && curl -o ~/.config/mpv/scripts/autospeed.lua https://raw.githubusercontent.com/kevinlekiller/mpv_scripts/master/autospeed/autospeed.lua`

--------------

#####Detailed Description:

This is roughly the order of events that happen:

Fetches your monitor refresh rate and video fps from mpv.

If you have xrandr enabled in the config file:

The supported modes for your monitor and resolution will be parsed using  
your display name (`autospeed-display`), your monitor's  
refresh rate will be changed to the most appropriate one based on  
the video speed thresholds (`autospeed-minspeed` and `autospeed-maxspeed`).

The speed is then calculated based on the video fps / display refresh rate.

If the speed is within range of the thresholds (`autospeed-minspeed` and `autospeed-maxspeed`),  
the mpv speed property is set.

When mpv exits, the mode will be set to a user specified mode (`autospeed-exitmode`).

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
