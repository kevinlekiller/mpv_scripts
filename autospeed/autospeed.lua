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
    autospeed-osdtime=10       Number     - How many seconds the OSD will be shown.
    autospeed-osdkey=y                    - Key to press to show the OSD.
    autospeed-logfps=false     true/false - Log non known ffprobe fps's to ~/mpv_unk_fps.log
    autospeed-estfps=false     true/false - Calculate/change speed if a video has a variable fps at the cost of higher CPU usage (most videos have a fixed fps).

    Example: mpv file.mkv --script-opts=autospeed-ffprobe=true,autospeed-minspeed=0.8
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
        [23.976101] = 19061/795,
        [24]        = 24/1,
        [25]        = 25/1,
        [29.969999] = 2997/100,
        [29.970030] = 30000/1001,
        [30.000000] = 30/1,
        [50]        = 50/1,
        [59.939999] = 2997/50,
        [59.94006]  = 19001/317
    },
    modes = {},
    modeCache = {},
    lastDrr = 0,
    speedCache = {},
    next = next,
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

function osdEcho()
    if (_global.options["osd"] ~= true) then
        return
    end
    setOSD()
    if (_global.temp["output"] ~= nil) then
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
        ["osdtime"]  = "10",
        ["osdkey"]   = "y",
        ["logfps"]   = "false",
        ["estfps"]   = "false",
    }
    for key, value in pairs(_global.options) do
        local opt = mp.get_opt("autospeed-" .. key)
        if (opt ~= nil) then
            if ((key == "xrandr" or key == "ffprobe" or key == "osd" or key == "logfps" or key == "estfps") and opt == "true") then
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

function main(name, fps)
    if (fps == nil) then
        return
    end
    _global.temp["fps"] = fps
    getFfprobeFps()
    _global.temp["fps"] = _global.knownFps[_global.temp["fps"]]
    local wanted_drr = findRefreshRate()
    
    if (wanted_drr ~= _global.temp["drr"]) then
        if (wanted_drr ~= _global.temp["start_drr"] and wanted_drr > 0) then
            _global.temp["drr"] = wanted_drr
            mp.set_property("display-fps", _global.temp["drr"])
        else
            _global.temp["drr"] = _global.temp["start_drr"]
        end
    end
    
    if (determineSpeed() ~= 0) then
        if (_global.temp["speed"] > 0 and _global.temp["speed"] >= _global.options["minspeed"] and _global.temp["speed"] <= _global.options["maxspeed"]) then
            mp.set_property("speed", _global.temp["speed"])
        else
            _global.temp["speed"] = _global.confspeed
        end
    end
end

function setOSD()
    _global.temp["output"] = (_global.osd_start ..
        "{\\b1}Original monitor refresh rate{\\b0}\\h\\h" .. _global.temp["start_drr"] .. "Hz\\N" ..
        "{\\b1}Current  monitor refresh rate{\\b0}\\h\\h" .. _global.temp["drr"] .. "Hz\\N" ..
        "{\\b1}Original video fps{\\b0}\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h" .. _global.temp["fps"] .. "fps\\N" ..
        "{\\b1}Current  video fps{\\b0}\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h" .. (_global.temp["fps"] * _global.temp["speed"]) .. "fps\\N" ..
        "{\\b1}Original mpv speed setting{\\b0}\\h\\h\\h\\h\\h\\h" .. _global.confspeed .. "x\\N" ..
        "{\\b1}Current  mpv speed setting{\\b0}\\h\\h\\h\\h\\h\\h" .. _global.temp["speed"] .. "x" ..
        _global.osd_end
    )
end

function getFfprobeFps()
    -- Even if the user doesn't use ffprobe, we can use known values.
    if (_global.knownFps[_global.temp["fps"]]) then
        return
    end
    _global.knownFps[_global.temp["fps"]] = _global.temp["fps"]
    if (_global.options["ffprobe"] ~= true) then
        return
    end
    -- Get video file name.
    local video = mp.get_property("stream-path")
    if not (fileExists(video)) then
        if (_global.estimated == false and _global.options["logfps"] == true) then
            os.execute("echo [$(date)] \"" .. mp.get_property("path") .. "\" " .. _global.temp["fps"] .. " >> ~/mpv_unk_fps.log") 
        end
        return
    end
    local command = {
        ["cancellable"] = false,
        ["args"] = {
            [1] = "ffprobe",
            [2] = "-select_streams",
            [3] = "v:" .. mp.get_property("ff-vid"),
            [4] = "-v",
            [5] = "quiet",
            [6] = "-show_streams",
            [7] = "-show_entries",
            [8] = "stream=r_frame_rate",
            [9] = "-print_format",
            [10] = "json",
            [11] = video
        }
    }
    local output = _global.utils.subprocess(command)
    if not (output) then
        return
    end
    
    output = _global.utils.parse_json(output.stdout)
    if (output == nil or output == error) then
        return
    end
    
    local first, second = output.streams[1].r_frame_rate:match("(%d+)%D+(%d+)")
    if (tonumber(first) == nil or tonumber(second) == nil) then
        return
    end
    if (_global.options["logfps"] == true) then
        os.execute("echo [$(date)] \"" .. mp.get_property("filename") .. "\" [" .. _global.temp["fps"] .. "] = " .. output.streams[1].avg_frame_rate .. ", >> ~/mpv_unk_fps.log") 
    end
    
    local ff_fps = first / second
    if (ff_fps < 1) then
        return
    end
    _global.knownFps[_global.temp["fps"]] = ff_fps
end

function determineSpeed()
    local id = _global.temp["drr"] .. _global.temp["fps"]
    if (_global.speedCache[id] ~= nil) then
        _global.temp["speed"] = _global.speedCache[id]
        return 0
    end
    if (_global.temp["drr"] > _global.temp["fps"]) then
        local difference = (_global.temp["drr"] / _global.temp["fps"])
        if (difference >= 2) then
            -- fps = 24fps, drr = 60hz
            -- difference = 60hz/24fps = 3 rounded
            -- 24fps * 3 = 72fps
            -- 60hz / 72fps = 0.833333333333 speed
            -- 72fps * 0.833333333333 = 60fps
            _global.temp["speed"] = (_global.temp["drr"] / (_global.temp["fps"] * round(difference)))
        else
            -- fps = 50fps, drr = 60hz
            -- 60hz / 50fps = 1.2 speed
            -- 50fps * 1.2 speed = 60fps
            
            -- fps = 59.94fps, drr = 60hz
            -- 60hz / 59.94fps  = 1.001001001001001 speed
            -- 59.94fps * 1.001001001001001 = 60fps
            _global.temp["speed"] = difference
        end
    elseif (_global.temp["drr"] < _global.temp["fps"]) then
        local difference = (_global.temp["fps"] / _global.temp["drr"])
        if (difference >= 2) then
            -- fps = 120fps, drr = 25hz
            -- difference = 120fps/25hz = 5 rounded
            -- 120fps/5 = 24fps ; 25hz / 24fps = 1.04166666667 speed
            -- 24fps * 1.04166666667 speed = 25fps
            _global.temp["speed"] = (_global.temp["drr"] / (_global.temp["fps"] / round(difference)))
        else
            -- fps = 60fps, drr = 50hz
            -- difference = 50hz / 60fps = 0.833333333333 speed
            -- 60fps * 0.833333333333 speed = 50fps
            
            -- fps = 60fps, drr = 59.94hz
            -- difference = 59.94hz / 60fps = 0.999 speed
            -- 60fps * 0.999 speed = 59.94fps
            _global.temp["speed"] = (_global.temp["drr"] / _global.temp["fps"])
        end
    elseif (_global.temp["drr"] == _global.temp["fps"]) then
        _global.temp["speed"] = 1
    end
    _global.speedCache[id] = _global.temp["speed"]
end

function findRefreshRate()
    -- This is to prevent a system call if the screen refresh / video fps has not changed.
    if (_global.temp["drr"] == _global.lastDrr) then
        return _global.modeCache[_global.temp["drr"]]["clock"]
    elseif (_global.modeCache[_global.temp["drr"]] ~= nil) then
        return setXrandrRate(_global.modeCache[_global.temp["drr"]])
    end
    if (_global.options["xrandr"] ~= true or getXrandrRates() == false) then
        return 0
    end
    local round_fps = round(_global.temp["fps"])
    local iterator = 1
    if (_global.temp["maxclock"] > round_fps) then
        iterator = round(_global.temp["maxclock"] / round_fps)
    elseif (_global.temp["maxclock"] < round_fps) then
        iterator = round(round_fps / _global.temp["maxclock"])
    else
        return setXrandrRate(_global.modes[_global.temp["maxclock"]])
    end
    local smallest = 0
    local found = {}
    for rate, val in pairs(_global.modes) do
        local min = (rate * _global.options["minspeed"])
        local max = (rate * _global.options["maxspeed"])
        for multiplier = 1, iterator do
            local multiplied_fps = (multiplier * round_fps)
            if (multiplied_fps >= min and multiplied_fps <= max) then
                if (multiplied_fps < rate) then
                    local difference = (rate - multiplied_fps)
                    if (smallest == 0 or difference < smallest) then
                        smallest = difference
                        found = {["mode"] = val["mode"], ["clock"] = val["clock"]}
                    end
                elseif (multiplied_fps > rate) then
                    local difference = (multiplied_fps - rate)
                    if (smallest == 0 or difference < smallest) then
                        smallest = difference
                        found = {["mode"] = val["mode"], ["clock"] = val["clock"]}
                    end
                else
                    return setXrandrRate(val)
                end
            end
        end
    end
    if (_global.next(found) ~= nil) then
        return setXrandrRate(found)
    end
    return 0
end

function setXrandrRate(mode)
    _global.modeCache[_global.temp["drr"]] = mode
    _global.lastDrr = _global.temp["drr"]
    _global.utils.subprocess({
        ["cancellable"] = false,
        ["args"] = {
            [1] = "xrandr",
            [2] = "--output",
            [3] = _global.options["display"],
            [4] = "--mode",
            [5] = mode["mode"]
        }
    })
    return mode["clock"]
end

function getXrandrRates()
    if (_global.next(_global.modes) ~= nil) then
        return true
    end
    if not (_global.modes) then
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
        if (vars.foundDisp == false and string.match(line, "^" .. _global.options["display"]) == _global.options["display"]) then -- Check if the display name (ie HDMI1) matches the one in the config.
            if (string.find(line, "disconnected") ~= nil) then
                break -- Wrong display name was given.
            else
                local res = string.match(line, "^" .. _global.options["display"] .. "%D+([%dx]+)") -- Find current monitor resolution.
                if (res ~= nil and res ~= "") then
                    vars.resolution = res
                    vars.foundDisp = true
                else
                    break -- Could not find display resolution.
                end
            end
        elseif (vars.foundDisp == true) then -- We found the display name.
            if (vars.foundRes == false and string.match(line, "^%s+" .. vars.resolution) ~= nil) then -- Check if mode uses current display resolution.
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
                    clock = round(clock)
                    if (_global.temp["maxclock"] == nil or _global.temp["maxclock"] < clock) then
                        _global.temp["maxclock"] = clock
                    end
                    _global.modes[clock] = {
                        ["clock"] = ((vars.temp["pclock"] * 1000000) / (vtotal * vars.temp["htotal"])),
                        ["mode"] = vars.temp["mode"]
                    }
                    vars.count = 0 -- Reset variables to look for another matching resolution.
                    vars.foundRes = false
                    vars.temp = {}
                end
            elseif (string.match(line, "^%S") ~= nil) then
                break -- We reached the next display or EOF.
            end
        end
    end
    vars.handle:close()
    if (_global.next(_global.modes) == nil) then
        _global.modes = false
        return false
    end
end

function start()
    mp.unobserve_property(start)
    _global.temp = {}
    _global.temp["start_drr"] = tonumber(mp.get_property("display-fps"))
    if not (_global.temp["start_drr"]) then
        return
    end
    _global.temp["drr"] = _global.temp["start_drr"]
    if not (_global.confspeed) then
        _global.confspeed = mp.get_property("speed")
    end
    _global.estimated = false
    local test = mp.get_property("fps")
    if (test == nil or test == "nil property unavailable") then
        if (_global.options["estfps"] ~= true) then
            return
        end
        test = mp.get_property("estimated-vf-fps")
        if (test == nil or test == "nil property unavailable") then
            return
        end
        mp.observe_property("estimated-vf-fps", "number", main)
        _global.estimated = true
    else
        mp.observe_property("fps", "number", main)
    end
    mp.add_key_binding(_global.options["osdkey"], mp.get_script_name(), osdEcho, {repeatable=true})
    if (_global.options["xrandr"] == true and _global.options.exitmode ~= "") then
        function revertDrr()
            os.execute("xrandr --output " .. _global.options["display"] .. " --mode " .. _global.options["exitmode"] .. " &")
        end
        mp.register_event("shutdown", revertDrr)
    end
end

-- Wait until we get a video fps.
function check()
    mp.observe_property("estimated-vf-fps", "string", start)
end

mp.register_event("file-loaded", check)
