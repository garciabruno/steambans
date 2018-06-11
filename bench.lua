local ffi = require 'ffi'

ffi.cdef[[
    int QueryUnbiasedInterruptTime(uint64_t* time);

    struct timespec {
        int64_t  tv_sec;        /* seconds */
        long     tv_nsec;       /* nanoseconds */
    };
    int clock_gettime(int clk_id, struct timespec *tp);
]]

Bench = {}
Bench.__index = Bench

setmetatable(Bench, Bench)

if ffi.os == "Windows" then -- Windows
    function Bench:__call()
        local obj = setmetatable({}, Bench)
        obj.startTime = ffi.new('uint64_t[1]')
        obj.endTime   = ffi.new('uint64_t[1]')
        return obj
    end

    function Bench:Begin()
        ffi.C.QueryUnbiasedInterruptTime(self.startTime)
    end

    function Bench:End()
        ffi.C.QueryUnbiasedInterruptTime(self.endTime)
        local runTime = tonumber(self.endTime[0]-self.startTime[0])/10000
        print(string.format('finished in %.4fms',runTime))
    end
else -- Linux
    function Bench:__call()
        local obj = setmetatable({}, Bench)
        obj.startTime = ffi.new('struct timespec[1]')
        obj.endTime   = ffi.new('struct timespec[1]')
        return obj
    end

    function Bench:Begin()
        ffi.C.clock_gettime(4--[[CLOCK_MONOTONIC_RAW]], self.startTime)
    end

    function Bench:End()
        ffi.C.clock_gettime(4--[[CLOCK_MONOTONIC_RAW]], self.endTime)
        self.endTime[0].tv_sec  = self.endTime[0].tv_sec - self.startTime[0].tv_sec
        self.endTime[0].tv_nsec = self.endTime[0].tv_nsec - self.startTime[0].tv_nsec
        local runTime = (tonumber(self.endTime[0].tv_nsec) / 1e6) + (tonumber(self.endTime[0].tv_sec) * 1000)
        print(string.format('finished in %.4fms',runTime))
    end
end