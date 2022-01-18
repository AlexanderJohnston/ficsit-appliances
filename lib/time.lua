local time = {}

function time.real_millis_since_boot()
    return computer.millis()
end

function time.real_seconds_since_boot()
    return time.real_millis_since_boot() / 1000
end

-- https://docs.ficsit.app/ficsit-networks/latest/lua/api/Computer.html says
--    A game day consists of 24 game hours, a game hour consists of 60 game minutes, a game minute consists of 60 game seconds.
-- https://satisfactory.fandom.com/wiki/World says
--    One day on Massage-2(A-B)b lasts for 50 real-world minutes
local REAL_TO_GAME = 60 * 24 / 50

function time.game_to_real(duration)
    return duration / REAL_TO_GAME
end

function time.real_to_game(duration)
    return duration * REAL_TO_GAME
end

function time.game_seconds_save_age()
    --- The number of in-game seconds that have elapsed since the creation of this world
    return computer.time()
end

function time.real_seconds_save_age()
    --- The number of real-world seconds that have elapsed since the creation of this world
    return time.game_to_real(time.game_seconds_save_age())
end

function time.timestamp()
    --- Best monothonic, second-resolution timestamp we have
    -- ideally this would be time.real_seconds_save_age(),
    -- but that's borked currently due to https://github.com/Panakotta00/FicsIt-Networks/issues/200
    return time.real_seconds_since_boot()
end

return time
