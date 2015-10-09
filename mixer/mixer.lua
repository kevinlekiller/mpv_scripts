--[[
    Mixes audio based on audio channels of current playing track.
    By default this will mix to stereo.
    Change "map" variables below to alter number of output channels / input volumes.
    Uses mpv's "pan" filter http://mpv.io/manual/master/#audio-filters-pan
    
    Default keybinds are ' to print to OSD, ; to disable/enable the script.

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

--[[
From `ffprobe -layouts`

FL             front left
FR             front right
FC             front center
LFE            low frequency
BL             back left
BR             back right
FLC            front left-of-center
FRC            front right-of-center
BC             back center
SL             side left
SR             side right
TC             top center
TFL            top front left
TFC            top front center
TFR            top front right
TBL            top back left
TBC            top back center
TBR            top back right
DL             downmix left
DR             downmix right
WL             wide left
WR             wide right
SDL            surround direct left
SDR            surround direct right
LFE2           low frequency 2
--]]

local map = {
    --[[
        ["INPUT CHANNEL"] = "OUTPUT SPEAKERS/VOLUMES"
        
        For example, ["FL"] = "1,0"
        FL is the front left channel in the audio track.
        The 1 means 100% volume to the first output speaker (the left speaker).
        The 0 means 0% volume (muted) to the second output speaker (the right speaker).
    
        If we were to set ["FL"] to "0,1", then we would send the front left channel
        to the right speaker.
    
        If we were to set ["FL"] to "0,0" we would mute the front left channel.
    
        If we were to set ["FL"] "1,1" we would send the front left channel at
        100% volume to both the left and right speakers.
    
        We can also use values between 0 and 1.
    
        ["FL"] = "0.3,0.5"
        This would send the front left channel at 30% volume to the left speaker
        and 50% to the right speaker.
    
        If you have more than 2 speakers, then you set the "CHANS" variable accordingly.
    
        If you have 3 channels for example (2 speakers and a subwoofer), then you set
        "CHANS" to 3 and change all the "INPUT CHANNELS" accordingly,
        ["FL"] = "1,0,0"   ["FR"] = "0,1,0"   ["LFE"] = "0,0,1" and so on.
    
        You might have to experiment to figure out which speaker matches which number.
        You can do this easily by playing a stereo file, then you set everything to 0
        and change one of the 0's to 1 and see which speaker plays
        (for example, on a 6 speaker system: "1,0,0,0,0,0", then note which speaker plays, then try "0,1,0,0,0,0" and so on). 
    --]]
    ["FL"]   = "1,0",
    ["FR"]   = "0,1",
    ["FC"]   = "0.5,0.5",
    ["LFE"]  = "1,1",
    ["BL"]   = "1,0",
    ["BR"]   = "0,1",
    ["FLC"]  = "1,0",
    ["FRC"]  = "0,1",
    ["BC"]   = "0.5,0.5",
    ["SL"]   = "1,0",
    ["SR"]   = "0,1",
    ["TC"]   = "0.5,0.5",
    ["TFL"]  = "1,0",
    ["TFC"]  = "0.5,0.5",
    ["TFR"]  = "0,1",
    ["TBL"]  = "1,0",
    ["TBC"]  = "0.5,0.5",
    ["TBR"]  = "0,1",
    ["DL"]   = "1,0",
    ["DR"]   = "0,1",
    ["WL"]   = "1,0",
    ["WR"]   = "0,1",
    ["SDL"]  = "1,0",
    ["SDR"]  = "0,1",
    ["LFE2"] = "1,1",
    
    
    ["CHANS"] = "2", -- Number of output channels.

    ["OSD"]      = true, -- Print to OSD?
    ["OSDSTART"] = true,  -- Print to OSD on start?
    ["OSDKEY"]   = "'",   -- Key to print on OSD.
    ["OSDTIME"]  = 5,     -- Seconds for OSD message to remain on screen.
    
    ["TOGGLE"]  = ";"    -- Key to toggle on/off the script during playback.
}

------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
local _global = {
    aid = "",
    layout = "",
    layouts = {
        ["mono"]           = "FC",
        ["stereo"]         = "FL+FR",
        ["2.1"]            = "FL+FR+LFE",
        ["3.0"]            = "FL+FR+FC",
        ["3.0(back)"]      = "FL+FR+BC",
        ["4.0"]            = "FL+FR+FC+BC",
        ["quad"]           = "FL+FR+BL+BR",
        ["quad(side)"]     = "FL+FR+SL+SR",
        ["3.1"]            = "FL+FR+FC+LFE",
        ["5.0"]            = "FL+FR+FC+BL+BR",
        ["5.0(side)"]      = "FL+FR+FC+SL+SR",
        ["4.1"]            = "FL+FR+FC+LFE+BC",
        ["5.1"]            = "FL+FR+FC+LFE+BL+BR",
        ["5.1(side)"]      = "FL+FR+FC+LFE+SL+SR",
        ["6.0"]            = "FL+FR+FC+BC+SL+SR",
        ["6.0(front)"]     = "FL+FR+FLC+FRC+SL+SR",
        ["hexagonal"]      = "FL+FR+FC+BL+BR+BC",
        ["6.1"]            = "FL+FR+FC+LFE+BC+SL+SR",
        ["6.1(front)"]     = "FL+FR+LFE+FLC+FRC+SL+SR",
        ["7.0"]            = "FL+FR+FC+BL+BR+SL+SR",
        ["7.0(front)"]     = "FL+FR+FC+FLC+FRC+SL+SR",
        ["7.1"]            = "FL+FR+FC+LFE+BL+BR+SL+SR",
        ["7.1(wide)"]      = "FL+FR+FC+LFE+BL+BR+FLC+FRC",
        ["7.1(wide-side)"] = "FL+FR+FC+LFE+FLC+FRC+SL+SR",
        ["octagonal"]      = "FL+FR+FC+BL+BR+BC+SL+SR",
        ["hexadecagonal"]  = "FL+FR+FC+BL+BR+BC+SL+SR+TFL+TFC+TFR+TBL+TBC+TBR+WL+WR",
        ["downmix"]        = "DL+DR"
    },
    panLayouts = {},
    startAf = mp.get_property("af"),
    baseAf = "",
    currentAf = "",
    osd_start = mp.get_property_osd("osd-ass-cc/0"),
    osd_end = mp.get_property_osd("osd-ass-cc/1"),
    osd_out = "",
    off = false
}

function main()
    local aid = mp.get_property("aid")
    if (aid == nil or aid == "no" or aid == "") then
        _global.aid = false
        return
    else
        _global.aid = true
    end
    _global.layout = getLayout()
    if (_global.layout == "" or _global.layouts[_global.layout] == nil) then
        return
    end

    getAf();
    getPan()
    setPan()
    
    if (map["OSD"] == true) then
        _global.osd_out = (_global.osd_start .. "mixer:" .. "\\N" ..
                "Input: " .. _global.layout .. " " .. _global.layouts[_global.layout] .. "\\N" ..
                "Output: " .. map["CHANS"] .. " audio channels" .. "\\N" ..
                "Filter: " .. _global.panLayouts[_global.layout] .. _global.osd_end
        )
        if (map["OSDSTART"] == true) then
            osd()
        end
    end
end

function getLayout()
    -- {"samplerate":44100,"channel-count":2,"channels":"stereo","hr-channels":"stereo","format":"floatp"}
    local params = mp.get_property("audio-params")
    if (params == nil) then
        return ""
    end
    local channels, hr_channels = string.match(params, '"channels":"(.*)","hr%-channels":"(.*)","format":')
    local layout = ""
    if (channels ~= nil and _global.layouts[channels] ~= nil) then
        return channels
    elseif (hr_channels ~= nil and _global.layouts[hr_channels] ~= nil) then
        return hr_channels
    else
        return ""
    end
end

function getAf()
    local first, last = string.match(_global.startAf, '(.*)pan=.*matrix=[%%%d,]+(.*)')
    if (first == nil or last == nil) then
        _global.baseAf = _global.startAf
        return
    end
    first = first:gsub("^%s+", "")
    last = last:gsub("%s+$", "")
    if (first ~= "" and last == "") then
        local temp = string.sub(first, -1, -1)
        if (temp == ",") then
            first = string.sub(first, 1, -2)
        end
    end
    _global.baseAf = ""
end

function getPan()
    if (_global.panLayouts[_global.layout] ~= nil) then
        return
    end
    local temp = "pan=channels=" .. map["CHANS"] .. ":matrix=["
    for value in string.gmatch(_global.layouts[_global.layout],'%w+') do
        temp = temp .. map[value] .. ","
    end
    temp = string.sub(temp, 1, -2) .. "]"
    _global.panLayouts[_global.layout] = temp
end

function setPan()
    local temp = _global.panLayouts[_global.layout]
    if (_global.baseAf ~= "") then
        temp = temp .. _global.baseAf
    end
    _global.currentAf = temp
    if (_global.off == false) then
        mp.set_property("af", temp)
    end
end

function osd()
    if (_global.aid == false or _global.off == true) then
        mp.osd_message(_global.osd_start .. "mixer: Disabled." .. _global.osd_end, map["OSDTIME"])
    else
        mp.osd_message(_global.osd_out, map["OSDTIME"])
    end
end

function toggle()
    if (_global.off == true) then
        _global.off = false
        if (_global.currentAf ~= "") then
            mp.set_property("af", _global.currentAf)
        end
    else
        _global.off = true
        mp.set_property("af", _global.startAf)
    end
end

mp.register_event("audio-reconfig", main)
if (map["OSD"] == true) then
    mp.add_key_binding(map["OSDKEY"], osd)
end
mp.add_key_binding(map["TOGGLE"], toggle)
