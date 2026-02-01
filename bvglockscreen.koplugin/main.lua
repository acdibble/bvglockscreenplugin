local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local Device = require("device")
local Screen = Device.screen
local Blitbuffer = require("ffi/blitbuffer")
local ScreenSaverWidget = require("ui/widget/screensaverwidget")
local NetworkMgr = require("ui/network/manager")
local logger = require("logger")
local _ = require("gettext")

local BVGLockscreen = WidgetContainer:extend{
    name = "bvglockscreen",
    is_doc_only = false,
    refresh_interval = 15, -- refresh every 15 seconds
    refresh_task = nil,
    screensaver_active = false,
}

function BVGLockscreen:init()
    self.ui.menu:registerToMainMenu(self)
    self:patchDofile()
    self:patchScreensaver()

    -- Create the refresh task function
    self.refresh_task = function()
        self:refreshScreensaver()
    end
end

function BVGLockscreen:addToMainMenu(menu_items)
    local BVGMenu = require("bvg_menu")
    menu_items.bvg_lockscreen = BVGMenu:getMenuTable()
end

function BVGLockscreen:scheduleRefresh()
    if self.screensaver_active then
        logger.dbg("BVGLockscreen: Scheduling refresh in", self.refresh_interval, "seconds")
        UIManager:scheduleIn(self.refresh_interval, self.refresh_task)
    end
end

function BVGLockscreen:unscheduleRefresh()
    if self.refresh_task then
        UIManager:unschedule(self.refresh_task)
        logger.dbg("BVGLockscreen: Refresh task unscheduled")
    end
end

function BVGLockscreen:refreshScreensaver()
    if not self.screensaver_active then
        return
    end

    logger.dbg("BVGLockscreen: Refreshing departures")

    local Screensaver = require("ui/screensaver")
    local DisplayDepartures = require("display_departures")

    -- Create new widget with fresh data
    local widget = DisplayDepartures:createScreensaverWidget()

    if widget and Screensaver.screensaver_widget then
        -- Close old widget and show new one
        UIManager:close(Screensaver.screensaver_widget)

        Screensaver.screensaver_widget = ScreenSaverWidget:new{
            widget = widget,
            background = Blitbuffer.COLOR_WHITE,
            covers_fullscreen = true,
        }
        Screensaver.screensaver_widget.modal = true
        Screensaver.screensaver_widget.dithered = true

        UIManager:show(Screensaver.screensaver_widget, "full")
        logger.dbg("BVGLockscreen: Widget refreshed")
    end

    -- Schedule next refresh
    self:scheduleRefresh()
end

function BVGLockscreen:patchDofile()
    -- Patch dofile to inject our menu item into screensaver_menu.lua
    if not _G._orig_dofile_before_bvg then
        local orig_dofile = dofile
        _G._orig_dofile_before_bvg = orig_dofile

        _G.dofile = function(filepath)
            local result = orig_dofile(filepath)

            -- Check if this is the screensaver menu being loaded
            if filepath and filepath:match("screensaver_menu%.lua$") then
                logger.dbg("BVGLockscreen: Patching screensaver menu")

                if result and result[1] and result[1].sub_item_table then
                    local wallpaper_submenu = result[1].sub_item_table

                    local function genMenuItem(text, setting, value)
                        return {
                            text = text,
                            checked_func = function()
                                return G_reader_settings:readSetting(setting) == value
                            end,
                            callback = function()
                                G_reader_settings:saveSetting(setting, value)
                            end,
                            radio = true,
                        }
                    end

                    -- Add BVG option
                    local bvg_item = genMenuItem(
                        _("Show BVG departures on sleep screen"),
                        "screensaver_type",
                        "bvg_departures"
                    )

                    -- Insert at position 6 (before "Leave screen as-is")
                    table.insert(wallpaper_submenu, 6, bvg_item)

                    logger.dbg("BVGLockscreen: Added BVG option to screensaver menu")
                end

                -- Restore original dofile after patching
                _G.dofile = orig_dofile
                _G._orig_dofile_before_bvg = nil
            end

            return result
        end
    end
end

function BVGLockscreen:patchScreensaver()
    local plugin_instance = self
    local Screensaver = require("ui/screensaver")

    -- Save original show method if not already saved
    if not Screensaver._orig_show_before_bvg then
        Screensaver._orig_show_before_bvg = Screensaver.show
    end

    -- Save original close method if not already saved
    if not Screensaver._orig_close_before_bvg then
        Screensaver._orig_close_before_bvg = Screensaver.close
    end

    Screensaver.show = function(screensaver_instance)
        local ss_type = G_reader_settings:readSetting("screensaver_type")

        if ss_type == "bvg_departures" then
            screensaver_instance.screensaver_type = "bvg_departures"
            logger.dbg("BVGLockscreen: BVG screensaver activated")

            local BVGMenu = require("bvg_menu")
            local station = BVGMenu:getCurrentStation()

            if not station then
                logger.warn("BVGLockscreen: No station configured, falling back to default")
                return Screensaver._orig_show_before_bvg(screensaver_instance)
            end

            -- Close any existing screensaver widget
            if screensaver_instance.screensaver_widget then
                UIManager:close(screensaver_instance.screensaver_widget)
                screensaver_instance.screensaver_widget = nil
            end

            -- Set device to screen saver mode
            Device.screen_saver_mode = true
            plugin_instance.screensaver_active = true

            -- Handle rotation if needed (switch to portrait if in landscape)
            local rotation_mode = Screen:getRotationMode()
            Device.orig_rotation_mode = rotation_mode
            local bit = require("bit")
            if bit.band(Device.orig_rotation_mode, 1) == 1 then
                Screen:setRotationMode(Screen.DEVICE_ROTATED_UPRIGHT)
            else
                Device.orig_rotation_mode = nil
            end

            -- Create and show the departures widget
            local function showDepartures()
                local DisplayDepartures = require("display_departures")
                local widget = DisplayDepartures:createScreensaverWidget()

                if widget then
                    screensaver_instance.screensaver_widget = ScreenSaverWidget:new{
                        widget = widget,
                        background = Blitbuffer.COLOR_WHITE,
                        covers_fullscreen = true,
                    }
                    screensaver_instance.screensaver_widget.modal = true
                    screensaver_instance.screensaver_widget.dithered = true

                    UIManager:show(screensaver_instance.screensaver_widget, "full")
                    logger.dbg("BVGLockscreen: Widget displayed")

                    -- Schedule periodic refresh
                    plugin_instance:scheduleRefresh()
                else
                    logger.warn("BVGLockscreen: Failed to create widget, falling back")
                    plugin_instance.screensaver_active = false
                    return Screensaver._orig_show_before_bvg(screensaver_instance)
                end
            end

            -- Check if online and fetch departures
            if NetworkMgr:isOnline() then
                showDepartures()
            else
                -- Try to go online first
                NetworkMgr:runWhenOnline(function()
                    showDepartures()
                end)
            end
        else
            return Screensaver._orig_show_before_bvg(screensaver_instance)
        end
    end

    Screensaver.close = function(screensaver_instance)
        -- Stop periodic refresh when screensaver closes
        if plugin_instance.screensaver_active then
            plugin_instance.screensaver_active = false
            plugin_instance:unscheduleRefresh()
            logger.dbg("BVGLockscreen: Screensaver closed, refresh stopped")
        end

        return Screensaver._orig_close_before_bvg(screensaver_instance)
    end

    logger.dbg("BVGLockscreen: Screensaver patched successfully")
end

function BVGLockscreen:onCloseDocument()
    -- Nothing special needed on document close
end

return BVGLockscreen
