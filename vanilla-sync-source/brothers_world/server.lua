local slots, cooldowns, regroupAt, positionAt = {}, {}, {}, {}
local weather, hour = BrothersConfig.weather, BrothersConfig.hour
local allowedWeather = {CLEAR=true, EXTRASUNNY=true, CLOUDS=true, OVERCAST=true, RAIN=true,
    THUNDER=true, CLEARING=true, FOGGY=true, SMOG=true, XMAS=true, SNOWLIGHT=true}
local function online(id)
    return type(id)=='number' and id>0 and GetPlayerName(tostring(id))~=nil
end
local function notice(id, message) TriggerClientEvent('brothers_world:notice', id, message) end
local function modeSettings()
    local selected = GetConvarInt('brothers_experimental', 0)==1 and BrothersConfig.experimental or BrothersConfig.main
    local health = math.max(200, math.min(600, GetConvarInt('brothers_health', selected.health)))
    return {health=health, armour=selected.armour, peds=selected.peds, traffic=selected.traffic,
        parked=selected.parked, experimental=GetConvarInt('brothers_experimental',0)==1, friendlyFire=BrothersConfig.friendlyFire}
end
local function slotFor(id)
    if slots[id] then return slots[id] end
    -- Drop stale reservations first, avoiding slot drift after disconnect/reconnect.
    for member in pairs(slots) do if not online(member) then slots[member]=nil end end
    local used={}
    for _, slot in pairs(slots) do used[slot]=true end
    for slot=1,BrothersConfig.maxPlayers do
        if not used[slot] then slots[id]=slot;return slot end
    end
end
RegisterNetEvent('brothers_world:hello', function()
    local id=tonumber(source)
    if not online(id) then return end
    local slot=slotFor(id)
    if not slot then notice(id,'Этот кооператив рассчитан на двух игроков.');return end
    TriggerClientEvent('brothers_world:ready', id, slot, modeSettings(), weather, hour)
end)
RegisterNetEvent('brothers_world:buy', function(shopId)
    local id=tonumber(source)
    if not online(id) or not slots[id] then return end
    -- Never accept a model, weapon, amount or coordinate chosen by a client.
    local point=BrothersCore.shop(shopId)
    if not point or (point.experimentalOnly and GetConvarInt('brothers_experimental',0)~=1) then return end
    local now=GetGameTimer()
    cooldowns[id]=cooldowns[id] or {}
    local previous=cooldowns[id][point.id]
    if previous and now-previous<point.cooldown then
        notice(id,'Подождите немного перед повторным использованием этой точки.');return
    end
    cooldowns[id][point.id]=now
    TriggerClientEvent('brothers_world:grant', id, point.id)
end)
RegisterNetEvent('brothers_world:position',function(position,heading,alive,unsafe)
    local id=tonumber(source)
    if not online(id) or not slots[id] or type(position)~='table' then return end
    local function finite(value) return type(value)=='number' and value==value and math.abs(value)<math.huge end
    if not finite(position.x) or not finite(position.y) or not finite(position.z) or
        math.abs(position.x)>12000 or math.abs(position.y)>12000 or position.z < -200 or position.z>2000 or
        not finite(heading) or type(alive)~='boolean' or type(unsafe)~='boolean' then return end
    local now=GetGameTimer()
    if positionAt[id] and now-positionAt[id]<500 then return end
    positionAt[id]=now
    TriggerClientEvent('brothers_world:position',-1,id,GetPlayerName(tostring(id)),
        {x=position.x,y=position.y,z=position.z},heading%360,alive,unsafe)
end)
RegisterNetEvent('brothers_world:regroup', function()
    local id=tonumber(source)
    if not online(id) or not slots[id] then return end
    local now=GetGameTimer()
    if regroupAt[id] and now-regroupAt[id]<15000 then
        notice(id,'Перегруппировка доступна раз в 15 секунд.');return
    end
    regroupAt[id]=now
    TriggerClientEvent('brothers_world:regroupApproved', id)
end)
RegisterCommand('together', function(id)
    if id~=0 and not IsPlayerAceAllowed(id,'brothers.manage') then return end
    for member in pairs(slots) do
        if online(member) then TriggerClientEvent('brothers_world:hubApproved',member) end
    end
end, false)
AddEventHandler('playerDropped', function()
    local id=tonumber(source)
    slots[id],cooldowns[id],regroupAt[id],positionAt[id]=nil,nil,nil,nil
    TriggerClientEvent('brothers_world:removeMember',-1,id)
end)
exports('SetEnvironment', function(newWeather,newHour)
    if type(newWeather)~='string' or not allowedWeather[newWeather] or
        type(newHour)~='number' or newHour~=newHour or newHour%1~=0 or newHour<0 or newHour>23 then return false end
    weather,hour=newWeather,newHour
    TriggerClientEvent('brothers_world:environment',-1,weather,hour)
    return true
end)
exports('GetHub',function() return BrothersCore.slotPosition(1) end)
print('[brothers_world] Local co-op ready: shared spawn, buddy map and free supply points. No database.')
