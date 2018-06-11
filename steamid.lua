local ffi = require 'ffi'
local ACCOUNT_TYPE_INDIVIDUAL = 0x0110000100000000ULL

function GenerateSteamID64(id_type, account_number)
    return (account_number * 2ULL) + ACCOUNT_TYPE_INDIVIDUAL + id_type
end
