# autoscaling

Disable video scaling if video is slightly smaller than window size.

For this script to function properly, you need to either be fullscreen or have the "no-border" option
in addition to disabling any options altering the size of the window when not in fullscreen (window-scale must be 1 for example),
otherwise the calculations may be off. If you do not have the "no-border" option enabled, the script
will still function when you enter fullscreen mode, it will be disabled when outside of fullscreen.

Edit the script settings at line ~35.

Download link for the script: https://raw.githubusercontent.com/kevinlekiller/mpv_scripts/master/autoscaling/auto_scaling.lua
