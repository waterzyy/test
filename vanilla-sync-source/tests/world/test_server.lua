local function run()
local root=arg[1] or 'shared-resources/brothers_world/'
local net,events,commands,exported,sent={},{},{},{},{}
local now,experimental=1000,0
local players={[11]='Host',[22]='Brother',[33]='Third'}
local env=setmetatable({},{__index=_G})
env.RegisterNetEvent=function(name,fn) net[name]=fn end
env.AddEventHandler=function(name,fn) events[name]=fn end
env.RegisterCommand=function(name,fn) commands[name]=fn end
env.TriggerClientEvent=function(...) sent[#sent+1]={...} end
env.GetGameTimer=function() return now end
env.GetPlayerName=function(id) return players[tonumber(id)] end
env.GetConvarInt=function(name,default) return name=='brothers_experimental' and experimental or default end
env.IsPlayerAceAllowed=function(id,ace) return id==11 and ace=='brothers.manage' end
env.exports=function(name,fn) exported[name]=fn end
assert(loadfile(root..'config.lua','t',env))();assert(loadfile(root..'core.lua','t',env))()
assert(loadfile(root..'server.lua','t',env))()
local passed=0
local function check(ok,label) assert(ok,label);passed=passed+1;print('PASS '..label) end
local function fire(id,name,...) sent={};env.source=id;net['brothers_world:'..name](...);return sent end
local e=fire(11,'hello');check(e[1][1]=='brothers_world:ready' and e[1][3]==1,'first member receives fixed shared spawn slot one')
e=fire(22,'hello');check(e[1][3]==2,'second member receives slot two rather than random spawn')
e=fire(11,'hello');check(e[1][3]==1,'duplicate hello does not move member to another slot')
e=fire(33,'hello');check(e[1][1]=='brothers_world:notice','third registration cannot claim a co-op slot')
e=fire(33,'buy','hub_loadout');check(#e==0,'unregistered player cannot request supplies')
e=fire(11,'buy',{model='rhino',coords={1,2,3}});check(#e==0,'arbitrary model/coordinate payload is rejected')
e=fire(11,'buy','missing');check(#e==0,'unknown supply id is rejected')
e=fire(11,'buy','hub_loadout');check(e[1][1]=='brothers_world:grant' and e[1][2]==11 and e[1][3]=='hub_loadout','server grants only the allowlisted supply to requesting player')
e=fire(11,'buy','hub_loadout');check(e[1][1]=='brothers_world:notice','repeated supply request is rate limited')
now=now+5001;e=fire(11,'buy','hub_loadout');check(e[1][1]=='brothers_world:grant','supply becomes available after real cooldown')
e=fire(22,'buy','hub_loadout');check(e[1][1]=='brothers_world:grant','supply cooldowns are independent per brother')
e=fire(11,'buy','fun_vigilante');check(#e==0,'main server rejects experimental-only vehicle even with forged id')
experimental=1;e=fire(11,'buy','fun_vigilante');check(e[1][3]=='fun_vigilante','experimental server permits fixed vanilla DLC vehicle')
e=fire(11,'position',{x=100,y=200,z=30},45,true,false)
check(e[1][1]=='brothers_world:position' and e[1][3]==11 and e[1][4]=='Host','buddy marker identity comes from source, not client payload')
e=fire(11,'position',{x=999,y=200,z=30},45,true,false);check(#e==0,'map updates have a bounded send rate')
now=now+501;e=fire(11,'position',{x=0/0,y=2,z=3},45,true,false);check(#e==0,'non-finite map coordinates are rejected')
e=fire(11,'position',{x=20000,y=2,z=3},45,true,false);check(#e==0,'out-of-world map coordinates are rejected')
e=fire(11,'position',{x=1,y=2,z=3},-90,true,false);check(e[1][6]==270,'heading is normalized before marker broadcast')
e=fire(11,'regroup');check(e[1][1]=='brothers_world:regroupApproved' and e[1][2]==11,'regroup moves only the requesting brother')
e=fire(11,'regroup');check(e[1][1]=='brothers_world:notice','regroup is rate limited')
sent={};commands.together(22);check(#sent==0,'ordinary player cannot force both brothers to regroup')
sent={};commands.together(11);check(#sent==2,'host ACE permits shared return to hub')
sent={};commands.together(0);check(#sent==2,'server console can return both to hub')
sent={};check(exported.SetEnvironment('MALWARE',15)==false and #sent==0,'environment export rejects arbitrary weather')
check(exported.SetEnvironment('RAIN',15.5)==false,'environment export rejects fractional/invalid hour')
check(exported.SetEnvironment('RAIN',18)==true and sent[1][1]=='brothers_world:environment','validated environment update is broadcast once')
players[11]=nil;env.source=11;sent={};events.playerDropped()
check(sent[1][1]=='brothers_world:removeMember' and sent[1][3]==11,'disconnect removes buddy marker immediately')
e=fire(33,'hello');check(e[1][3]==1,'vacated slot is reused without moving remaining brother')
print(('Completed %d world-server checks; FiveM APIs simulated'):format(passed))
end
local ok,err=pcall(run);if not ok then io.stderr:write(tostring(err),'\n');os.exit(1) end
