require("sol")
require("steamid")

local ffi = require "ffi"
local API_KEY = ''

BanTracker = {}

BanTracker.NUMBER_OF_IDS = NUMBER_OF_IDS
BanTracker.__index = BanTracker
BanTracker.SteamAPIBase = 'https://api.steampowered.com/'
BanTracker.GetPlayersBansURL = BanTracker.SteamAPIBase .. 'ISteamUser/GetPlayerBans/v1?key=%s&steamids=%s'
BanTracker.ProfileURL = 'https://steamcommunity.com/profiles/%s'

setmetatable(BanTracker, BanTracker)

function BanTracker:__call()
    local obj = setmetatable({}, BanTracker)
    return obj
end

function BanTracker:ScanID(steamids, callback)
    dew.getURL(BanTracker.GetPlayersBansURL % {API_KEY, steamids}, callback)
end
