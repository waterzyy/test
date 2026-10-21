local function run()
local root=arg[1] or 'shared-resources/brothers_world/'
assert(loadfile(root..'config.lua'))();assert(loadfile(root..'core.lua'))()
local C=BrothersCore;local passed=0
local function check(ok,label) assert(ok,label);passed=passed+1;print('PASS '..label) end
local one,two=C.slotPosition(1),C.slotPosition(2)
check(C.distanceSquared(one,two)>=9 and C.distanceSquared(one,two)<25,'shared spawn slots are close but not overlapping')
check(one.heading==two.heading and one.z==two.z,'both initial spawns share a known floor and direction')
check(C.nearestShop({x=0,y=0,z=0},2.6,false)==nil,'interaction cannot purchase a distant supply')
local shop=C.shop('hub_health')
check(C.nearestShop(shop,2.6,false).id=='hub_health','nearest point identifies fixed free health supply')
local fun=C.shop('fun_vigilante')
check(C.nearestShop(fun,2.6,false)==nil,'experimental points are hidden in main mode')
check(C.nearestShop(fun,2.6,true).id==fun.id,'experimental point is interactable in experimental mode')
check(C.shop({})==nil and C.shop('unknown')==nil,'shop lookup rejects arbitrary payloads')
local p={x=100,y=100,z=30}
check(C.safeBuddyPosition(p,{x=109,y=102,z=30}),'nearby grounded respawn candidate is accepted')
check(not C.safeBuddyPosition(p,{x=101,y=100,z=30}),'respawn cannot overlap brother or his vehicle')
check(not C.safeBuddyPosition(p,{x=109,y=102,z=39}),'roof/interior floor mismatch is rejected')
check(not C.safeBuddyPosition(p,{x=190,y=102,z=30}),'distant navmesh candidate is rejected')
local text=string.rep('Привет, брат! ',30);local chunks=C.textChunks(text,90)
check(table.concat(chunks)==text,'Russian UI chunking preserves the complete UTF-8 message')
local valid=true;for _,chunk in ipairs(chunks) do valid=valid and #chunk<=90 and utf8.len(chunk)~=nil end
check(valid,'every UI chunk respects native byte limit without cutting UTF-8')
print(('Completed %d world-core checks'):format(passed))
end
local ok,err=pcall(run);if not ok then io.stderr:write(tostring(err),'\n');os.exit(1) end
