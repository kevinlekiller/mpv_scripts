--[[
    See script details on https://github.com/kevinlekiller/mpv_scripts
    
    Valid --script-opts are (they are all optional):
    autospeed-xrandr=false     true/false - Use xrandr to change display refresh rate?.
    autospeed-speed=false      true/false - Adjust speed of the video?
    autospeed-display=HDMI1               - Use specified xrandr display, find with xrandr -q, if set to "auto", uses the primary monitor.
    autospeed-exitmode=0x48               - Changes the monitor mode (refresh rate) when exiting mpv.
                                            autospeed-exitmode=false Don't change the mode when exiting. If autospeed-exitmode is not set, this is the default.
                                            autospeed-exitmode=auto Change the mode to the mode used when mpv started.
                                            autospeed-exitmode=0x48 Revert to specified mode when exiting mpv. Find a mode using xrandr --verbose (it should look something like 0x123).
    autospeed-interlaced=false true/false - Allow using a interlaced mode when switching refresh rates with xrandr?
    autospeed-mblacklist=false            - List of modes to blacklist.
                                            Modes in this list will be ignored.
                                            If more than one mode is specified, seperate them by semicolon.
                                            Example: autospeed-mblacklist="0x128;0x2fa"
    autospeed-minspeed=0.9     Number     - Minimum allowable speed to play video at.
    autospeed-maxspeed=1.1     Number     - Maximum allowable speed to play video at.
    autospeed-osd=true         true/false - Enable OSD.
    autospeed-osdtime=10       Number     - How many seconds the OSD will be shown.
    autospeed-osdkey=y                    - Key to press to show the OSD.
    autospeed-estfps=false     true/false - Calculate/change speed if a video has a variable fps at the cost of higher CPU usage (most videos have a fixed fps).
    autospeed-spause           true/false - Pause video while switching display modes.
                               Number     - If you set this a number, it will pause for that amount of seconds.

    Example: mpv file.mkv --script-opts=autospeed-xrandr=true,autospeed-speed=false,autospeed-minspeed=0.8
--]]
--[[
    Copyright (C) 2015-2017  kevinlekiller

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
    modes = {},
    modeCache = {},
    lastDrr = 0,
    speedCache = {},
    next = next,
}

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
        ["xrandr"]     = false,
        ["speed"]      = false,
        ["display"]    = "auto",
        ["exitmode"]   = "auto",
        ["interlaced"] = false,
        ["mblacklist"] = "false",
        ["minspeed"]   = 0.9,
        ["maxspeed"]   = 1.1,
        ["osd"]        = false,
        ["osdtime"]    = 10,
        ["osdkey"]     = "y",
        ["estfps"]     = false,
        ["spause"]     = false,
    }
    for key, value in pairs(_global.options) do
        local opt = mp.get_opt("autospeed-" .. key)
        if (opt ~= nil) then
            if (key == "xrandr" or key == "osd" or key == "estfps" or key == "interlaced" or key == "speed") then
                if (opt == "true") then
                    _global.options[key] = true
                end
            elseif (key == "minspeed" or key == "maxspeed" or key == "osdtime") then
                opt = tonumber(opt)
                if (opt ~= nil) then
                    _global.options[key] = opt
                end
            elseif (key == "spause") then
                if (opt == "true") then
                    _global.options[key] = 0
                else
                    opt = tonumber(opt)
                    if (opt ~= nil) then
                        _global.options[key] = opt
                    end
                end
            else
                _global.options[key] = opt
            end
        end
    end
    if (_global.options["mblacklist"] == "false") then
        _global.options["mblacklist"] = false
    else
        local tmp_blacklist = {}
        for blacklist in string.gmatch(_global.options["mblacklist"], '[0-9a-zA-Z]+') do
            tmp_blacklist[blacklist] = true
        end
        _global.options["mblacklist"] = tmp_blacklist
    end
end
getOptions()

function main(name, fps)
    if (fps == nil) then
        return
    end
    _global.temp["fps"] = fps
    findRefreshRate()
    if (_global.options["speed"] == true) then
        determineSpeed()
        if (_global.temp["speed"] >= _global.options["minspeed"] and _global.temp["speed"] <= _global.options["maxspeed"]) then
            mp.set_property_number("speed", _global.temp["speed"])
        else
            _global.temp["speed"] = _global.confSpeed
        end
    else
        _global.temp["speed"] = _global.confSpeed
    end
end

function setOSD()
    _global.temp["output"] = (_global.osd_start ..
        "{\\b1}Original monitor refresh rate{\\b0}\\h\\h" .. _global.temp["start_drr"] .. "Hz\\N" ..
        "{\\b1}Current  monitor refresh rate{\\b0}\\h\\h" .. _global.temp["drr"] .. "Hz\\N" ..
        "{\\b1}Original video fps{\\b0}\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h" .. _global.temp["fps"] .. "fps\\N" ..
        "{\\b1}Current  video fps{\\b0}\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h\\h" .. (_global.temp["fps"] * _global.temp["speed"]) .. "fps\\N" ..
        "{\\b1}Original mpv speed setting{\\b0}\\h\\h\\h\\h\\h\\h" .. _global.confSpeed .. "x\\N" ..
        "{\\b1}Current  mpv speed setting{\\b0}\\h\\h\\h\\h\\h\\h" .. _global.temp["speed"] .. "x" ..
        _global.osd_end
    )
end

function determineSpeed()
    local id = _global.temp["drr"] .. _global.temp["fps"]
    if (_global.speedCache[id] ~= nil) then
        _global.temp["speed"] = _global.speedCache[id]
        return
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
        return
    elseif (_global.modeCache[_global.temp["drr"]] ~= nil) then
        setXrandrRate(_global.modeCache[_global.temp["drr"]])
        return
    end
    if (_global.options["xrandr"] ~= true or getXrandrModes() == false) then
        return
    end
    -- If the current monitor rate is already a multiple, don't change the mode.
    if (_global.temp["fps"] <= _global.temp["drr"] and _global.temp["drr"] % _global.temp["fps"] == 0) then
        return
    end
    local round_fps = round(_global.temp["fps"])
    local iterator = 1
    if (_global.temp["maxclock"] > round_fps) then
        iterator = round(_global.temp["maxclock"] / round_fps)
    elseif (_global.temp["maxclock"] < round_fps) then
        iterator = round(round_fps / _global.temp["maxclock"])
    else
        setXrandrRate(_global.modes[_global.temp["maxclock"]])
        return
    end
    local smallest = 0
    local foundMode = false
    for rate, mode in pairs(_global.modes) do
        local min = (rate * _global.options["minspeed"])
        local max = (rate * _global.options["maxspeed"])
        for multiplier = 1, iterator do
            local multiplied_fps = (multiplier * round_fps)
            if (multiplied_fps >= min and multiplied_fps <= max) then
                if (multiplied_fps < rate) then
                    local difference = (rate - multiplied_fps)
                    if (smallest == 0 or difference < smallest) then
                        smallest = difference
                        foundMode = mode
                    end
                elseif (multiplied_fps > rate) then
                    local difference = (multiplied_fps - rate)
                    if (smallest == 0 or difference < smallest) then
                        smallest = difference
                        foundMode = mode
                    end
                else
                    setXrandrRate(mode)
                    return
                end
            end
        end
    end
    if (foundMode ~= false) then
        setXrandrRate(foundMode)
    end
end

function setXrandrRate(mode)
    if (mode == _global.temp["currentmode"]) then
        return
    end
    local vars = {vid = nil, time_pos = nil, vdpau = (mp.get_property("options/vo") == "vdpau" or mp.get_property("options/hwdec") == "vdpau")}
    if (_global.options["spause"]) then
        mp.set_property("pause", "yes")
    end
    if (vars.vdpau) then
        vars.vid = mp.get_property("vid")
        vars.time_pos = mp.get_property("time-pos")
        mp.set_property("vid", "no")
    end
    _global.utils.subprocess({["cancellable"] = false, ["args"] = {[1] = "xrandr", [2] = "--output", [3] = _global.options["display"], [4] = "--mode", [5] = mode,}})
    if (_global.options["spause"]) then
        if (tonumber(_global.options["spause"]) ~= nil and _global.options["spause"] > 0) then
            _global.utils.subprocess({["cancellable"] = false, ["args"] = {[1] = "sleep", [2] = _global.options["spause"]}})
        end
        mp.set_property("pause", "no")
    end
    if (vars.vdpau) then
        mp.set_property("vid", vars.vid)
        if (vars.time_pos ~= nil) then
            mp.commandv("seek", vars.time_pos, "absolute", "keyframes")
        end
    end
    _global.utils.subprocess({["cancellable"] = false, ["args"] = {[1] = "sleep", [2] = "0.5"}})
    _global.temp["drr"] = mp.get_property_native("display-fps")
    _global.modeCache[_global.temp["drr"]] = mode
    _global.lastDrr = _global.temp["drr"]
    _global.temp["currentmode"] = mode
end

function getXrandrModes()
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
        resolution,
    }
    if (_global.options["display"] == "auto") then
        vars.disp = "^%S+%sconnected%sprimary"
    else
        vars.disp = "^" .. string.gsub(_global.options["display"], "%-", "%%-")
    end
    _global.temp["maxclock"] = 0
    for line in vars.handle:lines() do
        if (vars.foundDisp == false and string.match(line, vars.disp) ~= nil) then -- Check if the display name (ie HDMI1) matches the one in the config.
            if (string.find(line, "disconnected") ~= nil) then
                break -- Wrong display name was given.
            else
                local res = string.match(line, vars.disp .. "%D+([%dx]+)") -- Find current monitor resolution.
                if (res ~= nil and res ~= "") then
                    if (_global.options["display"] == "auto") then
                        _global.options["display"] = string.match(line, "^%S+")
                    end
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
                if (vars.count == 1) then -- Log the mode name.
                    vars.mode = string.match(line, "%((.+)%)%s+[%d.]+MHz")
                    if (_global.temp["origmode"] == nil) then
                        if (string.find(line, "%*current") ~= nil) then
                            _global.temp["origmode"] = vars.mode
                            _global.temp["currentmode"] = vars.mode
                        end
                    end
                    vars.interlaced = false
                    if (string.find(line, "Interlace") ~= nil) then
                        vars.interlaced = true
                    end
                elseif (vars.count == 2) then
                    
                elseif (vars.count == 3) then
                    if ((_global.options["interlaced"] == false and vars.interlaced == true) or (_global.options["mblacklist"] ~= false and _global.options["mblacklist"][vars.mode] ~= nil)) then
                        -- ignore these modes
                    else
                        local clock = string.match(line, "total%s+%d+.+clock%s+([%d.]+)[KkHh]+z")
                        clock = round(clock)
                        if (_global.temp["maxclock"] < clock) then
                            _global.temp["maxclock"] = clock
                        end
                        _global.modes[clock] = vars.mode
                    end
                    vars.count = 0 -- Reset variables to look for another matching resolution.
                    vars.foundRes = false
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
    _global.temp["start_drr"] = mp.get_property_native("display-fps")
    if not (_global.temp["start_drr"]) then
        return
    end
    _global.temp["drr"] = _global.temp["start_drr"]
    if not (_global.confSpeed) then
        _global.confSpeed = mp.get_property_native("speed")
    end
    local test = mp.get_property("container-fps")
    if (test == nil or test == "nil property unavailable") then
        if (_global.options["estfps"] ~= true) then
            return
        end
        test = mp.get_property("estimated-vf-fps")
        if (test == nil or test == "nil property unavailable") then
            return
        end
        mp.observe_property("estimated-vf-fps", "number", main)
    else
        mp.observe_property("container-fps", "number", main)
    end
    mp.add_key_binding(_global.options["osdkey"], mp.get_script_name(), osdEcho, {repeatable=true})
    if (_global.options["xrandr"] == true and _global.options.exitmode ~= "false") then
        function revertDrr()
            if (_global.options["display"] ~= "auto") then
                if (_global.options["exitmode"] == "auto" and _global.temp["origmode"] ~= nil) then
                    os.execute("xrandr --output " .. _global.options["display"] .. " --mode " .. _global.temp["origmode"] .. " &")
                else
                    os.execute("xrandr --output " .. _global.options["display"] .. " --mode " .. _global.options["exitmode"] .. " &")
                end
            end
        end
        mp.register_event("shutdown", revertDrr)
    end
end

-- Wait until we get a video fps.
function check()
    mp.observe_property("estimated-vf-fps", "string", start)
end

mp.register_event("file-loaded", check)
