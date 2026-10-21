-- A dedicated local two-player world. OneSync performs entity replication;
-- these helpers only keep its routing bucket shared and expose diagnostics.
local reports, warned = {}, {}
local BUCKET = 0
local function ids()
    local result = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id and id > 0 then result[#result + 1] = id end
    end
    table.sort(result)
    return result
end
local function syncOn()
    local mode = GetConvar('onesync', 'off'):lower()
    return mode == 'on' or mode == 'legacy' or mode == 'true' or mode == '1'
end
local function shared(id)
    if type(id) ~= 'number' or id < 1 or not syncOn() or not GetPlayerName(tostring(id)) then return false end
    local previous = GetPlayerRoutingBucket(id)
    if previous ~= BUCKET then
        SetPlayerRoutingBucket(id, BUCKET)
        local now = GetGameTimer()
        if not warned[id] or now - warned[id] >= 15000 then
            print(('[brothers_sync] player=%d moved from bucket=%d to shared bucket=0. Disable conflicting instance/spawn resources.'):format(id, previous))
            warned[id] = now
        end
    end
    return true
end
AddEventHandler('brothers_world:hello', function() shared(tonumber(source)) end)
AddEventHandler('playerJoining', function() shared(tonumber(source)) end)
AddEventHandler('playerDropped', function() reports[tonumber(source)], warned[tonumber(source)] = nil, nil end)
RegisterNetEvent('brothers_session:report', function(seen, visible)
    local id = tonumber(source)
    if not id or not GetPlayerName(tostring(id)) or type(seen) ~= 'table' or #seen > BrothersConfig.maxPlayers or type(visible) ~= 'boolean' then return end
    local now = GetGameTimer()
    if reports[id] and now - reports[id].at < 1000 then return end
    local clean, used = {}, {}
    for _, peer in ipairs(seen) do
        if type(peer) ~= 'number' or peer % 1 ~= 0 or not GetPlayerName(tostring(peer)) then return end
        if not used[peer] then clean[#clean + 1], used[peer] = peer, true end
    end
    table.sort(clean)
    reports[id] = {seen = clean, visible = visible, at = now}
end)
RegisterCommand('brothers_sync', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'brothers.manage') then return end
    if #args > 1 or (args[1] and args[1] ~= 'fix') then print('[brothers_sync] Usage: brothers_sync [fix]');return end
    local list = ids()
    print(('[brothers_sync] OneSync=%s players=%d (expected 2). Same server + same bucket + nearby peds are required.'):format(GetConvar('onesync', 'off'), #list))
    if not syncOn() then
        print('[brothers_sync] ERROR: set onesync on in the startup config/txAdmin and FULLY restart the server and both clients. Resource restart cannot enable OneSync.')
        return
    end
    for _, id in ipairs(list) do
        if args[1] == 'fix' then
            shared(id)
            TriggerClientEvent('brothers_session:repair', id)
            TriggerClientEvent('brothers_world:hubApproved', id)
        end
        local ped = GetPlayerPed(id)
        local position = 'ped=missing'
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            local p = GetEntityCoords(ped)
            position = ('ped=present xyz=%.1f,%.1f,%.1f'):format(p.x, p.y, p.z)
        end
        local r = reports[id]
        local seen = r and GetGameTimer() - r.at <= 15000 and ('clientSees=[' .. table.concat(r.seen, ',') .. '] selfVisible=' .. tostring(r.visible)) or 'clientReport=missing/stale'
        print(('[brothers_sync] id=%d bucket=%d %s %s'):format(id, GetPlayerRoutingBucket(id), position, seen))
    end
    if args[1] == 'fix' then print('[brothers_sync] Shared bucket + own visibility restored; hub respawn requested. In 5 seconds run brothers_sync again.') end
end, false)
CreateThread(function()
    while true do
        if syncOn() then
            for _, id in ipairs(ids()) do shared(id) end
        else
            print('[brothers_sync] ERROR: OneSync is OFF. Enable it and fully restart. Brothers config v1.1 requires OneSync.')
        end
        Wait(syncOn() and 3000 or 30000)
    end
end)
