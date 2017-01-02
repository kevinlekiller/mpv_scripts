--[[
    https://github.com/kevinlekiller/mpv_scripts
    
    When a file is loaded into mpv, this script will check if it's a local mkv file.
    If the file is missing replaygain tags, it will scan them with bs1770gain,
    using --ebu, --samplepeak (much faster than --truepeak) and --range options.
    If bs1770gain succeeds, tags are applied using mkvpropedit.
    mpv will then see the replaygain tags, and use them if you have the 
    appropriate setting : https://mpv.io/manual/master/#audio-filters-volume
    For example : mpv --af=volume:replaygain-track:detach
    
    You can enable mkvrg.lua OSD messages in mpv by passing the script-opts
    option mkvrg-osd=true, like this: mpv --script-opts=mkvrg-osd=true
    
    These programs are required for this script to function:
    bs1770gain : http://bs1770gain.sourceforge.net/
    mkvpropedit : https://mkvtoolnix.download/
    
    This script is based on https://github.com/kevinlekiller/mkvrg
--]]
--[[
    Copyright (C) 2017  kevinlekiller

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

local osd = mp.get_opt("mkvrg-" .. "osd")
osd = (osd ~= nil and osd == "true")
local utils = require 'mp.utils'
local msg = require 'mp.msg'

local function file_exists(path)
    local handle = io.open(path, "r")
    if handle ~= nil then
        handle:close()
        return true
    end
    return false
end

local function process()
    if mp.get_property("file-format") ~= "mkv" then
        msg.info("File is not mkv, skipping.")
        return
    end
    local tlist = mp.get_property_native("track-list")
    if type(tlist) ~= "table" then
        return
    end
    local ids = false
    for key,value in pairs(tlist) do
        if value["external"] then
            msg.info("File is not local. skipping.")
            break
        elseif (value["type"] == "audio" and value["selected"] == true) then
            if (value["replaygain-track-gain"] == nil and value["replaygain-track-peak"] == nil) then
                ids = {["ffid"] = value["ff-index"], ["id"] = value["id"]}
                msg.info("No replaygain found, processing file.")
            else
                msg.info("File already has replaygain info. skipping.")
            end
            break
        end
    end
    if type(ids) ~= "table" then
        return
    end
    local path = mp.get_property("working-directory") .. "/" .. mp.get_property("path")
    if not file_exists(path) then
        msg.warn("File not found: '" .. path .. "', skipping.")
        return
    end
    if osd then
        mp.osd_message("mkvrg: Scanning file for replaygain, this can take a few minutes.", 10)
    end
    local output = utils.subprocess({
        ["cancellable"] = false,
        ["args"] = {
            [1] = "bs1770gain",
            [2] = "--ebu",
            [3] = "--audio",
            [4] = ids["ffid"],
            [5] = "-rp",
            [6] = path,
        }
    })
    if osd then
        mp.osd_message("", 0)
    end
    if output["error"] ~= nil then
        msg.warn("Problem getting replaygain info from bs1770gain, skipping.")
        return
    end
    local rg = {["gain"] = false, ["range"] = false, ["peak"] = false}
    for line in string.gmatch(output["stdout"], "[^\r\n]+") do
        if (rg["gain"] and rg["range"] and rg["peak"]) then
            break
        end
        if (rg["gain"] == false and string.match(line, "integrated")) then
            rg["gain"] = string.gsub(line, "%s*integrated.*/%s+", "")
            rg["gain"] = string.gsub(rg["gain"], "%s+LU%s*", "")
        elseif (rg["range"] == false and string.match(line, "range")) then
            rg["range"] = string.gsub(line, "%s*range:%s*", "")
            rg["range"] = string.gsub(rg["range"], "%s*LUFS%s*", "")
        elseif (rg["peak"] == false and string.match(line, "peak")) then
            rg["peak"] = string.gsub(line, "%s*sample%s*peak.*/%s+", "")
            rg["peak"] = string.gsub(rg["peak"], "s*$", "")
        end
    end
    if not (rg["gain"] and rg["range"] and rg["peak"]) then
        msg.warn("Could not parse replaygain info for file, skipping.")
        return
    end
    local xml = [===[<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE Tags SYSTEM "matroskatags.dtd">
<Tags>
  <Tag>
    <Targets>
    </Targets>
    <Simple>
      <Name>REPLAYGAIN_ALGORITHM</Name>
      <String>ITU-R BS.1770</String>
    </Simple>
    <Simple>
      <Name>REPLAYGAIN_REFERENCE_LOUDNESS</Name>
      <String>-23.0</String>
    </Simple>
    <Simple>
      <Name>REPLAYGAIN_TRACK_GAIN</Name>
      <String>]===] .. rg["gain"] ..  [===[</String>
    </Simple>
    <Simple>
      <Name>REPLAYGAIN_TRACK_RANGE</Name>
      <String>]===] .. rg["range"] .. [===[</String>
    </Simple>
    <Simple>
      <Name>REPLAYGAIN_TRACK_PEAK</Name>
      <String>]===] .. rg["peak"] .. [===[</String>
    </Simple>
  </Tag>
</Tags>]===]

    local tmppath = os.tmpname()
    local handle = io.open(tmppath, "w")
    if handle == nil then
        msg.warn("Could not open '" .. tmppath .. "' for writing, skipping.")
        return
    end
    handle:write(xml)
    handle:close()
    if os.execute("mkvpropedit --tags track:" .. (tonumber(ids["ffid"]) + 1)  .. ":" .. tmppath .. " " .. path) ~= 0 then
        msg.warn("Could not write replaygain tags to file with mkvpropedit.")
    end
    os.remove(tmppath)
    local index = mp.get_property("playlist-pos")
    mp.command("loadfile " .. path .. " append-play")
    mp.command("playlist-remove " .. index)
end

local function start()
    local paused = mp.get_property("pause")
    if paused == "no" then
        mp.set_property("pause", "yes")
    end
    process()
    if paused == "no" then
        mp.set_property("pause", "no")
    end
end

mp.register_event("file-loaded", start)
