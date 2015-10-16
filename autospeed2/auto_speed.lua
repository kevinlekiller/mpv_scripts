--[[
    See script details on https://github.com/kevinlekiller/mpv_scripts
    
    Valid --script-opts are (they are all optional):
    autospeed-xrandr=false     true/false - Use xrandr.
    autospeed-ffprobe=false    true/false - Use ffprobe
    autospeed-display=HDMI1               - Use specified xrandr display, fetch with xrandr -q
    autospeed-exitmode=0x48               - Revert to this mode when exiting mpv, fetch with xrandr --verbose
    autospeed-minspeed=0.9     Number     - Minimum allowable speed to play video at.
    autospeed-maxspeed=1.1     Number     - Maximum allowable speed to play video at.
    autospeed-osd=true         true/false - Enable OSD.
    autospeed-osdstart=false   true/false - Show OSD output when a video starts.
    autospeed-osdtime=10       Number     - How many seconds the OSD will be shown.
    autospeed-osdkey=y                    - Key to press to show the OSD.
    autospeed-logfps=false     true/false - Log non known ffprobe fps's to ~/mpv_unk_fps.log

    Example: mpv file.mkv --script-opts=autospeed-ffprobe=true,--autospeed-minspeed=0.8
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

local _global = {
    osd_start = mp.get_property_osd("osd-ass-cc/0"),
    osd_end = mp.get_property_osd("osd-ass-cc/1"),
    utils = require 'mp.utils',
    -- I will keep adding these as I find them.
    -- You can also pass --script-options=autospeed-logfps=true to log (~/mpv_unk_fps.log) ones not found in this table.
    -- Some of these are good, they are there to prevent a call to ffprobe.
    knownFps = {
        [23.975986] = 13978/583,
        [23.976]    = 2997/125,
        [23.976025] = 24000/1001,
        [23.976044] = 27021/1127,
        [25]        = 25/1,
        [29.969999] = 2997/100,
        [29.970030] = 30000/1001,
        [30.000000] = 30/1,
        [50]        = 50/1,
        [59.939999] = 2997/50,
        [59.94006]  = 19001/317
    },
    modes = {}
}

function fileExists(path)
    local test = io.open(path, "r")
    if (test == nil) then
        return false
    end
    return io.close(test)
end

function round(number)
    return math.floor(number + 0.5)
end

function notInt(integer)
    return (tonumber(integer) == nil)
end

function osdEcho()
    if (_global.options["osd"] == true) then
        mp.osd_message(_global.temp["output"], _global.options["osdtime"])
    end
end

function getOptions()
    _global.options = {
        ["xrandr"]   = "false",
        ["ffprobe"]  = "false",
        ["display"]  = "HDMI1",
        ["exitmode"] = "",
        ["minspeed"] = "0.9",
        ["maxspeed"] = "1.1",
        ["osd"]      = "false",
        ["osdstart"] = "false",
        ["osdtime"]  = "10",
        ["osdkey"]   = "y",
        ["logfps"]   = "false"
    }
    for key, value in pairs(_global.options) do
        local opt = mp.get_opt("autospeed-" .. key)
        if (opt ~= nil) then
            if ((key == "xrandr" or key == "ffprobe" or key == "osd" or key == "osdstart" or key == "logfps") and opt == "true") then
                _global.options[key] = true
            elseif (key == "minspeed" or key == "maxspeed" or key == "osdtime") then
                local test = tonumber(opt)
                if (test ~= nil) then
                    _global.options[key] = test
                end
            else
                _global.options[key] = opt
            end
        end
    end
end
getOptions()

function main()
    _global.temp = {}
    _global.temp["fps"] = tonumber(mp.get_property("fps"))
    if (_global.temp["fps"] == nil) then
        return
    end
    
    _global.temp["start_drr"] = tonumber(mp.get_property("display-fps"))
    if (_global.temp["start_drr"] == nil) then
        return
    end
    
    _global.temp["fps"] = getFfprobeFps()
    local wanted_drr = findRefreshRate()
    
    _global.temp["drr"] = tonumber(mp.get_property("display-fps"))
    -- If we didn't get the updated display refresh rate, sleep and try again.
    if (wanted_drr ~= _global.temp["start_drr"] and wanted_drr > 0 and _global.temp["drr"] == _global.temp["start_drr"]) then
        os.execute("sleep 1")
        _global.temp["drr"] = tonumber(mp.get_property("display-fps"))
    end

    if (_global.confspeed == nil) then
        _global.confspeed = mp.get_property("speed")
    end
    
    determineSpeed()
    if (_global.temp["speed"] > 0 and _global.temp["speed"] > _global.options["minspeed"] and _global.temp["speed"] < _global.options["maxspeed"]) then
        mp.set_property("speed", _global.temp["speed"])
    else
        _global.temp["speed"] = _global.confspeed
    end
    
    if (_global.options["osd"] == true) then
        setOSD()
        if (_global.options["osdstart"] == true) then
            osdEcho()
        end
    end
end

function setOSD()
    _global.temp["output"] = (_global.osd_start ..
        "{\\b1}Original monitor refresh rate{\\b0}\\h\\h" .. _global.temp["start_drr"] .. "Hz\\N" ..
        "{\\b1}Current  monitor refresh rate{\\b0}\\h\\h" .. _global.temp["drr"] .. "Hz\\N" ..
        "{\\b1}Original video fps{\\b0}\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h" .. _global.temp["fps"] .. "fps\\N" ..
        "{\\b1}Current  video fps{\\b0}\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h" .. (_global.temp["fps"] * _global.temp["speed"]) .. "fps\\N" ..
        "{\\b1}Original video playback fps{\\b0}\\h\\h\\h\\h\\h" .. _global.temp["relative_fps"] .. "fps\\N" ..
        "{\\b1}Current  video playback fps{\\b0}\\h\\h\\h\\h\\h" .. (_global.temp["relative_fps"] * _global.temp["speed"]) .. "fps\\N" ..
        "{\\b1}Original mpv speed setting{\\b0}\\h\\h\\h\\h\\h\\h" .. _global.confspeed .. "x\\N" ..
        "{\\b1}Current  mpv speed setting{\\b0}\\h\\h\\h\\h\\h\\h" .. _global.temp["speed"] .. "x" ..
        _global.osd_end
    )
end

function getFfprobeFps()
    -- Even if the user doesn't use ffprobe, we can use known values.
    local temp = _global.knownFps[_global.temp["fps"]]
    if (temp ~= nil) then
        return temp
    end
    if (_global.options["ffprobe"] ~= true) then
        return _global.temp["fps"]
    end
    -- Get video file name.
    local video = mp.get_property("stream-path")
    if (fileExists(video) == false) then
        if (_global.options["logfps"] == true) then
            os.execute("echo [$(date)] \"" ..mp.get_property("path") .. "\" " .. _global.temp["fps"] .. " >> ~/mpv_unk_fps.log") 
        end
        return _global.temp["fps"]
    end
    local command = {
        ["cancellable"] = "false",
        ["args"] = {
            [1] = "ffprobe",
            [2] = "-select_streams",
            [3] = "v:" .. mp.get_property("ff-vid"),
            [4] = "-v",
            [5] = "quiet",
            [6] = "-show_streams",
            [7] = "-show_entries",
            [8] = "stream=avg_frame_rate,r_frame_rate",
            [9] = "-print_format",
            [10] = "json",
            [11] = video
        }
    }
    local output = _global.utils.subprocess(command)
    if (output == nil) then
        return _global.temp["fps"]
    end
    
    output = _global.utils.parse_json(output.stdout)
    -- Make sure we got data, and avg_frame_rate is the same as r_frame_rate, otherwise the video is not constant fps.
    if (output == nil or output == error or output.streams[1].avg_frame_rate ~= output.streams[1].r_frame_rate) then
        return _global.temp["fps"]
    end
    
    local first, second = output.streams[1].avg_frame_rate:match("(%d+)%D+(%d+)")
    if (notInt(first) or notInt(second)) then
        return _global.temp["fps"]
    end
    if (_global.options["logfps"] == true) then
        os.execute("echo [$(date)] \"" .. mp.get_property("filename") .. "\" [" .. _global.temp["fps"] .. "] = " .. output.streams[1].avg_frame_rate .. ", >> ~/mpv_unk_fps.log") 
    end
    
    local ff_fps = first / second
    if (ff_fps < 1) then
        return _global.temp["fps"]
    end
    _global.knownFps[_global.temp["fps"]] = ff_fps
    return ff_fps
end

function determineSpeed()
    local speed = 0
    local difference = 1
    local relative_fps = 0
    if (_global.temp["drr"] > _global.temp["fps"]) then
        difference = (_global.temp["drr"] / _global.temp["fps"])
        if (difference >= 2) then
            -- fps = 24fps, drr = 60hz
            -- difference = 60hz/24fps = 3 rounded
            -- 24fps * 3 = 72fps
            -- 60hz / 72fps = 0.833333333333 speed
            -- 72fps * 0.833333333333 = 60fps
            difference = round((_global.temp["drr"] / _global.temp["fps"]))
            speed = (_global.temp["drr"] / (_global.temp["fps"] * difference))
        else
            -- fps = 50fps, drr = 60hz
            -- 60hz / 50fps = 1.2 speed
            -- 50fps * 1.2 speed = 60fps
            
            -- fps = 59.94fps, drr = 60hz
            -- 60hz / 59.94fps  = 1.001001001001001 speed
            -- 59.94fps * 1.001001001001001 = 60fps
            speed = difference
        end
        if ((_global.temp["drr"] - _global.temp["fps"]) < 1) then
            relative_fps = _global.temp["fps"]
        else
            relative_fps = _global.temp["fps"] * difference
        end
    elseif (_global.temp["drr"] < _global.temp["fps"]) then
        difference = (_global.temp["fps"] / _global.temp["drr"])
        if (difference >= 2) then
            -- fps = 120fps, drr = 25hz
            -- difference = 120fps/25hz = 5 rounded
            -- 120fps/5 = 24fps ; 25hz / 24fps = 1.04166666667 speed
            -- 24fps * 1.04166666667 speed = 25fps
            difference = round((_global.temp["fps"] / _global.temp["drr"]))
            speed = (_global.temp["drr"] / (_global.temp["fps"] / difference))
        else
            -- fps = 60fps, drr = 50hz
            -- difference = 50hz / 60fps = 0.833333333333 speed
            -- 60fps * 0.833333333333 speed = 50fps
            
            -- fps = 60fps, drr = 59.94hz
            -- difference = 59.94hz / 60fps = 0.999 speed
            -- 60fps * 0.999 speed = 59.94fps
            speed = (_global.temp["drr"] / _global.temp["fps"])
        end
        if ((_global.temp["fps"] - _global.temp["drr"]) < 1) then
            relative_fps = _global.temp["fps"]
        else
            relative_fps = _global.temp["fps"] / difference
        end
    elseif (_global.temp["drr"] == _global.temp["fps"]) then
        speed = 1
        relative_fps = _global.temp["fps"]
    end
    _global.temp["speed"] = speed
    _global.temp["relative_fps"] = relative_fps
end

function findRefreshRate()
    if (_global.options["xrandr"] ~= true or getXrandrRates() == false) then
        return 0
    end
    local round_fps = round(_global.temp["fps"])
    -- If video FPS is 24 fps, 240 / 24 = 10, try 10 times to find a suitable monitor mode,
    -- for example: 24, 48, 72, 96, 120, 144, 168, 192, 226, 240 hz
    -- TODO? Maybe add fallback code if for example the video is 120fps and the monitor
    -- can only go as high as 60hz, although this will lead to dropped frames.
    local iterator = (240 / round_fps)
    if (iterator < 1) then
        iterator = 1
    end
    for rate, val in pairs(_global.modes) do
        local min = (rate * _global.options["minspeed"])
        local max = (rate * _global.options["maxspeed"])
        for multiplier = 1, iterator do
            local multiplied_fps = (multiplier * round_fps)
            if (multiplied_fps >= min and multiplied_fps <= max) then
                setXrandrRate(val["mode"])
                return val["clock"]
            end
        end
    end
    return 0
end

function setXrandrRate(mode)
    if (_global.options["xrandr"] == true) then
        local command = {
            ["cancellable"] = "false",
            ["args"] = {
                [1] = "xrandr",
                [2] = "--output",
                [3] = _global.options["display"],
                [4] = "--mode",
                [5] = mode
            }
        }
        _global.utils.subprocess(command)
    end
end

function getXrandrRates()
    if (_global.modes == false) then
        return false
    end
    local vars = {
        handle = assert(io.popen("xrandr --verbose")),
        foundDisp = false,
        foundRes = false,
        count = 0,
        temp = {},
        resolution
    }
    
    for line in vars.handle:lines() do
        if (vars.foundDisp == true) then -- We found the display name.
            if (string.match(line, "^%S") ~= nil) then
                break -- We reached the next display or EOF.
            end
            if (string.match(line, "^%s+" .. vars.resolution) ~= nil) then -- Check if mode uses current display resolution.
                vars.foundRes = true
            end
            if (vars.foundRes == true) then -- We found a matching screen resolution.
                vars.count = vars.count + 1
                if (vars.count == 1) then -- Log the mode name / pixel clock speed.
                    local mode, pclock = string.match(line, "%((.+)%)%s+([%d.]+)MHz")
                    vars.temp = {["mode"] = mode, ["pclock"] = pclock, ["htotal"] = "", ["vtotal"] = "", ["clock"] = ""}
                elseif (vars.count == 2) then -- Log the total horizontal pixels.
                    vars.temp["htotal"] = string.match(line, "total%s+(%d+)")
                elseif (vars.count == 3) then -- Get the total vertical pixels, calculate refresh rate, log it.
                    local vtotal, clock = string.match(line, "total%s+(%d+).+clock%s+([%d.]+)[KkHh]+z")
                    _global.modes[round(clock)] = {
                        ["clock"] = ((vars.temp["pclock"] * 1000000) / (vtotal * vars.temp["htotal"])),
                        ["mode"] = vars.temp["mode"]
                    }
                    vars.count = 0 -- Reset variables to look for another matching resolution.
                    vars.foundRes = false
                    vars.temp = {}
                end
            end
        elseif (string.match(line, "^" .. _global.options["display"]) == _global.options["display"]) then -- Check if the display name (ie HDMI1) matches the one in the config.
            if (string.find(line, "disconnected") ~= nil) then
                break -- Wrong display name was given.
            else
                local res = string.match(line, "^" .. _global.options["display"] .. "[^%d]+([%dx]+)") -- Find current monitor resolution.
                if (res ~= nil and res ~= "") then
                    vars.resolution = res
                    vars.foundDisp = true
                else
                    break -- Could not find display resolution.
                end
            end
        end
    end
    vars.handle:close()
    if (_global.modes == {}) then
        _global.modes = false
        return false
    end
end

if (_global.options["xrandr"] == true and _global.options.exitmode ~= "") then
    function revertDrr()
        os.execute("xrandr --output " .. _global.options["display"] .. " --mode " .. _global.options["exitmode"] .. " &")
    end
    mp.register_event("shutdown", revertDrr)
end
mp.observe_property("fps", "native", main)
mp.add_key_binding(_global.options["osdkey"], mp.get_script_name(), osdEcho, {repeatable=true})
