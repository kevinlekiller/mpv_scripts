--[[
    Disable video scaling if video is slightly smaller than window size.

    For example, your monitor is 1920x1080, the video is 1920x816 (2.35:1 aspect ratio), scaling is disabled.

    The "window-scale" will be set to 1 and "border" set to "no" if the video is within range,
    this is to simplify how the script functions.

    Edit the script settings at line ~35.

    https://github.com/kevinlekiller/mpv_scripts
--]]
--[[
    Copyright (C) 2016-2017  kevinlekiller

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
    -- Width of your monitor's resolution in pixels.
    width = 1920,
    -- Height of your monitor's resolution in pixels.
	height = 1080,
    -- How much smaller can a video be to the window size before enabling scaling?
    -- For example, the video is 1860x1020, window size is 1920x1080, 1920*0.93=1786, 1080*0.93=1004,
    -- the video is larger than 1786x1004 so scaling is turned off.
    deviation = 0.93,
    osd = {
        -- Enable OSD?
        enabled = false,
        -- How much time in seconds will the OSD message be on screen.
        time = 5,
        -- Keyboard key to print OSD message.
        key = ";"
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
    debug = ""
}

function main()
    global.debug = ""
    global.scale = check_scaling()
    if (global.scale ~= nil) then
        if (global.scale == "yes") then
            mp.set_property("border", "no")
            mp.set_property("window-scale", 1)
        end
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

if (settings.osd.enabled == true) then
    mp.add_key_binding(settings.osd.key, "auto-scaling_osd", osd, {repeatable=true})
end

function check_scaling()
    -- Get video dimensions.
    local video = {
        width = mp.get_property("video-out-params/dw"),
        height = mp.get_property("video-out-params/dh")
    }

    -- Get window size.
    local window = {
        width = tonumber(settings.width),
        height = tonumber(settings.height),
    }

    local error = "nil property unavailable"
    if (video.width == error or video.height == error) then
        global.debug = "Unable to get video dimensions."
        return nil
    end

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

    if (settings.debug == true) then
        global.debug = "Video (" .. video.width .. "x" .. video.height .. ") is "
    end

    -- Video is bigger than monitor.
    if (video.width > window.width or video.height > window.height) then
        if (settings.debug == true) then
            global.debug = (
                global.debug .. "larger than window size (" ..
                window.width .. "x" .. window.height .."), enable scaling."
            )
        end
        return "no"
    end

    -- Video width is within acceptable range.
    if (video.width >= min.width) then
        if (settings.debug == true) then
            global.debug = (
                global.debug .. "within acceptable width range of (" ..
                min.width .. " - " .. window.width .. "), disable scaling."
            )
        end
        return "yes"
    end

    -- Video height is within acceptable range.
    if (video.height >= min.height) then
        if (settings.debug == true) then
            global.debug = (
                global.debug .. "within acceptable height range of (" ..
                min.height .. " - " .. window.height .. "), disable scaling."
            )
        end
        return "yes"
    end

    -- Video height and width are under acceptable range. Enable scaling.
    if (settings.debug == true) then
        global.debug = (
            global.debug ..
            "under acceptable range of thresholds (" .. min.width ..
            "x" .. min.height .. ") and window size (" ..
            window.width .. "x" .. window.height .. "), enable scaling."
        )
    end
    return "no"
end

mp.register_event("file-loaded", main)
mp.register_event("video-reconfig", main)
mp.observe_property("window-scale", "native", main)
mp.observe_property("fullscreen", "native", main)
