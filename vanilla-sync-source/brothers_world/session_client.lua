local function restoreOwnVisibility()
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return end
    NetworkSetEntityInvisibleToNetwork(ped, false)
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    NetworkSetInSpectatorMode(false, ped)
end
local function report()
    if not NetworkIsSessionStarted() or not NetworkIsPlayerActive(PlayerId()) then return end
    local seen = {}
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if NetworkIsPlayerActive(player) and ped ~= 0 and DoesEntityExist(ped) then
            seen[#seen + 1] = GetPlayerServerId(player)
        end
    end
    TriggerServerEvent('brothers_session:report', seen, IsEntityVisible(PlayerPedId()))
end
AddEventHandler('playerSpawned', function() restoreOwnVisibility();report() end)
RegisterNetEvent('brothers_session:repair', function()
    if source ~= 65535 then return end
    restoreOwnVisibility()
    report()
end)
CreateThread(function()
    while true do Wait(5000);report() end
end)
