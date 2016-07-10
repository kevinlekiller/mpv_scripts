--[[
    Displays statistics on dropped frames and video output performance.
    
    Default keybinding is ` (the key under Escape on US keyboards).
    
    Frames:
        Dropped:    https://mpv.io/manual/master/#command-interface-drop-frame-count
        VO Dropped: https://mpv.io/manual/master/#command-interface-vo-drop-frame-count
        Mistimed:   https://mpv.io/manual/master/#command-interface-mistimed-frame-count
        VO Delayed:    https://mpv.io/manual/master/#command-interface-vo-delayed-frame-count
    
    Video output performance:
        upload:  https://mpv.io/manual/master/#command-interface-upload
        render:  https://mpv.io/manual/master/#command-interface-render
        present: https://mpv.io/manual/master/#command-interface-present
        Total:   Combined amount of time of the above 3 (this should stay lower than
                 your display frame time, if it goes higher, you will want to tweak
                 mpv settings).
        
        last:    How much time it took for the last frame; https://mpv.io/manual/master/#command-interface-last
        average: How much time it took for the last few frames; https://mpv.io/manual/master/#command-interface-avg
                 Note: Wait 5 to 10 seconds at the start of a video for the average to settle.
    
    Maximum display frame time:
        This is how much time your computer monitor spends displaying a single frame.
    
    Note: All time measurements are in microseconds.
    
    https://github.com/kevinlekiller/mpv_scripts
--]]
--[[
    Copyright (C) 2016  kevinlekiller
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
function perfstats()
    local uplast = mp.get_property("vo-performance/upload-last")
    if (uplast == nil or uplast == "nil property unavailable") then
        return
    end
    local rendlast = mp.get_property("vo-performance/render-last")
    local preslast = mp.get_property("vo-performance/present-last")
    local upavg = mp.get_property("vo-performance/upload-avg")
    local rendavg = mp.get_property("vo-performance/render-avg")
    local presavg = mp.get_property("vo-performance/present-avg")
    mp.osd_message(osdh ..
        "{\\fs" .. font_size .. "}Frames:\\NDropped\\h" .. mp.get_property("drop-frame-count") ..
        "\\NVO Dropped:\\h" .. mp.get_property("vo-drop-frame-count") ..
        "\\NMistimed:\\h" .. mp.get_property("mistimed-frame-count") ..
        "\\NDelayed:\\h" .. mp.get_property("vo-delayed-frame-count") ..
        "\\N_________\\NVideo output performance (last frame):\\Nupload:\\h" ..
        uplast ..
        "μs\\Nrender:\\h" .. rendlast ..
        "μs\\Npresent:\\h" .. preslast ..
        "μs\\NTotal:\\h" .. (uplast + rendlast + preslast) ..
        "μs\\N_________\\NVideo output performance (averaged):\\Nupload:\\h" ..
        upavg ..
        "μs\\Nrender:\\h" .. rendavg ..
        "μs\\Npresent:\\h" .. presavg ..
        "μs\\NTotal:\\h" .. (upavg + rendavg + presavg) ..
        "μs\\N_________\\NMaximum display frame time:\\N" ..
        (1000000 / mp.get_property("display-fps")) .. "μs\\N" ..
        osdt,
        osd_time
    )
end
mp.add_key_binding(keybinding, mp.get_script_name(), perfstats, {repeatable=true})
