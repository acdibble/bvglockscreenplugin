local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")

local BVGUtils = {
    last_request_time = 0,
    rate_limit_seconds = 15,
}

function BVGUtils:canMakeRequest()
    local current_time = os.time()
    return (current_time - self.last_request_time) >= self.rate_limit_seconds
end

function BVGUtils:recordRequest()
    self.last_request_time = os.time()
end

function BVGUtils:getWaitTime()
    local current_time = os.time()
    local elapsed = current_time - self.last_request_time
    return self.rate_limit_seconds - elapsed
end

function BVGUtils:showRateLimitMessage()
    local wait_time = self:getWaitTime()
    UIManager:show(InfoMessage:new{
        text = _("Please wait") .. " " .. wait_time .. " " .. _("seconds before refreshing."),
        timeout = 2,
    })
end

function BVGUtils:formatMinutesUntil(iso_time)
    if not iso_time then return nil end

    -- Parse ISO 8601 time format: 2024-01-15T14:32:00+01:00
    local year, month, day, hour, min, sec = iso_time:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not year then return nil end

    local departure_time = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec),
    })

    local now = os.time()
    local diff_seconds = departure_time - now
    local diff_minutes = math.floor(diff_seconds / 60)

    return diff_minutes
end

function BVGUtils:formatDelay(planned_time, actual_time)
    if not planned_time or not actual_time then return 0 end

    local planned_min = self:formatMinutesUntil(planned_time)
    local actual_min = self:formatMinutesUntil(actual_time)

    if planned_min and actual_min then
        return actual_min - planned_min
    end
    return 0
end

function BVGUtils:formatDepartureTime(minutes, delay)
    if minutes == nil then
        return "???"
    end

    if minutes <= 0 then
        return _("now")
    end

    local time_str = tostring(minutes)

    if delay and delay > 0 then
        time_str = time_str .. " +" .. delay
    elseif delay and delay < 0 then
        time_str = time_str .. " " .. delay
    else
        time_str = time_str .. " min"
    end

    return time_str
end

function BVGUtils:getCurrentTimeString()
    return os.date("%H:%M")
end

-- Count UTF-8 characters (not bytes)
function BVGUtils:utf8len(str)
    if not str then return 0 end
    local len = 0
    for _ in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        len = len + 1
    end
    return len
end

-- Truncate string to max UTF-8 characters
function BVGUtils:truncateString(str, max_len)
    if not str then return "" end
    local len = self:utf8len(str)
    if len <= max_len then return str end

    -- Build truncated string character by character
    local result = ""
    local count = 0
    for char in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if count >= max_len - 1 then break end
        result = result .. char
        count = count + 1
    end
    return result .. "…"
end

function BVGUtils:padLeft(str, width)
    str = str or ""
    local len = self:utf8len(str)
    if len >= width then return str end
    return string.rep(" ", width - len) .. str
end

function BVGUtils:padRight(str, width)
    str = str or ""
    local len = self:utf8len(str)
    if len >= width then return str end
    return str .. string.rep(" ", width - len)
end

return BVGUtils
