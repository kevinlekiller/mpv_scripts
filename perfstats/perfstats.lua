--[[
    mpv script for displaying statistics on dropped frames and video output performance.
    
    Default keybinding is ` (the key under Escape on US keyboards).
    
    Frames:
        Dropped:    https://mpv.io/manual/master/#command-interface-drop-frame-count
        VO Dropped: https://mpv.io/manual/master/#command-interface-vo-drop-frame-count
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
    
    Note: All time measurements are in microseconds.
    
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

local keybinding = "`"
local font_size = 7
-- Time in seconds to show the message on mpv's osd.
local osd_time = 8

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
local osdh = mp.get_property_osd("osd-ass-cc/0")
local osdt = mp.get_property_osd("osd-ass-cc/1")
local msg = require 'mp.msg'
local properties0 = {
    ["Dropped"]     = "drop-frame-count",
    ["VO Dropped:"] = "vo-drop-frame-count",
    ["Mistimed:"]   = "mistimed-frame-count",
    ["VO Delayed:"] = "vo-delayed-frame-count"
}
local properties1 = {
    ["render"]  = "vo-performance/render-",
    ["upload"]  = "vo-performance/upload-",
    ["present"] = "vo-performance/present-",
}
function perfstats()
    local out = osdh .. "{\\fs" .. font_size .. "}Frames:\\N"
    for key,property in pairs(properties0) do
        local prop = mp.get_property(property)
        if (prop == nil) then
            msg.warn("Got a nil value from mpv for property : " .. property)
            return
        end
        out = out .. key .. "\\h" .. prop .."\\N"
    end
    local totals = {["avg"] = 0, ["last"] = 0, ["peak"] = 0}
    for key,property in pairs(properties1) do
        out = out .. "_________\\NVideo output performance (" .. key .. "):\\N"
        for k,name in ipairs({"last", "avg", "peak"}) do
            local prop = mp.get_property(properties1[key] .. name)
            if (prop == nil) then
                msg.warn("Got a nil value from mpv for property : " .. properties1[key] .. name)
                return
            end
            totals[name] = totals[name] + prop
            out = out .. name .. ":\\h" .. prop .. "μs\\N"
        end
    end
    out = out .. "_________\\NVideo output performance (total):\\N"
    for key,total in pairs(totals) do
        out = out .. key .. ":\\h" .. total .. "μs\\N"
    end
    local prop = mp.get_property("display-fps")
    if (prop ~= nil) then
        out = out .. "_________\\NDisplay information:\\NRefresh rate:\\h" .. prop .. "Hz\\N"
        out = out .. "Frame time:\\h" .. (1000000 / prop) .. "μs\\N"
    end
    mp.osd_message(out .. osdt, osd_time)
end
mp.add_key_binding(keybinding, mp.get_script_name(), perfstats, {repeatable=true})
