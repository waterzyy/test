local root=arg[1] or 'shared-resources/brothers_world/'
local passed=0
local function check(ok,msg) assert(ok,msg);passed=passed+1;print('PASS '..msg) end
local ev,net,cmd,threads,sent,logs={},{},{},{},{},{}
local players={[11]=true,[22]=true}
local mode,buckets,changed,tick='on',{[11]=3,[22]=9},{},10000
local env=setmetatable({BrothersConfig={maxPlayers=2}},{__index=_G})
env.GetPlayers=function()return {'22','11'}end
env.GetConvar=function()return mode end
env.GetPlayerName=function(id)return players[tonumber(id)] and 'Brother' or nil end
env.GetPlayerRoutingBucket=function(id)return buckets[id]end
env.SetPlayerRoutingBucket=function(id,b)buckets[id]=b;changed[#changed+1]=id end
env.GetGameTimer=function()return tick end
env.RegisterNetEvent=function(n,f)net[n]=f end
env.AddEventHandler=function(n,f)ev[n]=f end
env.RegisterCommand=function(n,f)cmd[n]=f end
env.CreateThread=function(f)threads[#threads+1]=f end
env.Wait=function()coroutine.yield()end
env.TriggerClientEvent=function(...)sent[#sent+1]={...}end
env.IsPlayerAceAllowed=function(id,ace)return id==11 and ace=='brothers.manage'end
env.GetPlayerPed=function(id)return id+100 end
env.DoesEntityExist=function()return true end
env.GetEntityCoords=function(id)return {x=id,y=20,z=30}end
env.print=function(line)logs[#logs+1]=line end
assert(loadfile(root..'session_server.lua','t',env))()
env.source=11;ev['brothers_world:hello']();check(buckets[11]==0,'handshake moves first player into shared bucket before world ready')
env.source=22;ev.playerJoining();check(buckets[22]==0,'joining brother is put in the same bucket')
local co=coroutine.create(threads[1]);local ok,err=coroutine.resume(co);assert(ok,err);check(#changed==2,'healthy shared bucket is not repeatedly rewritten')
buckets[22]=8;ok,err=coroutine.resume(co);assert(ok,err);check(buckets[22]==0,'foreign instance assignment is reconciled for dedicated local world')
sent={};cmd.brothers_sync(22,{'fix'});check(#sent==0,'ordinary second player cannot repair or teleport both players')
sent={};cmd.brothers_sync(0,{'fix'});check(#sent==4,'console repair requests own visibility and shared hub for both clients')
sent={};cmd.brothers_sync(11,{'fix'});check(#sent==4,'configured host may request shared repair')
logs={};env.source=11;net['brothers_session:report']({11,22},true);cmd.brothers_sync(0,{});local dump=table.concat(logs,'\n');check(dump:find('clientSees=[11,22]',1,true)~=nil,'diagnostics include actual client entity presence report')
logs={};env.source=22;net['brothers_session:report']({999},true);cmd.brothers_sync(0,{});dump=table.concat(logs,'\n');check(dump:find('clientSees=[999]',1,true)==nil,'nonexistent player ids cannot pollute session report')
tick=tick+16000;logs={};cmd.brothers_sync(0,{});check(table.concat(logs,'\n'):find('clientReport=missing/stale',1,true)~=nil,'stale report is never represented as current synchronization')
mode='off';sent={};local before=#changed;logs={};cmd.brothers_sync(0,{'fix'});check(#sent==0 and #changed==before and table.concat(logs,'\n'):find('FULLY restart',1,true)~=nil,'OneSync off is rejected with full restart instructions instead of fake success')
-- Client: separate environment, active ped list rather than server map markers.
local ce,cn,ct,requests,calls={},{},{},{},{}
local client=setmetatable({},{__index=_G})
client.AddEventHandler=function(n,f)ce[n]=f end
client.RegisterNetEvent=function(n,f)cn[n]=f end
client.CreateThread=function(f)ct[#ct+1]=f end
client.Wait=function()coroutine.yield()end
client.PlayerPedId=function()return 111 end
client.PlayerId=function()return 1 end
client.DoesEntityExist=function(p)return p~=0 end
client.GetActivePlayers=function()return {1,2}end
client.GetPlayerPed=function(p)return p+110 end
client.GetPlayerServerId=function(p)return p==1 and 11 or 22 end
client.NetworkIsSessionStarted=function()return true end
client.NetworkIsPlayerActive=function()return true end
client.IsEntityVisible=function()return true end
client.TriggerServerEvent=function(...)requests[#requests+1]={...}end
for _,name in ipairs({'NetworkSetEntityInvisibleToNetwork','SetEntityVisible','ResetEntityAlpha','NetworkSetInSpectatorMode'})do client[name]=function(...)calls[#calls+1]={name,...}end end
assert(loadfile(root..'session_client.lua','t',client))()
ce.playerSpawned();check(#calls==4 and calls[1][2]==111 and calls[1][3]==false,'spawn restores only own ped network visibility and clears spectator state')
check(requests[1][1]=='brothers_session:report' and #requests[1][2]==2 and requests[1][2][2]==22,'presence report measures real nearby players rather than blips')
calls={};client.source=1;cn['brothers_session:repair']();check(#calls==0,'forged local repair event does not mutate the player')
client.source=65535;cn['brothers_session:repair']();check(#calls==4,'server-authorized repair restores own visibility')
print(('Completed %d session checks; real FiveM entity replication NOT simulated'):format(passed))
