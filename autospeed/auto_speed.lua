--[[
    Copy auto_speed_config.lua.example to auto_speed_config.lua and change the options in that file.

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

mputils = require 'mp.utils'
local osd = {
    string_start = mp.get_property_osd("osd-ass-cc/0"),
    string_end = mp.get_property_osd("osd-ass-cc/1"),
    output = ""
}
local exit_drr = 0

--[[
    Check if a file exists.

    @param string File path.
    @return bool
--]]
function fileExists(path)
    local test = io.open(path, "r")
    if (test == nil) then
        return false
    end
    io.close(test)
    return true
end

--[[
    Get path of current script.
    Taken from : http://stackoverflow.com/a/23535333

    @return string
--]]
function scriptPath()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end

--[[
    Get options from config file.

    @return bool If config file loaded.
--]]
function getSetConfig()
    if (fileExists(scriptPath() .. "auto_speed_config.lua")) then
        return require "auto_speed_config"
    end
    return false
end

-- Try to set the options from the config file. Set default values if config file not found.
if (getSetConfig() == false) then
    config = {
        use_xrandr = false,
        use_nircdm = false,
        use_ffprobe = false,
        nircmd_bit_depth = "32",
        xrandr_display = "DP1",
        display_width  = "1920",
        display_height = "1080",
        srr = {
            _24  = false,
            _25  = false,
            _30  = false,
            _48  = false,
            _50  = false,
            _60  = "0x48",
            _72  = false,
            _96  = false,
            _100 = false,
            _120 = false,
            _144 = false
        },
        thresholds = {
            min_speed = 0.9,
            max_speed = 1.1
        },
        osd_displayed = false,
        osd_start = false,
        osd_time = 10,
        osd_key = "y"
    }
end

--[[
    Main function.

    @return int 0 on success, anything else is an error.
--]]
function main()
    -- Reset this - for when a new video is loaded.
    osd.output = ""
    local fps = tonumber(mp.get_property("fps"))
    if (checkInt(fps) == false) then
        print("Error: Could not properly detect video frame rate.")
        return 1
    end

    local original_drr = tonumber(mp.get_property("display-fps"))
    if (checkInt(original_drr) == false) then
        print("Error: Could not properly detect display refresh rate.")
        return 2
    end

    exit_drr = original_drr
    fps = getMoreAccurateFrameRate(fps)
    wanted_drr = getAndSetRefreshRate(fps)

    local drr = tonumber(mp.get_property("display-fps"))
    -- If we didn't get the updated display refresh rate, sleep and try again.
    if (checkInt(wanted_drr) == true and drr == original_drr and wanted_drr ~= original_drr) then
        if (config.use_xrandr == true) then
            os.execute("sleep 1")
        elseif (config.use_nircdm == true) then
            os.execute("ping -n 1 localhost > NUL")	
        end
        drr = tonumber(mp.get_property("display-fps"))
    end

    setSpeedOSD(original_drr, drr, fps)
    if (config.osd_start == true) then
        osdEcho()
    end
    return 0
end

--[[
    Sets the speed in mpv and the OSD output text.
    @param int/float/double original_drr Original display refresh rate.
    @param int/float/fouble drr          Current display refresh rate (after xrandr or nircdm).
    @param fps                           Original video FPS.
--]]
function setSpeedOSD(original_drr, drr, fps)
    local original_mp_speed = mp.get_property("speed")
    speed, relative_fps, difference = determineSpeed(drr, fps)

    if (speed > 0 and speed > config.thresholds.min_speed and speed < config.thresholds.max_speed) then
        mp.set_property("speed", speed)
    end

    local new_video_fps = fps * speed
    local new_playback_fps = relative_fps * speed

    osdAppend(osdBold("Original monitor refresh rate") .. osdTab(2)  .. original_drr             .. "Hz")
    osdAppend(osdBold("Current  monitor refresh rate") .. osdTab(2)  .. drr                      .. "Hz")
    osdAppend(osdBold("Original video fps")            .. osdTab(24) .. fps                      .. "fps")
    osdAppend(osdBold("Current  video fps")            .. osdTab(24) .. new_video_fps            .. "fps")
    osdAppend(osdBold("Original video playback fps")   .. osdTab(6)  .. relative_fps             .. "fps")
    osdAppend(osdBold("Current  video playback fps")   .. osdTab(6)  .. new_playback_fps         .. "fps")
    osdAppend(osdBold("Original mpv speed setting")    .. osdTab(6)  .. original_mp_speed        .. "x")
    osdAppend(osdBold("Current  mpv speed setting")    .. osdTab(6)  .. speed                    .. "x")
end

--[[
    Due to rounding in mpv to float, convert some known frame rates for better accuracy.

    @param float/int Video frame rate.
    @return float/double/int
--]]
function getMoreAccurateFrameRate(fps)
    -- Try known values.
    if (fps == 23.976) then 
        fps = 2997 / 125 -- This one is fine, adding it so I know which ones I mapped.
    elseif (fps == 23.976025) then
        fps = 24000 / 1001
    elseif (fps == 23.976044) then
        fps = 27021 / 1127
    elseif (fps == 29.969999) then
        fps = 2997 / 100
    elseif (fps == 59.939999) then
        fps = 2997 / 50
    else
        -- Try ffprobe.
        local ff_fps = getFfprobeFps()
        if (ff_fps ~= 0) then
            fps = ff_fps
        end
    end
    return fps
end

--[[
    Use ffprobe to get more accurate video fps.

    @TODO Use the video stream currently in use? I believe this is the mpv "video" property.
    @return int/float/double 0 on failure.
--]]
function getFfprobeFps()
    -- Get video file name.
    local video = mp.get_property("working-directory") .. "/" .. mp.get_property("filename")
    if (fileExists(video) == false) then
        return 0
    end

    local command = {}
    command["cancellable"] = "false"
    command["args"] = {}
    command["args"][1] = "ffprobe"
    command["args"][2] = "-select_streams"
    command["args"][3] = "v"
    command["args"][4] = "-v"
    command["args"][5] = "quiet"
    command["args"][6] = "-show_streams"
    command["args"][7] = "-show_entries"
    command["args"][8] = "stream=avg_frame_rate,r_frame_rate"
    command["args"][9] = "-print_format"
    command["args"][10] = "json"
    command["args"][11] = video
    local output = mputils.subprocess(command)
    if (output == nil) then
        return 0
    end

    local json = mputils.parse_json(output.stdout)
    -- Make sure we got data, and avg_frame_rate is the same as r_frame_rate, otherwise the video is not constant fps.
    if (json == nil or json == error or json.streams[1].avg_frame_rate ~= json.streams[1].r_frame_rate) then
        return 0
    end

    local first, second = json.streams[1].avg_frame_rate:match("([0-9]+)[^0-9]+([0-9]+)")
    if (checkInt(first) == false or checkInt(second) == false) then
        return 0
    end

    local fps = first / second
    if (checkInt(fps) == false) then
        return 0
    end
    return fps
end

--[[
    Check integer for nil or smaller than 1.

    @param int integer
    @return bool
--]]
function checkInt(integer)
    integer = tonumber(integer)
    if (integer == nil or integer < 1) then
        return false
    end
    return true
end

--[[
    Adds bold to OSD text.

    @param string text
    @return string
--]]
function osdBold(text)
    return "{\\b1}" .. text .. "{\\b0}"
end

--[[
    Returns given quantity of tabs for OSD text.

    @param int quantity
    @return string
--]]
function osdTab(quantity)
    local ret = ""
    if (checkInt(quantity) == false) then
        ret = ""
    elseif (quantity == 1) then
        ret = "\\h"
    else
        for i=1,quantity do
            ret = ret .. "\\h"
        end
    end
    return ret
end

--[[
    Appends OSD output text.

    @param string text
    @void
--]]
function osdAppend(text)
    osd.output = osd.output .. text .. "\\N"
end

--[[
    Print output text to OSD.
    @void
--]]
function osdEcho()
    if (config.osd_displayed == true) then
        mp.osd_message(osd.string_start .. osd.output .. osd.string_end, config.osd_time)
    end
end

--[[
    Calculates the video playback speed.

    @param int drr Display refresh rate.
    @param int fps Video frame rate.

    @return int speed        Determined wanted playback speed.
            int relative_fps FPS of video when factoring repeated or discarded frames.
            int difference   Difference between display and video refresh rates.
--]]
function determineSpeed(drr, fps)
    local speed = 0
    local difference = 1
    local relative_fps = 0
    if (drr > fps) then
        difference = (drr / fps)
        if (difference >= 2) then
            -- fps = 24fps, drr = 60hz
            -- difference = 60hz/24fps = 3 rounded
            -- 24fps * 3 = 72fps
            -- 60hz / 72fps = 0.833333333333 speed
            -- 72fps * 0.833333333333 = 60fps
            difference = math.floor((drr / fps) + 0.5)
            speed = (drr / (fps * difference))
        else
            -- fps = 50fps, drr = 60hz
            -- 60hz / 50fps = 1.2 speed
            -- 50fps * 1.2 speed = 60fps

            -- fps = 59.94fps, drr = 60hz
            -- 60hz / 59.94fps  = 1.001001001001001 speed
            -- 59.94fps * 1.001001001001001 = 60fps
            speed = difference
        end
        if (drr - fps < 1) then
            relative_fps = fps
        else
            relative_fps = fps * difference
        end
    elseif (drr < fps) then
        difference = (fps / drr)
        if (difference >= 2) then
            -- fps = 120fps, drr = 25hz
            -- difference = 120fps/25hz = 5 rounded
            -- 120fps/5 = 24fps ; 25hz / 24fps = 1.04166666667 speed
            -- 24fps * 1.04166666667 speed = 25fps
            difference = math.floor((fps / drr) + 0.5)
            speed = (drr / (fps / difference))
        else
            -- fps = 60fps, drr = 50hz
            -- difference = 50hz / 60fps = 0.833333333333 speed
            -- 60fps * 0.833333333333 speed = 50fps

            -- fps = 60fps, drr = 59.94hz
            -- difference = 59.94hz / 60fps = 0.999 speed
            -- 60fps * 0.999 speed = 59.94fps
            speed = (drr / fps)
        end
        if (fps - drr < 1) then
            relative_fps = fps
        else
            relative_fps = fps / difference
        end
    elseif (drr == fps) then
        speed = 1
        relative_fps = fps
    end
    return speed, relative_fps, difference
end

--[[
    Finds a suitable refresh rate for the monitor based on video frame rate.

    @var int fps Frame rate of the video.
    @return int
--]]
function getAndSetRefreshRate(fps)
    if (config.use_xrandr == false and config.use_nircdm == false) then
        return 0
    elseif ((fps >= 29 and fps <= 31) or (fps >= 59 and fps <= 61)) then
        if (config.srr._120 ~= false) then
            return setRefreshRate(120, config.srr._120)
        elseif (config.srr._60 ~= false) then
            return setRefreshRate(60, config.srr._60)
        elseif (config.srr._30 ~= false) then
            return setRefreshRate(30, config.srr._30)

        -- Not exact, but close.
        elseif (config.srr._50 ~= false) then
            return setRefreshRate(50, config.srr._50)
        end
    elseif ((fps >= 23 and fps <= 24.5) or (fps >= 47 and fps <= 49)) then
        if (config.srr._144 ~= false) then
            return setRefreshRate(144, config.srr._144)
        elseif (config.srr._120 ~= false) then
            return setRefreshRate(120, config.srr._120)
        elseif (config.srr._96 ~= false) then
            return setRefreshRate(96, config.srr._96)
        elseif (config.srr._72 ~= false) then
            return setRefreshRate(72, config.srr._72)
        elseif (config.srr._48 ~= false) then
            return setRefreshRate(48, config.srr._48)
        elseif (config.srr._24 ~= false) then
            return setRefreshRate(24, config.srr._24)

        -- Not exact matches but close.
        elseif (config.srr._50 ~= false) then
            return setRefreshRate(50, config.srr._50)
        elseif (config.srr._25 ~= false) then
            return setRefreshRate(25, config.srr._25)
        end
    elseif ((fps >= 24.6 and fps <= 25.5) or (fps >= 49.1 and fps <= 51)) then
        if (config.srr._100 ~= false) then
            return setRefreshRate(100, config.srr._100)
        elseif (config.srr._50 ~= false) then
            return setRefreshRate(50, config.srr._50)
        elseif (config.srr._25 ~= false) then
            return setRefreshRate(25, config.srr._25)

        -- Not exact matches but close.
        elseif (config.srr._120 ~= false) then
            return setRefreshRate(120, config.srr._120)
        elseif (config.srr._24 ~= false) then
            return setRefreshRate(24, config.srr._24)
        end
    end
    return 0
end

--[[
    Sets monitor refresh rate using xrandr.
    Credits to lvml @ https://github.com/lvml/mpv-plugin-xrandr/blob/master/xrandr.lua#L228

    @param string drr  Display refresh rate.
    @param string mode Xrandr mode.
--]]
function setRefreshRate(drr, mode)
    local command = {}
    command["cancellable"] = "false"
    if (config.use_xrandr == true) then
        command["args"] = {}
        command["args"][1] = "xrandr"
        command["args"][2] = "--output"
        command["args"][3] = tostring(config.xrandr_display)
        command["args"][4] = "--mode"
        command["args"][5] = tostring(mode)
        mputils.subprocess(command)
    end
    if (config.use_nircdm == true) then
        command["args"] = {}
        command["args"][1] = "nircmdc"
        command["args"][2] = "setdisplay"
        command["args"][3] = config.display_width
        command["args"][4] = config.display_height
        command["args"][5] = config.nircmd_bit_depth
        command["args"][6] = tostring(drr)
        mputils.subprocess(command)
    end
    return drr
end

--[[
    Revert display refresh rate to original value on exit.

    @param table event
--]]
function revertDrr(event)
    if (exit_drr == 0) then
        return
    end
    -- Round
    exit_drr = exit_drr + 0.5 - (exit_drr + 0.5) % 1
    if (config.use_xrandr == true) then
        os.execute(
            "xrandr -s " ..
            config.display_width ..
            "x" ..
            config.display_height ..
            " -r " ..
            tostring(exit_drr) ..
            " &"
        )
    end
    if (config.use_nircdm == true) then
        os.execute(
            "START /B nircmdc setdisplay " ..
            config.display_width .. " " ..
            config.display_height .. " " ..
            config.nircmd_bit_depth .. " " ..
            tostring(exit_drr)
        )
    end
end

mp.register_event("shutdown", revertDrr)
mp.observe_property("fps", "native", main)
mp.add_key_binding(config.osd_key, mp.get_script_name(), osdEcho, {repeatable=true})
