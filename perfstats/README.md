# perfstats

[mpv](https://mpv.io/) script for displaying statistics on dropped frames and video output performance.

Default keybinding is ` (the key under Escape on US keyboards).

    Frames:
        Dropped:    https://mpv.io/manual/master/#command-interface-decoder-frame-drop-count
        VO Dropped: https://mpv.io/manual/master/#command-interface-frame-drop-count
        Mistimed:   https://mpv.io/manual/master/#command-interface-mistimed-frame-count
        VO Delayed: https://mpv.io/manual/master/#command-interface-vo-delayed-frame-count

    Video output performance (does not seem to function with the angle backend):
        upload:  https://mpv.io/manual/master/#command-interface-upload
        render:  https://mpv.io/manual/master/#command-interface-render
        present: https://mpv.io/manual/master/#command-interface-present
        Total:   Combined amount of time of the above 3 (this should stay lower than
                 your display frame time, if it goes higher, you will want to tweak
                 mpv settings, however this probably depends on the fps of the video,
                 if the video is 30fps and the display is 60hz, then you probably get
                 2x more time to work on a frame since the same frame is displayed twice).

        last:    How much time it took for the last frame; https://mpv.io/manual/master/#command-interface-last
        average: How much time it took for the last few frames; https://mpv.io/manual/master/#command-interface-avg
                 Note: Wait 5 to 10 seconds at the start of a video for the average to settle.
        peak:    The highest amount of time it took to display a frame; https://mpv.io/manual/master/#command-interface-peak

    Refresh rate:
        How many times per second your monitor displays a new frame.
    Frame time:
        This is how much time your computer monitor spends displaying a single frame.

    Frame rate:
        Reported video fps by mpv.
    Frame time:
        How long in time a single frame of the video is.

    Note: All time measurements are in microseconds.

Download link for the script: https://raw.githubusercontent.com/kevinlekiller/mpv_scripts/master/perfstats/perfstats.lua

----
#License:

https://github.com/kevinlekiller/mpv_scripts/blob/master/LICENSE
