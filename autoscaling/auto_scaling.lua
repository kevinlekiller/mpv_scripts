--[[
    Disables video scaling if the video is close to screen resolution.
    If a video is for example 1916x1038, scaling will the disabled.
    Change settings below.

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

-----------------------------------------------------------------------------------------
---------------------------------- Settings start ---------------------------------------
-----------------------------------------------------------------------------------------
-- All 4 of the following must be "true" for video scaling to be disabled.
local settings = {
    -- Videos with width under this will have scaling turned off. Set it to the monitor pixel width.
    max_width = 1920,
    -- Videos with height under this will have scaling turned off. Set it to the monitor pixel height.
    max_height = 1080,
    -- Videos with width over this will have scaling turned off.
    min_width = 1850,
    -- Videos with height over this will have scaling turned off.
    min_height = 1
}
-----------------------------------------------------------------------------------------
----------------------------------- Settings end ----------------------------------------
-----------------------------------------------------------------------------------------

function main()
    local video = {
        width = mp.get_property("video-params/dw"),
        height = mp.get_property("video-params/dh")
    }

    if (video.width == "nil property unavailable" or video.height == "nil property unavailable") then
        return 1
    end

    video.width = tonumber(video.width)
    video.height = tonumber(video.height)

    if (video.width == nil or video.height == nil or video.width < 1 or video.height < 1) then
        return 2
    end

    -- Video is bigger than display resolution - enable scaling.
    if (video.width > settings.max_width or video.height > settings.max_height) then
        mp.set_property("video-unscaled", "no")
        return 3
    end

    -- Video is smaller than threshold settings - enable scaling.
    if (video.width < settings.min_width or video.height < settings.min_height) then
        mp.set_property("video-unscaled", "no")
        return 4
    end

    -- Video is bigger than mpv window - enable scaling.
    local fs = mp.get_property("fullscreen")
    local wscale = mp.get_property("window-scale")
    if (fs ~= nil and fs == "no" and wscale ~= nil) then
        if (video.width > (settings.max_width * wscale) or video.height > (settings.max_height * wscale)) then
            mp.set_property("video-unscaled", "no")
            return 5
        end
    end

    -- Video is not too small or too big - disable scaling.
    mp.set_property("video-unscaled", "yes")
    return 0
end

loaded = mp.register_event("file-loaded", main)
mp.observe_property("window-scale", "native", main)
mp.observe_property("fullscreen", "native", main)
