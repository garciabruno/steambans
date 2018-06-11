require("sol")
require("tracker")
require("bench")

local ffi = require 'ffi'
local json = require('json')
local sql = require('sqlite3')
os.remove('scanner.db')
local db = sql.open('scanner.db')

local NUMBER_OF_IDS = 150000000

local BAN_TYPES = {
    VAC = 1,
    GameBan = 2
}

local bm = Bench()
bm:Begin()
tracker = BanTracker()

db:exec[[
    PRAGMA synchronous = OFF;
    PRAGMA journal_mode = OFF;
    PRAGMA locking_mode = EXCLUSIVE;
    PRAGMA foreign_keys = ON;

    CREATE TABLE IF NOT EXISTS bans (
        id INTEGER PRIMARY KEY,
        date DATETIME,
        ban_type INTEGER,
        number_of_bans INTEGER
    );

    CREATE TABLE IF NOT EXISTS failedbatches (
        batch_number INTEGER PRIMARY KEY,
        succeded BOOLEAN DEFAULT 0,
        date DATETIME DEFAULT current_timestamp
    );
]]

local record_exists = db:prepare("SELECT EXISTS(SELECT 1 FROM BANS WHERE date=date('now', ?) AND ban_type=?);")
local create_ban_record = db:prepare("INSERT INTO bans(date, ban_type, number_of_bans) VALUES(date('now', ?), ?, 1)")
local update_ban_record = db:prepare("UPDATE bans SET number_of_bans=number_of_bans + 1 WHERE date=date('now', ?) AND ban_type=?")
local create_failedbatch_record = db:prepare("INSERT INTO failedbatches(batch_number) VALUES(?)")

function RegisterBan(days, ban_type)
    local query_record_exists = record_exists:reset():bind('-%d days' % days, ban_type):step()
    local record_exists = query_record_exists[1] == 1

    if not record_exists then
        create_ban_record:reset():bind('-%d days' % days, ban_type):step()
    else
        update_ban_record:reset():bind('-%d days' % days, ban_type):step()
    end
end

function CreateFailedBatch(batch_number)
    create_failedbatch_record:reset():bind(batch_number):step()
end

function ProcessPlayersData(data)
    for index,player in pairs(data) do
        if player.VACBanned then
            RegisterBan(player.DaysSinceLastBan, BAN_TYPES.VAC)
        end

        if player.NumberOfGameBans > 0 then
            RegisterBan(player.DaysSinceLastBan, BAN_TYPES.GameBan)
        end
    end
end

function CreateSteamIds(batch_number)
    local ids = {}
    local id_type = batch_number % 2 == 0 and 1 or 0

    for b = batch_number * 100, batch_number * 100 + 99 do
        local account_number = ffi.cast('uint64_t', b)
        local id = GenerateSteamID64(ffi.cast('uint64_t', id_type), account_number)

        table.insert(ids, tostring(id):sub(1, -4))
    end

    return ids
end

function StartScan(start_batch_number)
    local i = start_batch_number
    local max_iterations = NUMBER_OF_IDS / 100
    local number_of_batches = 100

    repeat
        function ProcessRequest(url, data, headers)
            if headers:match("HTTP/1%.1 (%d+)") ~= "200" then
                CreateFailedBatch(i)
            else
                decoded_data = json.decode(data)
                ProcessPlayersData(decoded_data.players)
            end
        end

        local ids = CreateSteamIds(i)
        steamids = table.concat(ids, ',')
        tracker:ScanID(steamids, ProcessRequest)

        i = i + 1

        if i % number_of_batches == 0 then
            std.wait()

            print('==== (%d/%d) ====' % {i, max_iterations})
        end

    until i == max_iterations
end

StartScan(1)
std.wait()
bm:End()
