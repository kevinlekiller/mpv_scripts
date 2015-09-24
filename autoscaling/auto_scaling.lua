--[[
    Disable video scaling if video is slightly smaller than window size.

    For this script to function properly, you need to either be fullscreen or have the "no-border" option
    in addition to disabling any options altering the size of the window when not in fullscreen,
    otherwise the calculations may be off. If you do not have the "no-border" option enabled, the script
    will still function when you enter fullscreen mode, it will be disabled when outside of fullscreen.

    Edit settings @ line ~35.

    https://github.com/kevinlekiller/mpv_scripts
--]]
--[[
    Copyright (C) 2015  kevinlekiller

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
    https://www.gnu.org/licenses/gpl-2.0.html
--]]

-----------------------------------------------------------------------------------------------------------------------------------
------------------------------------------- Start of user settings ----------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------
local settings = {
    -- How much smaller can a video be to the window size before enabling scaling?
    -- For example, the video is 1860x1020, window size is 1920x1080, 1920*0.93=1786, 1080*0.93=1004,
    -- the video is larger than 1786x1004 so scaling is turned off.
    deviation = 0.93,
    -- Set to true if you want to enable scaling if video width is smaller than (window.width * settings.deviation)
    -- For example, if you set to false, a video with 1440x1080 (4x3 aspect ratio) on a 1080p monitor will have scaling turned off.
    min_width = false,
    osd = {
        -- Enable OSD?
        enabled = false,
        -- How much time in seconds will the OSD message be on screen.
        time = 5,
        -- Keyboard key to print OSD message.
        key = "c"
    },
    -- Add debug to OSD messages?
    debug = false
}
-----------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------- End of user settings -----------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------

local global = {
    scale = nil,
    osd = {
        start = mp.get_property_osd("osd-ass-cc/0"),
        stop = mp.get_property_osd("osd-ass-cc/1")
    },
    debug = "",
    require_printed = false
}

function main()
    if (mp.get_property("fullscreen") == "no" and mp.get_property("border") == "yes") then
        global.scale = mp.get_property("video-unscaled")
        global.debug = "Error: This script requires '--fullscreen' or '--no-border' to function correctly."
        if (global.require_printed == false) then
            print(global.debug)
            global.require_printed = true
        end
        return
    end
    global.debug = ""
    global.scale = check_scaling()
    if (global.scale ~= nil) then
        mp.set_property("video-unscaled", global.scale)
    end
end

function osd()
    if (settings.osd.enabled == true and global.scale ~= nil) then
        local string = global.osd.start .. "{\\b1}Scaling disabled:{\\b0}\\h" .. global.scale .. "\\N"
        if (settings.debug == true) then
            string = string .. "{\\b1}Debug:{\\b0}\\h" .. global.debug .. "\\N"
        end
        mp.osd_message(string .. global.osd.stop, settings.osd.time);
    end
end

function check_scaling()
    -- Get video dimensions.
    local video = {
        width = mp.get_property("video-params/dw"),
        height = mp.get_property("video-params/dh")
    }

    -- Get window size.
    local window = {
        width = mp.get_property("video-out-params/dw"),
        height = mp.get_property("video-out-params/dh"),
    }

    local error = "nil property unavailable"
    if (video.width == error or window.width == error) then
        global.debug = "Unable to get video or window dimensions."
        return nil
    end

    window.width = tonumber(window.width)
    window.height = tonumber(window.height)
    video.width = tonumber(video.width)
    video.height = tonumber(video.height)
    if (window.width == nil or video.width == nil) then
        global.debug = "Unable to get video or window dimensions."
        return nil
    end

    -- Minimum acceptable values.
    local min = {
        width = (window.width * settings.deviation),
        height = (window.height * settings.deviation)
    }

    if (video.width > window.width or video.height > window.height) then
        if (settings.debug == true) then
            global.debug = (
                "Video (" .. video.width .. "x" .. video.height .. 
                ") is larger than window size (" .. window.width .. 
                "x" .. window.height .."), enable scaling."
            )
        end
        return "no"
    end

    if (settings.min_width == true and video.width < min.width) then
        if (settings.debug == true) then
            global.debug = (
                "Video width of " .. video.width ..
                " is less than threshold value of " ..
                min.width .. ", enable scaling."
            )
        end
        return "no" 
    end

    -- 
    if (video.height < min.height) then
        if (settings.debug == true) then
            global.debug = (
                "Video height of " .. video.height ..
                " is less than threshold value of " ..
                min.height .. ", enable scaling."
            )
        end
        return "no"
    end

    -- Video is larger than threshold values and smaller than window size, disable scaling.
    if (settings.debug == true) then
        global.debug = (
            "Video (" .. video.width .. "x" .. video.height ..
            ") is within acceotable range of thresholds (" .. min.width ..
            "x" .. min.height .. ") and window size (" ..
            window.width .. "x" .. window.height .. "), disable scaling."
        )
    end
    return "yes"
end

mp.register_event("file-loaded", main)
mp.register_event("video-reconfig", main)
mp.observe_property("window-scale", "native", main)
mp.observe_property("fullscreen", "native", main)
if (settings.osd.enabled == true) then
    mp.add_key_binding(settings.osd.key, mp.get_script_name(), osd, {repeatable=true})
end
