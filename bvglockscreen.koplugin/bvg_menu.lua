local InputDialog = require("ui/widget/inputdialog")
local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local NetworkMgr = require("ui/network/manager")
local G_reader_settings = require("luasettings"):open(
    ("%s/%s"):format(require("datastorage"):getDataDir(), "settings.reader.lua")
)
local logger = require("logger")
local _ = require("gettext")

local BVGAPI = require("bvg_api")
local BVGUtils = require("bvg_utils")

local BVGMenu = {}

function BVGMenu:getSettings()
    return G_reader_settings:readSetting("bvg_lockscreen") or {}
end

function BVGMenu:saveSetting(key, value)
    local settings = self:getSettings()
    settings[key] = value
    G_reader_settings:saveSetting("bvg_lockscreen", settings)
    G_reader_settings:flush()
end

function BVGMenu:getCurrentStation()
    local settings = self:getSettings()
    return settings.current_station
end

function BVGMenu:setCurrentStation(station)
    self:saveSetting("current_station", station)
end

function BVGMenu:getFavorites()
    local settings = self:getSettings()
    return settings.favorites or {}
end

function BVGMenu:addFavorite(station)
    local favorites = self:getFavorites()
    -- Check if already exists
    for i,fav in ipairs(favorites) do
        if fav.id == station.id then
            return false
        end
    end
    table.insert(favorites, station)
    self:saveSetting("favorites", favorites)
    return true
end

function BVGMenu:removeFavorite(station_id)
    local favorites = self:getFavorites()
    for i, fav in ipairs(favorites) do
        if fav.id == station_id then
            table.remove(favorites, i)
            self:saveSetting("favorites", favorites)
            return true
        end
    end
    return false
end

function BVGMenu:getDepartureCount()
    local settings = self:getSettings()
    return settings.departure_count or 8
end

function BVGMenu:setDepartureCount(count)
    self:saveSetting("departure_count", count)
end

function BVGMenu:getTimeRange()
    local settings = self:getSettings()
    return settings.time_range or 30
end

function BVGMenu:setTimeRange(range)
    self:saveSetting("time_range", range)
end

function BVGMenu:getTransportFilters()
    local settings = self:getSettings()
    return settings.transport_filters or {
        suburban = true,
        subway = true,
        tram = true,
        bus = true,
        ferry = true,
        express = true,
        regional = true,
    }
end

function BVGMenu:setTransportFilter(transport_type, enabled)
    local filters = self:getTransportFilters()
    filters[transport_type] = enabled
    self:saveSetting("transport_filters", filters)
end

function BVGMenu:getFontSize()
    local settings = self:getSettings()
    return settings.font_size or "medium"
end

function BVGMenu:setFontSize(size)
    self:saveSetting("font_size", size)
end

function BVGMenu:showSearchDialog(callback)
    local input_dialog
    input_dialog = InputDialog:new{
        title = _("Search BVG Station"),
        input_hint = _("Enter station name..."),
        input_type = "text",
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = _("Search"),
                    is_enter_default = true,
                    callback = function()
                        local query = input_dialog:getInputText()
                        UIManager:close(input_dialog)
                        if query and query ~= "" then
                            self:performSearch(query, callback)
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function BVGMenu:performSearch(query, callback)
    NetworkMgr:runWhenOnline(function()
        if not BVGUtils:canMakeRequest() then
            BVGUtils:showRateLimitMessage()
            return
        end

        UIManager:show(InfoMessage:new{
            text = _("Searching..."),
            timeout = 1,
        })

        local stations, err = BVGAPI:searchStations(query)

        if not stations then
            local error_msg = _("Search failed")
            if err == "rate_limited" then
                error_msg = _("Please wait before searching again")
            end
            UIManager:show(InfoMessage:new{
                text = error_msg,
                timeout = 2,
            })
            return
        end

        if #stations == 0 then
            UIManager:show(InfoMessage:new{
                text = _("No stations found"),
                timeout = 2,
            })
            return
        end

        self:showStationSelection(stations, callback)
    end)
end

function BVGMenu:showStationSelection(stations, callback)
    local buttons = {}

    for i,station in ipairs(stations) do
        table.insert(buttons, {
            {
                text = station.name,
                callback = function()
                    UIManager:close(self.station_dialog)
                    if callback then
                        callback(station)
                    else
                        self:setCurrentStation(station)
                        UIManager:show(InfoMessage:new{
                            text = _("Station set to:") .. " " .. station.name,
                            timeout = 2,
                        })
                    end
                end,
            },
        })
    end

    table.insert(buttons, {
        {
            text = _("Cancel"),
            callback = function()
                UIManager:close(self.station_dialog)
            end,
        },
    })

    self.station_dialog = ButtonDialog:new{
        title = _("Select Station"),
        buttons = buttons,
    }
    UIManager:show(self.station_dialog)
end

function BVGMenu:showFavoritesMenu()
    local favorites = self:getFavorites()

    if #favorites == 0 then
        UIManager:show(InfoMessage:new{
            text = _("No favorite stations saved"),
            timeout = 2,
        })
        return
    end

    local buttons = {}

    for i,station in ipairs(favorites) do
        table.insert(buttons, {
            {
                text = station.name,
                callback = function()
                    UIManager:close(self.favorites_dialog)
                    self:setCurrentStation(station)
                    UIManager:show(InfoMessage:new{
                        text = _("Station set to:") .. " " .. station.name,
                        timeout = 2,
                    })
                end,
            },
            {
                text = "✕",
                callback = function()
                    self:removeFavorite(station.id)
                    UIManager:close(self.favorites_dialog)
                    self:showFavoritesMenu()
                end,
            },
        })
    end

    table.insert(buttons, {
        {
            text = _("Cancel"),
            callback = function()
                UIManager:close(self.favorites_dialog)
            end,
        },
    })

    self.favorites_dialog = ButtonDialog:new{
        title = _("Favorite Stations"),
        buttons = buttons,
    }
    UIManager:show(self.favorites_dialog)
end

function BVGMenu:showAddFavoriteDialog()
    self:showSearchDialog(function(station)
        if self:addFavorite(station) then
            UIManager:show(InfoMessage:new{
                text = _("Added to favorites:") .. " " .. station.name,
                timeout = 2,
            })
        else
            UIManager:show(InfoMessage:new{
                text = _("Station already in favorites"),
                timeout = 2,
            })
        end
    end)
end

function BVGMenu:showDepartureCountMenu()
    local counts = {4, 6, 8, 10, 12}
    local buttons = {}
    local current = self:getDepartureCount()

    for i,count in ipairs(counts) do
        local text = tostring(count)
        if count == current then
            text = text .. " ✓"
        end
        table.insert(buttons, {
            {
                text = text,
                callback = function()
                    UIManager:close(self.count_dialog)
                    self:setDepartureCount(count)
                end,
            },
        })
    end

    table.insert(buttons, {
        {
            text = _("Cancel"),
            callback = function()
                UIManager:close(self.count_dialog)
            end,
        },
    })

    self.count_dialog = ButtonDialog:new{
        title = _("Number of Departures"),
        buttons = buttons,
    }
    UIManager:show(self.count_dialog)
end

function BVGMenu:showTimeRangeMenu()
    local ranges = {15, 30, 45, 60, 90, 120}
    local buttons = {}
    local current = self:getTimeRange()

    for i,range in ipairs(ranges) do
        local text = tostring(range) .. " " .. _("min")
        if range == current then
            text = text .. " ✓"
        end
        table.insert(buttons, {
            {
                text = text,
                callback = function()
                    UIManager:close(self.range_dialog)
                    self:setTimeRange(range)
                end,
            },
        })
    end

    table.insert(buttons, {
        {
            text = _("Cancel"),
            callback = function()
                UIManager:close(self.range_dialog)
            end,
        },
    })

    self.range_dialog = ButtonDialog:new{
        title = _("Time Range"),
        buttons = buttons,
    }
    UIManager:show(self.range_dialog)
end

function BVGMenu:showFontSizeMenu()
    local sizes = {
        {key = "small", name = _("Small")},
        {key = "medium", name = _("Medium")},
        {key = "large", name = _("Large")},
    }
    local buttons = {}
    local current = self:getFontSize()

    for i,size in ipairs(sizes) do
        local text = size.name
        if size.key == current then
            text = text .. " ✓"
        end
        table.insert(buttons, {
            {
                text = text,
                callback = function()
                    UIManager:close(self.font_dialog)
                    self:setFontSize(size.key)
                end,
            },
        })
    end

    table.insert(buttons, {
        {
            text = _("Cancel"),
            callback = function()
                UIManager:close(self.font_dialog)
            end,
        },
    })

    self.font_dialog = ButtonDialog:new{
        title = _("Font Size"),
        buttons = buttons,
    }
    UIManager:show(self.font_dialog)
end

function BVGMenu:showTransportFilterMenu()
    local filters = self:getTransportFilters()
    local transport_types = {
        {key = "subway", name = _("U-Bahn")},
        {key = "suburban", name = _("S-Bahn")},
        {key = "tram", name = _("Tram")},
        {key = "bus", name = _("Bus")},
        {key = "ferry", name = _("Ferry")},
        {key = "regional", name = _("Regional")},
        {key = "express", name = _("Express")},
    }

    local buttons = {}

    for i,transport in ipairs(transport_types) do
        local text = transport.name
        if filters[transport.key] then
            text = text .. " ✓"
        end
        table.insert(buttons, {
            {
                text = text,
                callback = function()
                    self:setTransportFilter(transport.key, not filters[transport.key])
                    UIManager:close(self.filter_dialog)
                    self:showTransportFilterMenu()
                end,
            },
        })
    end

    table.insert(buttons, {
        {
            text = _("Done"),
            callback = function()
                UIManager:close(self.filter_dialog)
            end,
        },
    })

    self.filter_dialog = ButtonDialog:new{
        title = _("Transport Types"),
        buttons = buttons,
    }
    UIManager:show(self.filter_dialog)
end

function BVGMenu:getMenuTable()
    return {
        text = _("BVG Lock Screen"),
        sub_item_table = {
            {
                text = _("Search station"),
                keep_menu_open = true,
                callback = function()
                    self:showSearchDialog()
                end,
            },
            {
                text_func = function()
                    local station = self:getCurrentStation()
                    if station then
                        return _("Current station:") .. " " .. station.name
                    else
                        return _("No station selected")
                    end
                end,
                enabled_func = function()
                    return self:getCurrentStation() ~= nil
                end,
                keep_menu_open = true,
                callback = function() end,
            },
            {
                text = _("Favorite stations"),
                keep_menu_open = true,
                callback = function()
                    self:showFavoritesMenu()
                end,
            },
            {
                text = _("Add to favorites"),
                keep_menu_open = true,
                callback = function()
                    self:showAddFavoriteDialog()
                end,
            },
            {
                text = "---",
            },
            {
                text_func = function()
                    return _("Departures shown:") .. " " .. self:getDepartureCount()
                end,
                keep_menu_open = true,
                callback = function()
                    self:showDepartureCountMenu()
                end,
            },
            {
                text_func = function()
                    return _("Time range:") .. " " .. self:getTimeRange() .. " " .. _("min")
                end,
                keep_menu_open = true,
                callback = function()
                    self:showTimeRangeMenu()
                end,
            },
            {
                text = _("Transport types"),
                keep_menu_open = true,
                callback = function()
                    self:showTransportFilterMenu()
                end,
            },
            {
                text_func = function()
                    local size_names = {small = _("Small"), medium = _("Medium"), large = _("Large")}
                    return _("Font size:") .. " " .. (size_names[self:getFontSize()] or _("Medium"))
                end,
                keep_menu_open = true,
                callback = function()
                    self:showFontSizeMenu()
                end,
            },
            {
                text = "---",
            },
            {
                text = _("Preview departures"),
                keep_menu_open = true,
                callback = function()
                    local station = self:getCurrentStation()
                    if not station then
                        UIManager:show(InfoMessage:new{
                            text = _("Please select a station first"),
                            timeout = 2,
                        })
                        return
                    end

                    local DisplayDepartures = require("display_departures")
                    DisplayDepartures:showDepartures()
                end,
            },
        },
    }
end

return BVGMenu
