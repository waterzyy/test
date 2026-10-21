local function run()
local root=arg[1] or 'shared-resources/brothers_world/'
local net,events,commands,threads,requests,mappings={}, {}, {}, {}, {}, {}
local health,armour,spawns,deleted,blips,weapons={}, {}, {}, {}, {}, {}
local now,position,inVehicle,currentVehicle=1000,{x=212.5,y=-805.5,z=30.75},false,0
local occupants,exists={}, {[42]=true,[99]=true}
local activePlayers,safeZ,scene,experimental={},nil,nil,false
local nextCar,nextBlip=501,100
local env=setmetatable({},{__index=_G})
env.RegisterNetEvent=function(n,f) net[n]=f end
env.AddEventHandler=function(n,f) events[n]=f end
env.RegisterCommand=function(n,f) commands[n]=f end
env.RegisterKeyMapping=function(name,label,device,key) mappings[name]={device=device,key=key} end
env.TriggerEvent=function(name,...) if events[name] then events[name](...) end end
env.CreateThread=function(f) threads[#threads+1]=f end
env.Wait=function() coroutine.yield() end
env.GetGameTimer=function() return now end
env.TriggerServerEvent=function(...) requests[#requests+1]={...} end
env.PlayerId=function() return 1 end
env.PlayerPedId=function() return 42 end
env.GetPlayerServerId=function() return 11 end
env.GetHashKey=function(s) return s end
env.GetEntityModel=function() return 'player_zero' end
env.GetEntityCoords=function(entity) return entity==99 and {x=100,y=100,z=30} or position end
env.GetEntityHeading=function() return 90 end
env.GetActivePlayers=function() return activePlayers end
env.NetworkIsPlayerActive=function() return true end
env.GetPlayerPed=function() return 99 end
env.DoesEntityExist=function(e) return exists[e]==true end
env.IsEntityDead=function() return false end
env.GetInteriorFromEntity=function() return 0 end
env.IsEntityInWater=function() return false end
env.IsNewLoadSceneLoaded=function() return true end
env.NewLoadSceneStartSphere=function(x,y,z) scene={x=x,y=y,z=z} end
env.NewLoadSceneStop=function() end
env.RequestCollisionAtCoord=function() end
env.GetSafeCoordForPed=function(x,y,z,onlyPavement,flags)
    assert(onlyPavement and flags==14);return true,{x=x,y=y,z=safeZ or z}
end
env.SetPedMaxHealth=function(_,h) health.max=h end
env.SetEntityMaxHealth=function(_,h) health.max=h end
env.SetEntityHealth=function(_,h) health.current=h end
env.SetPedArmour=function(_,h) armour.current=h end
env.SetCanAttackFriendly=function(_,v) health.friendlyFire=v end
env.NetworkSetFriendlyFireOption=function(v) health.networkFriendlyFire=v end
env.SetPlayerWantedLevel=function() end
env.SetPlayerWantedLevelNow=function() end
env.HasPedGotWeapon=function(_,w) return weapons[w]~=nil end
env.GiveWeaponToPed=function(_,w,ammo) weapons[w]=ammo end
env.IsPedInAnyVehicle=function() return inVehicle end
env.GetVehiclePedIsIn=function() return inVehicle and currentVehicle or 0 end
env.GetVehicleMaxNumberOfPassengers=function() return 3 end
env.GetPedInVehicleSeat=function(v,seat) return occupants[v] and occupants[v][seat] or 0 end
env.IsModelInCdimage=function() return true end
env.IsModelAVehicle=function() return true end
env.RequestModel=function() end
env.HasModelLoaded=function() return true end
env.SetModelAsNoLongerNeeded=function() end
env.NetworkHasControlOfEntity=function() return true end
env.NetworkRequestControlOfEntity=function() end
env.SetEntityAsMissionEntity=function() end
env.IsAnyVehicleNearPoint=function() return false end
env.CreateVehicle=function() local v=nextCar;nextCar=nextCar+1;exists[v]=true;occupants[v]={};return v end
env.SetVehicleOnGroundProperly=function() end
env.SetVehicleNumberPlateText=function() end
env.SetVehicleEngineOn=function() end
env.SetPedIntoVehicle=function(p,v,s) inVehicle=true;currentVehicle=v;occupants[v][s]=p end
env.DeleteVehicle=function(v) deleted[#deleted+1]=v;exists[v]=false end
env.SetVehicleFixed=function(v) health.repaired=v end
env.SetVehicleDeformationFixed=function() end
env.SetVehicleDirtLevel=function() end
env.AddBlipForCoord=function(x,y,z) nextBlip=nextBlip+1;blips[nextBlip]={x=x,y=y,z=z};return nextBlip end
env.SetBlipCoords=function(b,x,y,z) blips[b].x=x;blips[b].y=y;blips[b].z=z end
env.SetBlipRotation=function(b,h) blips[b].heading=h end
env.SetBlipAlpha=function(b,a) blips[b].alpha=a end
env.DoesBlipExist=function(b) return blips[b]~=nil end
env.RemoveBlip=function(b) blips[b]=nil end
for _,name in ipairs({'BeginTextCommandThefeedPost','AddTextComponentSubstringPlayerName','EndTextCommandThefeedPostTicker',
    'ClearOverrideWeather','ClearWeatherTypePersist','SetWeatherTypeNowPersist','NetworkOverrideClockTime',
    'SetBlipSprite','SetBlipColour','SetBlipScale','SetBlipAsShortRange','BeginTextCommandSetBlipName','EndTextCommandSetBlipName'}) do
    env[name]=function() end
end
env.exports={spawnmanager={setAutoSpawn=function() end,spawnPlayer=function(_,p,cb) spawns[#spawns+1]=p;cb() end}}
assert(loadfile(root..'config.lua','t',env))();assert(loadfile(root..'core.lua','t',env))()
assert(loadfile(root..'client.lua','t',env))()
local passed=0
local function check(ok,label) assert(ok,label);passed=passed+1;print('PASS '..label) end
local function fire(name,...) env.source=65535;net['brothers_world:'..name](...) end
local function latestThread() local co=coroutine.create(threads[#threads]);local ok,e=coroutine.resume(co);assert(ok,e);assert(coroutine.status(co)=='dead') end
local function countBlips() local n=0;for _ in pairs(blips) do n=n+1 end;return n end
check(type(commands.brothers_interact)=='function' and mappings.brothers_interact.device=='keyboard' and
    mappings.brothers_interact.key=='E','keyboard E mapping registers the shared interaction command')
env.source=1;net['brothers_world:ready'](1,env.BrothersConfig.main,'CLEAR',15)
check(#spawns==0,'local forged ready event cannot spawn or reset player')
fire('ready',1,env.BrothersConfig.main,'CLEAR',15)
check(#spawns==1 and spawns[1].x==env.BrothersConfig.hub.x and spawns[1].model=='a_m_y_business_02','initial spawn uses deterministic hub and player-one model')
check(health.max==300 and health.current==300 and armour.current==100,'spawn grants configured health and armour without godmode')
check(health.friendlyFire==false and health.networkFriendlyFire==false,'friendly fire is disabled for cooperative play')
check(weapons.WEAPON_PISTOL==120,'fresh spawn receives basic pistol and ammunition')
fire('ready',1,env.BrothersConfig.main,'CLEAR',15);check(#spawns==1,'duplicate handshake cannot repeatedly respawn player')
requests={};events['brothers_world:interact']();check(requests[1][1]=='brothers_world:buy' and requests[1][2]=='hub_health','controller interaction activates the exact nearby supply')
position={x=0,y=0,z=0};requests={};events['brothers_world:interact']();check(#requests==0,'controller interaction outside shops cannot buy anything')
health.current=100;fire('grant','hub_health');check(health.current==100,'remote health grant is ignored when player is far from fixed supply')
position=env.BrothersConfig.shops[1];fire('grant','hub_health');check(health.current==300,'nearby validated health grant restores player')
fire('grant','totally_unknown');check(health.current==300,'unknown grant id has no effect')
position=env.BrothersCore.shop('hub_loadout');fire('grant','hub_loadout')
check(weapons.WEAPON_PUMPSHOTGUN==48 and weapons.WEAPON_KNIFE==1,'loadout grants only fixed configured vanilla items')
local before=countBlips();fire('position',22,'Brother',{x=5000,y=5000,z=30},45,true,false)
check(countBlips()==before+1 and blips[nextBlip].x==5000,'brother map marker exists outside entity streaming radius')
fire('position',22,'Brother',{x=5100,y=5000,z=30},90,false,false)
check(countBlips()==before+1 and blips[nextBlip].x==5100 and blips[nextBlip].alpha==120,'far buddy marker updates in place and indicates death')
fire('removeMember',22);check(countBlips()==before,'disconnect removes far buddy map marker')
fire('position',22,'Brother',{x=5000,y=5000,z=30},45,true,false)
fire('regroupApproved');local spawn=spawns[#spawns]
check(scene.x==5000 and spawn.x==5009 and spawn.z==30.15,'regroup loads remote collision scene then uses safe pavement near far brother')
safeZ=60;fire('regroupApproved');spawn=spawns[#spawns]
check(spawn.x==env.BrothersConfig.hub.x and spawn.z==env.BrothersConfig.hub.z,'invalid remote roof candidate falls back to known shared hub')
safeZ=nil;fire('hubApproved');check(spawns[#spawns].x==env.BrothersConfig.hub.x,'host hub action does not depend on remote buddy location')
position=env.BrothersCore.shop('hub_sultan');fire('grant','hub_sultan');latestThread()
check(currentVehicle==501 and occupants[501][-1]==42,'garage creates fixed car and seats requesting brother as driver')
-- A new request while inside a car must never delete it under the player.
local threadCount=#threads;fire('grant','hub_sultan');check(#threads==threadCount and #deleted==0,'garage cannot replace a car while requesting player sits inside')
inVehicle=false;occupants[501][-1]=0;occupants[501][0]=99
fire('grant','hub_sultan');latestThread();check(#deleted==0,'garage never deletes previous personal car occupied by brother')
occupants[501][0]=0;fire('grant','hub_sultan');latestThread()
check(#deleted==1 and deleted[1]==501 and currentVehicle==502,'garage replaces only its own empty previous vehicle, keeping limit one')
position=env.BrothersCore.shop('hub_repair');requests={};commands.brothers_interact()
check(#requests==1 and requests[1][1]=='brothers_world:buy' and requests[1][2]=='hub_repair',
    'keyboard command reaches repair interaction once while requester is in driver seat')
fire('grant','hub_repair')
check(health.repaired==502,'repair point affects current car only when requester is driver')
occupants[502][-1]=99;health.repaired=nil;fire('grant','hub_repair')
check(health.repaired==nil,'passenger cannot repair an arbitrary vehicle through shop grant')
position=env.BrothersCore.shop('fun_vigilante');inVehicle=false;local n=#threads;fire('grant','fun_vigilante')
check(#threads==n,'main client refuses experimental-only vehicle grant')
print(('Completed %d world-client checks; FiveM/streaming APIs simulated'):format(passed))
end
local ok,err=pcall(run);if not ok then io.stderr:write(tostring(err),'\n');os.exit(1) end
