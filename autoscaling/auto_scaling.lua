--[[
    Disables video scaling if video resolution same or slightly lower than screen resolution.
    Enables video scaling if video resolution is higher or much lower than screen resolution.
    Change settings below.
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
    -- Set to monitor pixel width. Videos with width higher than this have scaling on.
    max_width = 1920,
    -- Set to monitor pixel height. Videos with height higher than this have scaling on.
    max_height = 1080,
    -- Videos with width between this and max_width will have scaling off.
    min_width = 1800,
    -- Videos with height between this and max_height will have scaling off 
    -- Can be left low, to allow wide aspect videos.
    min_height = 1
}
-----------------------------------------------------------------------------------------
----------------------------------- Settings end ----------------------------------------
-----------------------------------------------------------------------------------------
local debug = false
local display = {}
function main()
    local status = run()
    if (debug) then
        print(status)
    end
end
function run()
    -- Get video dimensions.
    local video = {
        width = mp.get_property("video-params/dw"),
        height = mp.get_property("video-params/dh")
    }

    -- Check if we got good values.
    if (video.width == "nil property unavailable" or video.height == "nil property unavailable") then
        return 1
    end

    video.width = tonumber(video.width)
    video.height = tonumber(video.height)

    if (video.width == nil or video.height == nil or video.width < 1 or video.height < 1) then
        return 2
    end

    local fs = mp.get_property("fullscreen")
    if (fs == nil) then
        fs = "no"
    end

    local wscale = mp.get_property("window-scale")
    if (wscale == nil) then
        wscale = 1
    end

    display.width = settings.max_width
    display.height = settings.max_height
    if (fs == "yes") then
        -- Video width same as monitor and video height equal or smaller than monitor - disable scaling.
        if (video.width == display.width and video.height <= display.height) then
            mp.set_property("video-unscaled", "yes")
            return 3
        end
        
        -- Video height same as monitor and video width equal or smaller than monitor - disable scaling.
        if (video.height == display.height and video.width <= display.width) then
            mp.set_property("video-unscaled", "yes")
            return 4
        end
    else
        -- If the window scale is 1, ignore everything, disable scaling.
        if (wscale == "1.000000") then
            mp.set_property("video-unscaled", "yes")
            return 5
        end
        
        -- We need to alter the max / min display size based on the scale of the window.
        display.width = settings.max_width * wscale
        display.height = settings.max_height * wscale

        -- New window size is smaller than thresholds. - enable scaling.
        if (display.width < settings.min_width or display.height < settings.min_height) then
            mp.set_property("video-unscaled", "no")
            return 6
        end
    end

    -- Video is bigger than display resolution - enable scaling.
    if (video.width > display.width or video.height > display.height) then
        mp.set_property("video-unscaled", "no")
        return 7
    end

    -- Video is smaller than threshold settings - enable scaling.
    if (video.width < settings.min_width or video.height < settings.min_height) then
        mp.set_property("video-unscaled", "no")
        return 8
    end

    -- Video is not too small or too big - disable scaling.
    mp.set_property("video-unscaled", "yes")
    return 0
end

mp.register_event("file-loaded", main)
mp.observe_property("window-scale", "native", main)
mp.observe_property("fullscreen", "native", main)
