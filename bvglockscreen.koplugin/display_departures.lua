local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local RightContainer = require("ui/widget/container/rightcontainer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local UIManager = require("ui/uimanager")
local Device = require("device")
local Screen = Device.screen
local InfoMessage = require("ui/widget/infomessage")
local NetworkMgr = require("ui/network/manager")
local logger = require("logger")
local _ = require("gettext")

local BVGAPI = require("bvg_api")
local BVGMenu = require("bvg_menu")
local BVGUtils = require("bvg_utils")

local DisplayDepartures = InputContainer:extend{
    width = nil,
    height = nil,
    departures = nil,
    station_name = nil,
}

function DisplayDepartures:init()
    self.width = self.width or Screen:getWidth()
    self.height = self.height or Screen:getHeight()

    -- Calculate responsive sizes
    local screen_size = math.min(self.width, self.height)
    self.padding = math.floor(screen_size * 0.03)
    self.line_height = math.floor(screen_size * 0.06)

    -- Font size multiplier based on user setting
    local font_size_setting = BVGMenu:getFontSize()
    local font_multiplier = 1.0
    if font_size_setting == "small" then
        font_multiplier = 0.8
    elseif font_size_setting == "large" then
        font_multiplier = 1.25
    end

    -- Font sizes based on screen size and user preference
    self.header_font_size = math.floor(screen_size * 0.04 * font_multiplier)
    self.departure_font_size = math.floor(screen_size * 0.035 * font_multiplier)

    -- Column widths
    local content_width = self.width - (self.padding * 2)
    self.line_col_width = math.floor(content_width * 0.15)
    self.direction_col_width = math.floor(content_width * 0.55)
    self.time_col_width = math.floor(content_width * 0.25)

    self:buildUI()

    if self.departures then
        self.ges_events = {
            Tap = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{
                        x = 0, y = 0,
                        w = self.width,
                        h = self.height,
                    },
                },
            },
        }
    end
end

function DisplayDepartures:buildUI()
    local content_width = self.width - (self.padding * 2)
    -- Use title font (bold) for station header
    local face_header = Font:getFace("tfont", self.header_font_size)
    -- Use monospace font for entire table (consistent alignment)
    local face_mono = Font:getFace("infont", self.departure_font_size)

    local rows = VerticalGroup:new{ align = "left" }

    -- Header: Station name and current time (right-aligned)
    local station_widget = TextWidget:new{
        text = self.station_name or _("No Station"),
        face = face_header,
        bold = true,
        max_width = content_width * 0.7,
    }
    local time_widget = TextWidget:new{
        text = BVGUtils:getCurrentTimeString(),
        face = face_header,
    }
    local station_width = station_widget:getSize().w
    local time_width = time_widget:getSize().w
    local spacer_width = content_width - station_width - time_width

    local header = HorizontalGroup:new{
        station_widget,
        HorizontalSpan:new{ width = spacer_width },
        time_widget,
    }
    table.insert(rows, header)
    table.insert(rows, VerticalSpan:new{ height = self.line_height * 0.5 })

    -- Separator line
    table.insert(rows, LineWidget:new{
        dimen = Geom:new{ w = content_width, h = 2 },
        background = Blitbuffer.COLOR_BLACK,
    })
    table.insert(rows, VerticalSpan:new{ height = self.line_height * 0.3 })

    -- Departure rows
    if self.departures and #self.departures > 0 then
        -- Calculate max line name width for right-alignment
        local max_line_chars = 0
        for i,dep in ipairs(self.departures) do
            local len = BVGUtils:utf8len(dep.line or "")
            if len > max_line_chars then
                max_line_chars = len
            end
        end

        -- Calculate total chars that fit in content width
        local char_width = TextWidget:new{ text = "M", face = face_mono }:getSize().w
        local total_chars = math.floor(content_width / char_width)

        for i,dep in ipairs(self.departures) do
            local row = self:buildDepartureRow(dep, face_mono, max_line_chars, total_chars)
            table.insert(rows, row)
            table.insert(rows, VerticalSpan:new{ height = self.line_height * 0.2 })
        end
    else
        table.insert(rows, VerticalSpan:new{ height = self.line_height })
        table.insert(rows, CenterContainer:new{
            dimen = Geom:new{ w = content_width, h = self.line_height },
            TextWidget:new{
                text = _("No departures available"),
                face = face_mono,
            },
        })
    end

    -- Build main content
    local content = VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ height = self.padding },
        HorizontalGroup:new{
            HorizontalSpan:new{ width = self.padding },
            rows,
        },
    }

    -- Battery indicator at bottom right
    local battery_percent = Device:getPowerDevice():getCapacity()
    local battery_text = battery_percent .. "%"
    local face_battery = Font:getFace("infont", self.departure_font_size)
    local battery_widget = TextWidget:new{
        text = battery_text,
        face = face_battery,
    }

    local battery_container = BottomContainer:new{
        dimen = Geom:new{ w = self.width, h = self.height },
        RightContainer:new{
            dimen = Geom:new{ w = self.width - self.padding, h = battery_widget:getSize().h + self.padding },
            battery_widget,
        },
    }

    -- Overlay battery on top of content
    self[1] = OverlapGroup:new{
        dimen = Geom:new{ w = self.width, h = self.height },
        FrameContainer:new{
            width = self.width,
            height = self.height,
            background = Blitbuffer.COLOR_WHITE,
            bordersize = 0,
            padding = 0,
            margin = 0,
            content,
        },
        battery_container,
    }
end

function DisplayDepartures:buildDepartureRow(departure, face_mono, line_chars, total_chars)
    local time_chars = 8

    local line_text = departure.line or ""
    local direction_text = departure.direction or ""
    local time_text = BVGUtils:formatDepartureTime(departure.minutes, departure.delay)

    -- Add cancelled indicator
    if departure.cancelled then
        time_text = "✕"
        direction_text = direction_text .. " " .. _("(cancelled)")
    end

    -- Pad line to dynamic width (right-aligned)
    line_text = BVGUtils:padLeft(line_text, line_chars)

    -- Pad time to fixed width (right-aligned)
    time_text = BVGUtils:padLeft(time_text, time_chars)

    -- Calculate remaining chars for direction
    local direction_chars = total_chars - line_chars - time_chars - 2  -- 2 for spacing

    -- Truncate and pad direction (left-aligned, fills middle)
    direction_text = BVGUtils:truncateString(direction_text, direction_chars)
    direction_text = BVGUtils:padRight(direction_text, direction_chars)

    -- Build full row as single text for perfect alignment
    local row_text = line_text .. " " .. direction_text .. " " .. time_text

    local row = TextWidget:new{
        text = row_text,
        face = face_mono,
    }

    return row
end

function DisplayDepartures:onTap()
    UIManager:close(self)
    return true
end

function DisplayDepartures:onShow()
    UIManager:setDirty(self, "full")
end

function DisplayDepartures:onCloseWidget()
    UIManager:setDirty(nil, "full")
end

-- Static function to fetch and display departures
function DisplayDepartures:showDepartures(callback)
    local station = BVGMenu:getCurrentStation()
    if not station then
        UIManager:show(InfoMessage:new{
            text = _("No station selected"),
            timeout = 2,
        })
        return
    end

    NetworkMgr:runWhenOnline(function()
        if not BVGUtils:canMakeRequest() then
            BVGUtils:showRateLimitMessage()
            return
        end

        local options = {
            duration = BVGMenu:getTimeRange(),
            results = BVGMenu:getDepartureCount(),
        }

        -- Apply transport filters
        local filters = BVGMenu:getTransportFilters()
        for key, value in pairs(filters) do
            options[key] = value
        end

        local departures, err = BVGAPI:getDepartures(station.id, options)

        if not departures then
            local error_msg = _("Failed to fetch departures")
            if err == "rate_limited" then
                error_msg = _("Please wait before refreshing")
            end
            UIManager:show(InfoMessage:new{
                text = error_msg,
                timeout = 2,
            })
            return
        end

        local widget = DisplayDepartures:new{
            departures = departures,
            station_name = station.name,
        }

        if callback then
            callback(widget)
        else
            UIManager:show(widget)
        end
    end)
end

-- Create a widget for screensaver use
function DisplayDepartures:createScreensaverWidget()
    local station = BVGMenu:getCurrentStation()
    if not station then
        return nil
    end

    -- For screensaver, force refresh (bypass rate limiting)
    local options = {
        duration = BVGMenu:getTimeRange(),
        results = BVGMenu:getDepartureCount(),
        force = true,
    }

    local filters = BVGMenu:getTransportFilters()
    for key, value in pairs(filters) do
        options[key] = value
    end

    local departures, err, changed = BVGAPI:getDepartures(station.id, options)

    local widget = DisplayDepartures:new{
        departures = departures or {},
        station_name = station.name,
    }

    return widget, changed
end

return DisplayDepartures
