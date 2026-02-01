local http = require("socket.http")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("json")
local logger = require("logger")
local BVGUtils = require("bvg_utils")
local _ = require("gettext")

local BVGAPI = {
    base_url = "https://v6.bvg.transport.rest",
}

function BVGAPI:makeRequest(endpoint, force)
    if not force and not BVGUtils:canMakeRequest() then
        return nil, "rate_limited"
    end

    local url = self.base_url .. endpoint
    local response_body = {}

    logger.dbg("BVG API request:", url)

    local result, code, headers, status = https.request{
        url = url,
        method = "GET",
        headers = {
            ["Accept"] = "application/json",
            ["User-Agent"] = "KOReader-BVG-Plugin/1.0",
        },
        sink = ltn12.sink.table(response_body),
    }

    BVGUtils:recordRequest()

    if not result or code ~= 200 then
        logger.err("BVG API error:", code, status)
        return nil, "request_failed"
    end

    local body = table.concat(response_body)
    local success, data = pcall(json.decode, body)

    if not success then
        logger.err("BVG API JSON parse error")
        return nil, "parse_error"
    end

    return data
end

function BVGAPI:searchStations(query)
    if not query or query == "" then
        return nil, "empty_query"
    end

    -- URL encode the query
    local encoded_query = query:gsub("([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)

    local endpoint = "/locations?query=" .. encoded_query .. "&results=10&stops=true&addresses=false&poi=false"
    local data, err = self:makeRequest(endpoint)

    if not data then
        return nil, err
    end

    local stations = {}
    for i,location in ipairs(data) do
        if location.type == "stop" or location.type == "station" then
            table.insert(stations, {
                id = location.id,
                name = location.name,
                type = location.type,
            })
        end
    end

    return stations
end

function BVGAPI:getDepartures(station_id, options)
    if not station_id then
        return nil, "no_station"
    end

    options = options or {}
    local duration = options.duration or 30
    local results = options.results or 8

    local endpoint = "/stops/" .. station_id .. "/departures?duration=" .. duration .. "&results=" .. results

    -- Add transport type filters if specified
    if options.suburban ~= nil then
        endpoint = endpoint .. "&suburban=" .. tostring(options.suburban)
    end
    if options.subway ~= nil then
        endpoint = endpoint .. "&subway=" .. tostring(options.subway)
    end
    if options.tram ~= nil then
        endpoint = endpoint .. "&tram=" .. tostring(options.tram)
    end
    if options.bus ~= nil then
        endpoint = endpoint .. "&bus=" .. tostring(options.bus)
    end
    if options.ferry ~= nil then
        endpoint = endpoint .. "&ferry=" .. tostring(options.ferry)
    end
    if options.express ~= nil then
        endpoint = endpoint .. "&express=" .. tostring(options.express)
    end
    if options.regional ~= nil then
        endpoint = endpoint .. "&regional=" .. tostring(options.regional)
    end

    local data, err = self:makeRequest(endpoint, options.force)

    if not data then
        return nil, err
    end

    local departures = {}
    for i,dep in ipairs(data.departures or data) do
        local line_name = ""
        local product = ""

        if dep.line then
            line_name = dep.line.name or dep.line.id or ""
            product = dep.line.product or ""
        end

        local direction = dep.direction or ""
        local planned = dep.plannedWhen or dep.when
        local actual = dep.when or dep.plannedWhen
        local platform = dep.platform or dep.plannedPlatform
        local cancelled = dep.cancelled or false

        local minutes = BVGUtils:formatMinutesUntil(actual)
        local delay = 0
        if dep.delay and type(dep.delay) == "number" then
            delay = math.floor(dep.delay / 60)
        end

        if minutes and minutes >= 0 then
            table.insert(departures, {
                line = line_name,
                product = product,
                direction = direction,
                minutes = minutes,
                delay = delay,
                platform = platform,
                cancelled = cancelled,
                planned_time = planned,
                actual_time = actual,
            })
        end
    end

    -- Sort by minutes until departure
    table.sort(departures, function(a, b)
        return (a.minutes or 999) < (b.minutes or 999)
    end)

    return departures
end

return BVGAPI
