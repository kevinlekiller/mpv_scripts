--[[
    Script to maximize mpv on start or fullscreen exit on Windows O/S using nircmd.
    Requires nircmdc.exe in PATH

    https://github.com/kevinlekiller/mpv_scripts
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

-- This is better than os.execute since it doesn't pop up command prompts.
mputils = require 'mp.utils'
local command = {}
command["args"] = {}
command["args"][1] = "nircmdc"
command["args"][2] = "win"
command["args"][3] = ""
command["args"][4] = "process"
command["args"][5] = "mpv.exe"

-- This is so we don't run maximize_no_fs 2 times on start.
local start = true

-- Maximize the window on start on Windows O/S using nircmd.
function maximize_start()
	start = false
	if (mp.get_property("fullscreen") == "no") then
		command["args"][3] = "max"
		mputils.subprocess(command)
	end
end
mp.register_event("video-reconfig", maximize_start)

-- Maximize the window when exiting fullscreen.
function maximize_no_fs()
	if (start == false and mp.get_property("fullscreen") == "no") then
		-- This is kind of a hack to force it to maximize.
		command["args"][3] = "togglemax"
		mputils.subprocess(command)
		command["args"][3] = "max"
		mputils.subprocess(command)
	end
end
mp.observe_property("fullscreen", "string", maximize_no_fs)
