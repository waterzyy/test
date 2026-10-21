local ready, spawning, slot, settings = false, false, 1, BrothersConfig.main
local spawnedOnce, deathAt, helpOpen = false, nil, false
local buddyBlips, shopBlips, peers = {}, {}, {}
local ownedVehicle, ownedVehicleAt, grantingVehicle = nil, 0, false
local spawnManager = exports.spawnmanager
local function serverEvent() return source==65535 end
local function components(text)
    for _, part in ipairs(BrothersCore.textChunks(text,90)) do AddTextComponentSubstringPlayerName(part) end
end
local function notice(text)
    print('[brothers_world] '..tostring(text))
    BeginTextCommandThefeedPost('STRING');components(text);EndTextCommandThefeedPostTicker(false,false)
end
local function text(x,y,scale,value)
    SetTextFont(0);SetTextScale(0.0,scale);SetTextColour(255,255,255,230);SetTextOutline()
    SetTextWrap(x,math.min(x+0.69,0.98));BeginTextCommandDisplayText('STRING');components(value);EndTextCommandDisplayText(x,y)
end
local function environment(weather,hour)
    if type(weather)~='string' or type(hour)~='number' then return end
    ClearOverrideWeather();ClearWeatherTypePersist();SetWeatherTypeNowPersist(weather)
    NetworkOverrideClockTime(hour,0,0)
end
local function comfort(ped,refill)
    SetPedMaxHealth(ped,settings.health);SetEntityMaxHealth(ped,settings.health)
    SetCanAttackFriendly(ped,settings.friendlyFire==true,false)
    NetworkSetFriendlyFireOption(settings.friendlyFire==true)
    if refill then SetEntityHealth(ped,settings.health);SetPedArmour(ped,settings.armour) end
end
local function buddyPosition()
    for _,player in ipairs(GetActivePlayers()) do
        if player~=PlayerId() and NetworkIsPlayerActive(player) then
            local ped=GetPlayerPed(player)
            if ped~=0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
                return GetEntityCoords(ped),GetEntityHeading(ped),
                    GetInteriorFromEntity(ped)~=0 or IsEntityInWater(ped)
            end
        end
    end
    for _,peer in pairs(peers) do
        if peer.alive and GetGameTimer()-peer.at<10000 then return peer.position,peer.heading,peer.unsafe end
    end
end
local function spawnPosition(nearBuddy)
    local fallback=BrothersCore.slotPosition(slot)
    if not nearBuddy then return fallback end
    local p,heading,unsafe=buddyPosition()
    if not p or unsafe then return fallback end
    -- A distant brother can be outside the entity streaming radius. Load a
    -- small collision scene before querying navmesh; never guess a roof/interior Z.
    RequestCollisionAtCoord(p.x,p.y,p.z)
    NewLoadSceneStartSphere(p.x,p.y,p.z,75.0,0)
    local untilTime=GetGameTimer()+2500
    while not IsNewLoadSceneLoaded() and GetGameTimer()<untilTime do Wait(0) end
    local found,safe=GetSafeCoordForPed(p.x+BrothersConfig.respawnBuddyDistance,p.y+2.0,p.z,true,14)
    NewLoadSceneStop()
    if found and BrothersCore.safeBuddyPosition(p,safe) then
        return {x=safe.x,y=safe.y,z=safe.z+0.15,heading=heading}
    end
    return fallback
end

local function spawn(nearBuddy,forceHub)
    if not ready or spawning then return end
    spawning=true
    local position=spawnPosition(nearBuddy and not forceHub)
    local current=GetEntityModel(PlayerPedId())
    local model=spawnedOnce and current or GetHashKey(BrothersConfig.playerModels[slot] or BrothersConfig.playerModels[1])
    position.model=model
    position.skipFade=false
    spawnManager:spawnPlayer(position,function()
        local ped=PlayerPedId();comfort(ped,true)
        SetPlayerWantedLevel(PlayerId(),0,false);SetPlayerWantedLevelNow(PlayerId(),false)
        if not HasPedGotWeapon(ped,GetHashKey('WEAPON_PISTOL'),false) then
            GiveWeaponToPed(ped,GetHashKey('WEAPON_PISTOL'),120,false,false)
        end
        spawnedOnce,spawning,deathAt=true,false,nil
        notice('Вы вместе в Los Santos. F6 / /coophelp — помощь. E или крестовина вниз — точка снабжения.')
    end)
end
local function shopAvailable(point) return not point.experimentalOnly or settings.experimental==true end
local function addShops()
    for _,blip in ipairs(shopBlips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
    shopBlips={}
    for _,point in ipairs(BrothersConfig.shops) do
        if shopAvailable(point) then
            local blip=AddBlipForCoord(point.x,point.y,point.z)
            SetBlipSprite(blip,point.sprite);SetBlipColour(blip,point.colour);SetBlipScale(blip,0.62)
            SetBlipAsShortRange(blip,false)
            BeginTextCommandSetBlipName('STRING');components(point.label..' (бесплатно)');EndTextCommandSetBlipName(blip)
            shopBlips[#shopBlips+1]=blip
        end
    end
end
local function interact()
    if not ready or spawning or IsEntityDead(PlayerPedId()) then return end
    local point=BrothersCore.nearestShop(GetEntityCoords(PlayerPedId()),2.6,settings.experimental)
    if point then TriggerServerEvent('brothers_world:buy',point.id) end
end
local function vehicleEmpty(vehicle)
    for seat=-1,GetVehicleMaxNumberOfPassengers(vehicle)-1 do
        if GetPedInVehicleSeat(vehicle,seat)~=0 then return false end
    end
    return true
end
local function removeOwnEmptyVehicle()
    if not ownedVehicle or not DoesEntityExist(ownedVehicle) then ownedVehicle=nil;return true end
    if not vehicleEmpty(ownedVehicle) then return false end
    if not NetworkHasControlOfEntity(ownedVehicle) then
        NetworkRequestControlOfEntity(ownedVehicle)
        local untilTime=GetGameTimer()+500
        while not NetworkHasControlOfEntity(ownedVehicle) and GetGameTimer()<untilTime do Wait(0) end
    end
    if not NetworkHasControlOfEntity(ownedVehicle) then return false end
    SetEntityAsMissionEntity(ownedVehicle,true,true);DeleteVehicle(ownedVehicle)
    ownedVehicle=nil
    return true
end
local function vehicle(point)
    if grantingVehicle then return end
    if IsPedInAnyVehicle(PlayerPedId(),false) then notice('Сначала выйдите из машины.');return end
    grantingVehicle=true
    CreateThread(function()
        local model=GetHashKey(point.model)
        if not IsModelInCdimage(model) or not IsModelAVehicle(model) then
            notice('Модель не доступна в этом игровом build.');grantingVehicle=false;return
        end
        RequestModel(model)
        local untilTime=GetGameTimer()+6000
        while not HasModelLoaded(model) and GetGameTimer()<untilTime do Wait(0) end
        if not HasModelLoaded(model) then notice('Машина не загрузилась. Попробуйте позже.');SetModelAsNoLongerNeeded(model);grantingVehicle=false;return end
        if not removeOwnEmptyVehicle() then
            notice('Ваша предыдущая машина занята или недоступна для замены.');SetModelAsNoLongerNeeded(model);grantingVehicle=false;return
        end
        local p=point.spawn
        if IsAnyVehicleNearPoint(p.x,p.y,p.z,3.5) then
            notice('Освободите место выдачи машины и повторите.');SetModelAsNoLongerNeeded(model);grantingVehicle=false;return
        end
        local car=CreateVehicle(model,p.x,p.y,p.z,p.heading,true,false)
        if car==0 then notice('Не удалось создать машину.');SetModelAsNoLongerNeeded(model);grantingVehicle=false;return end
        SetEntityAsMissionEntity(car,true,true);SetVehicleOnGroundProperly(car)
        SetVehicleNumberPlateText(car,'BROTHERS');SetVehicleEngineOn(car,true,true,false)
        SetPedIntoVehicle(PlayerPedId(),car,-1)
        ownedVehicle,ownedVehicleAt=car,GetGameTimer()
        SetModelAsNoLongerNeeded(model);grantingVehicle=false
        notice('Готово! Одновременно доступна одна личная машина; занятую братом машину ресурс не удаляет.')
    end)
end
RegisterNetEvent('brothers_world:ready',function(newSlot,newSettings,weather,hour)
    if not serverEvent() or (newSlot~=1 and newSlot~=2) or type(newSettings)~='table' then return end
    slot,settings=newSlot,newSettings
    if ready then return end
    ready=true;spawnManager:setAutoSpawn(false);environment(weather,hour);addShops();spawn(false)
end)
RegisterNetEvent('brothers_world:position',function(id,name,position,heading,alive,unsafe)
    if not serverEvent() or tonumber(id)==GetPlayerServerId(PlayerId()) then return end
    peers[id]={position=position,heading=heading,alive=alive,unsafe=unsafe,at=GetGameTimer()}
    local current=buddyBlips[id]
    if not current then
        local blip=AddBlipForCoord(position.x,position.y,position.z)
        SetBlipSprite(blip,1);SetBlipColour(blip,3);SetBlipScale(blip,0.85);SetBlipAsShortRange(blip,false)
        BeginTextCommandSetBlipName('STRING');components('Брат: '..tostring(name));EndTextCommandSetBlipName(blip)
        current={blip=blip};buddyBlips[id]=current
    end
    SetBlipCoords(current.blip,position.x,position.y,position.z)
    SetBlipRotation(current.blip,math.floor(heading))
    SetBlipAlpha(current.blip,alive and 255 or 120)
end)
RegisterNetEvent('brothers_world:removeMember',function(id)
    if not serverEvent() then return end
    peers[id]=nil
    if buddyBlips[id] then RemoveBlip(buddyBlips[id].blip);buddyBlips[id]=nil end
end)
RegisterNetEvent('brothers_world:notice',function(message) if serverEvent() then notice(message) end end)
RegisterNetEvent('brothers_world:environment',function(weather,hour) if serverEvent() then environment(weather,hour) end end)
RegisterNetEvent('brothers_world:grant',function(id)
    if not serverEvent() or not ready or IsEntityDead(PlayerPedId()) then return end
    local point=BrothersCore.shop(id)
    if not point or not shopAvailable(point) or BrothersCore.distanceSquared(GetEntityCoords(PlayerPedId()),point)>8.0^2 then return end
    local ped=PlayerPedId()
    if point.kind=='health' then comfort(ped,true);notice('Здоровье и броня восстановлены. Бесплатно.')
    elseif point.kind=='loadout' then
        for _,item in ipairs(BrothersConfig.loadout) do
            GiveWeaponToPed(ped,GetHashKey(item.weapon),item.ammo,false,false)
        end
        notice('Выданы пистолет, дробовик, фонарик, нож и патроны. Бесплатно.')
    elseif point.kind=='repair' then
        local car=GetVehiclePedIsIn(ped,false)
        if car~=0 and GetPedInVehicleSeat(car,-1)==ped then
            SetVehicleFixed(car);SetVehicleDeformationFixed(car);SetVehicleDirtLevel(car,0.0);notice('Машина отремонтирована.')
        else notice('Подъедьте к точке ремонта за рулём своей машины.') end
    elseif point.kind=='vehicle' then vehicle(point) end
end)
RegisterNetEvent('brothers_world:regroupApproved',function() if serverEvent() then spawn(true) end end)
RegisterNetEvent('brothers_world:hubApproved',function() if serverEvent() then spawn(false,true) end end)
AddEventHandler('brothers_world:interact',interact)
-- A key mapping works on foot and in a vehicle: E is otherwise the horn while
-- driving. Route through the same local event as the pad and co-op activities.
RegisterCommand('brothers_interact',function() TriggerEvent('brothers_world:interact') end,false)
RegisterKeyMapping('brothers_interact','Взаимодействие: точки снабжения и задания','keyboard','E')
RegisterCommand('coophelp',function() helpOpen=not helpOpen end,false)
RegisterKeyMapping('coophelp','Помощь: кооператив для двоих','keyboard','F6')
RegisterCommand('regroup',function() TriggerServerEvent('brothers_world:regroup') end,false)
CreateThread(function()
    spawnManager:setAutoSpawn(false)
    while not NetworkIsSessionStarted() or not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    while not ready do TriggerServerEvent('brothers_world:hello');Wait(2000) end
end)
CreateThread(function()
    while true do
        Wait(ready and 500 or 1000)
        if ready then
            local ped=PlayerPedId()
            if IsEntityDead(ped) then
                deathAt=deathAt or GetGameTimer()
                if GetGameTimer()-deathAt>=BrothersConfig.respawnDelayMs then spawn(true) end
            else deathAt=nil end
            NetworkSetFriendlyFireOption(settings.friendlyFire==true)
            SetCanAttackFriendly(ped,settings.friendlyFire==true,false)
            for id,peer in pairs(peers) do
                if GetGameTimer()-peer.at>15000 then
                    peers[id]=nil
                    if buddyBlips[id] then RemoveBlip(buddyBlips[id].blip);buddyBlips[id]=nil end
                end
            end
        end
    end
end)
CreateThread(function()
    while true do
        Wait(1000)
        if ready then
            local ped=PlayerPedId();local p=GetEntityCoords(ped)
            TriggerServerEvent('brothers_world:position',{x=p.x,y=p.y,z=p.z},GetEntityHeading(ped),
                not IsEntityDead(ped),GetInteriorFromEntity(ped)~=0 or IsEntityInWater(ped))
        end
    end
end)
CreateThread(function()
    while true do
        if not ready then Wait(500)
        else
            Wait(0)
            SetPedDensityMultiplierThisFrame(settings.peds)
            SetScenarioPedDensityMultiplierThisFrame(settings.peds,settings.peds)
            SetVehicleDensityMultiplierThisFrame(settings.traffic)
            SetRandomVehicleDensityMultiplierThisFrame(settings.traffic)
            SetParkedVehicleDensityMultiplierThisFrame(settings.parked)
        end
    end
end)
CreateThread(function()
    while true do
        local sleep=700
        if ready then
            local p=GetEntityCoords(PlayerPedId())
            local nearest=BrothersCore.nearestShop(p,32.0,settings.experimental)
            if nearest then
                sleep=0
                for _,point in ipairs(BrothersConfig.shops) do
                    if shopAvailable(point) and BrothersCore.distanceSquared(p,point)<32.0^2 then
                        DrawMarker(1,point.x,point.y,point.z-0.95,0,0,0,0,0,0,1.0,1.0,0.3,
                            point.experimentalOnly and 160 or 50,point.experimentalOnly and 80 or 180,240,145,false,false,2,false,nil,nil,false)
                    end
                end
                local close=BrothersCore.nearestShop(p,2.6,settings.experimental)
                if close then
                    text(0.22,0.84,0.34,close.label..' — бесплатно. E / крестовина вниз')
                end
            end
            if helpOpen then
                sleep=0
                DrawRect(0.5,0.49,0.76,0.71,12,18,27,220)
                local lines={'ДВА БРАТА — LOS SANTOS','F6 / /coophelp — скрыть помощь',
                    'E или крестовина вниз у маркера — получить товар бесплатно.',
                    'Синие значки: транспорт. Зелёные: лечение. Жёлтые: оружие.',
                    'У каждого одна личная машина. Занятые машины не удаляются.',
                    'Синий игрок на карте — ваш брат. Общий хаб: парковка Legion Square.',
                    'После смерти: 6 секунд и безопасное место рядом с братом или хаб.',
                    '/regroup — вернуться к брату (не в машину/интерьер), раз в 15 сек.',
                    'Огонь по брату выключен; от NPC, аварий и взрывов вред остаётся.',
                    'Здоровья больше обычного, но бессмертия нет.',
                    'Оружие/броня: рядом с хабом, Ammu-Nation и Pillbox.',
                    'Газ R2, тормоз L2, крестик в машине — ручник. Отпустите его для езды.',
                    'Для свободного управления миром хост использует vMenu.',
                    'Магазины — лёгкие бесплатные точки, не полная экономика GTA.'}
                for i,line in ipairs(lines) do text(0.15,0.16+(i-1)*0.045,0.28,line) end
            end
        end
        Wait(sleep)
    end
end)
CreateThread(function()
    while true do
        Wait(10000)
        if ownedVehicle and DoesEntityExist(ownedVehicle) then
            if not vehicleEmpty(ownedVehicle) then ownedVehicleAt=GetGameTimer()
            elseif GetGameTimer()-ownedVehicleAt>600000 then removeOwnEmptyVehicle() end
        else ownedVehicle=nil end
    end
end)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    for _,current in pairs(buddyBlips) do if DoesBlipExist(current.blip) then RemoveBlip(current.blip) end end
    for _,blip in ipairs(shopBlips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
    -- Do not delete any occupied vehicle or any car not created by this resource.
    if ownedVehicle and DoesEntityExist(ownedVehicle) and vehicleEmpty(ownedVehicle) and NetworkHasControlOfEntity(ownedVehicle) then
        SetEntityAsMissionEntity(ownedVehicle,true,true);DeleteVehicle(ownedVehicle)
    end
end)
