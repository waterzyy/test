-- Pure helpers shared with the test harness. No network, native calls or hidden I/O.
BrothersCore = {}
function BrothersCore.shop(id)
    if type(id) ~= 'string' then return nil end
    for _, point in ipairs(BrothersConfig.shops) do
        if point.id == id then return point end
    end
end
function BrothersCore.distanceSquared(a, b)
    return (a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2
end
function BrothersCore.nearestShop(position, radius, experimental)
    local found, best = nil, radius*radius
    for _, point in ipairs(BrothersConfig.shops) do
        local distance = BrothersCore.distanceSquared(position, point)
        if distance <= best and (not point.experimentalOnly or experimental) then found, best = point, distance end
    end
    return found
end
function BrothersCore.slotPosition(slot)
    local offset = BrothersConfig.spawnOffsets[slot] or BrothersConfig.spawnOffsets[1]
    local hub = BrothersConfig.hub
    return {x=hub.x+offset.x, y=hub.y+offset.y, z=hub.z, heading=hub.heading}
end
function BrothersCore.safeBuddyPosition(buddy, safe)
    -- Reject a distant navmesh floor, interior floor, roof or water candidates.
    return safe and BrothersCore.distanceSquared(buddy, safe) >= 3.0^2 and
        BrothersCore.distanceSquared(buddy, safe) <= 40.0^2 and
        math.abs(buddy.z-safe.z) <= 5.0
end
function BrothersCore.textChunks(text, limit)
    local result, chunk = {}, ''
    for character in tostring(text):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        if #chunk + #character > (limit or 90) then result[#result+1]=chunk;chunk='' end
        chunk=chunk..character
    end
    if #chunk>0 then result[#result+1]=chunk end
    return result
end
