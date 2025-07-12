Saim:AddSeparator({
    enabled = true,
    text = "Must Add Up to 100 or Breaks"
})
Saim:AddSeparator({
    enabled = true,
    text = "|No Over|"
})


local function getSumExcept(exceptHitbox)
    local sum = 0
    for _, hitbox in ipairs(realHitboxes) do
        if hitbox ~= exceptHitbox then
            sum = sum + (getgenv().hitboxChances[hitbox] or 0)
        end
    end
    return sum
end

for _, hitboxName in ipairs(realHitboxes) do
    Saim:AddSlider({
        text = hitboxName .. " Chance",
        flag = "Chance_" .. hitboxName:gsub(" ", ""),
        min = 0,
        max = 100,
        increment = 1,
        value = getgenv().hitboxChances[hitboxName],
        callback = function(v)
            getgenv().hitboxChances[hitboxName] = v
        end,
        get = function()
            local currentVal = getgenv().hitboxChances[hitboxName]
            local maxVal = 100 - getSumExcept(hitboxName)
            if maxVal < 0 then maxVal = 0 end
            return currentVal, min(100, maxVal)
        end
    })
end
