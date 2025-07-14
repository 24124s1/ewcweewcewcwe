getgenv().killAll = false
getgenv().teamCheck = false
getgenv().targetPartName = "Head"
getgenv().radius = 100000
getgenv().fireDelay = 0.1
getgenv().bulletTracers = getgenv().bulletTracers or false
getgenv().silentAim = getgenv().silentAim or false
getgenv().showFOV = getgenv().showFOV or false
getgenv().fov = getgenv().fov or 150
getgenv().hitchance = getgenv().hitchance or 85
getgenv().useRandomHitbox = getgenv().useRandomHitbox or false
getgenv().selectedHitbox = getgenv().selectedHitbox or "Head"
getgenv().enablePrediction = getgenv().enablePrediction or false
getgenv().predictionAmount = getgenv().predictionAmount or 0.5
getgenv().infDamage = getgenv().infDamage or false
getgenv().hitboxChances = getgenv().hitboxChances or {
    Head = 100,
    Torso = 100,
    HumanoidRootPart = 100,
    ["Left Arm"] = 100,
    ["Left Leg"] = 100,
    ["Right Arm"] = 100
}
getgenv().BulletTracerColor = getgenv().BulletTracerColor or Color3.fromRGB(0, 170, 255)
getgenv().autoShoot = getgenv().autoShoot or false
getgenv().autoShootDelay = getgenv().autoShootDelay or 1
getgenv().doubleTap = getgenv().doubleTap or false
getgenv().doubleTapHitchance = getgenv().doubleTapHitchance or 85 
getgenv().DoubleTapTracerColor = Color3.fromRGB(140, 140, 140)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local RunService = game:GetService("RunService")
local realHitboxes = {"Head","Torso","HumanoidRootPart","Left Arm","Left Leg","Right Arm"}
local adjusting = false

local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(0, 170, 255)
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.Radius = getgenv().fov
fovCircle.Visible = getgenv().showFOV
fovCircle.Transparency = 1

RunService.RenderStepped:Connect(function()
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    fovCircle.Radius = getgenv().fov
    fovCircle.Visible = getgenv().showFOV
end)

local function getTargetsInRadius()
    local targets = {}
    local origin = Camera.CFrame.Position
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild(getgenv().targetPartName) then
            if not getgenv().teamCheck or plr.Team ~= LocalPlayer.Team then
                local part = plr.Character[getgenv().targetPartName]
                local distance = (part.Position - origin).Magnitude
                if distance <= getgenv().radius then
                    table.insert(targets, part)
                end
            end
        end
    end
    return targets
end

local function fireDamageSignal(part, pos)
    local dir = (pos - Camera.CFrame.Position).Unit
    local args = {
        part,
        0,
        "VM_AntiHero_UP2",
        true,
        [6] = "Awd1jTmMCYdoI5gq5DXNFry,QGpe.q",
        [7] = dir,
        [8] = pos,
        [9] = 93.03475952148438
    }
    ReplicatedStorage:WaitForChild("Signals"):WaitForChild("damagesignal"):FireServer(unpack(args))
end

local function normalizeChances(excludeHitbox)
    if adjusting then return end
    adjusting = true
    local total = 0
    for _, hitbox in ipairs(realHitboxes) do
        total = total + (getgenv().hitboxChances[hitbox] or 0)
    end
    if total > 100 then
        local excess = total - 100
        local adjustableTotal = 0
        for _, hitbox in ipairs(realHitboxes) do
            if hitbox ~= excludeHitbox then
                adjustableTotal = adjustableTotal + (getgenv().hitboxChances[hitbox] or 0)
            end
        end
        if adjustableTotal == 0 then
            getgenv().hitboxChances[excludeHitbox] = 100
        else
            for _, hitbox in ipairs(realHitboxes) do
                if hitbox ~= excludeHitbox then
                    local oldValue = getgenv().hitboxChances[hitbox] or 0
                    local reduction = (oldValue / adjustableTotal) * excess
                    local newValue = math.max(0, oldValue - reduction)
                    getgenv().hitboxChances[hitbox] = newValue
                end
            end
        end
    end
    adjusting = false
end

local function createBeam(fromPos, toPos)
    local attPart = Instance.new("Part")
    attPart.Size = Vector3.new(0.1, 0.1, 0.1)
    attPart.CFrame = CFrame.new(fromPos)
    attPart.Anchored = true
    attPart.CanCollide = false
    attPart.Transparency = 1
    attPart.Name = "TracerPart"
    attPart.Parent = workspace
    local a0 = Instance.new("Attachment", attPart)
    local a1 = Instance.new("Attachment", attPart)
    a1.WorldPosition = toPos
    local beam = Instance.new("Beam")
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.Color = ColorSequence.new(getgenv().BulletTracerColor)
    beam.Width0 = 0.035
    beam.Width1 = 0.035
    beam.LightEmission = 1
    beam.FaceCamera = true
    beam.Transparency = NumberSequence.new(0.1)
    beam.Parent = attPart
    task.delay(2, function()
        if attPart then attPart:Destroy() end
    end)
end

local function isInFOV(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    if not onScreen then return false end
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
    return dist <= getgenv().fov
end

local function passesHitchanceValue(value)
    return math.random(1, 100) <= value
end

local function passesHitchance()
    return math.random(1, 100) <= getgenv().hitchance
end

local function getCurrentWeapon()
    local vmfolder = workspace:FindFirstChild("vmfolder")
    if vmfolder and #vmfolder:GetChildren() > 0 then
        return vmfolder:GetChildren()[1].Name
    end
    return "VM_AntiHero_UP2"
end

local function isVisible(part)
    local origin = Camera.CFrame.Position
    local direction = (part.Position - origin)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character }
    local result = workspace:Raycast(origin, direction, rayParams)
    return not result or result.Instance:IsDescendantOf(part.Parent)
end

local function getWeightedRandomHitbox(chances)
    local total = 0
    for _, hitbox in ipairs(realHitboxes) do
        total = total + (chances[hitbox] or 0)
    end
    if total == 0 then return nil end
    local roll = math.random() * total
    local cumulative = 0
    for _, hitbox in ipairs(realHitboxes) do
        cumulative = cumulative + (chances[hitbox] or 0)
        if roll <= cumulative then return hitbox end
    end
end

local function getValidPart(character)
    if getgenv().useRandomHitbox then
        local tries = 10
        for i = 1, tries do
            local hitbox = getWeightedRandomHitbox(getgenv().hitboxChances)
            if hitbox then
                local part = character:FindFirstChild(hitbox)
                if part and isInFOV(part.Position) and passesHitchance() and isVisible(part) then
                    return part
                end
            end
        end
        return nil
    else
        local part = character:FindFirstChild(getgenv().selectedHitbox)
        if part and isInFOV(part.Position) and passesHitchance() and isVisible(part) then
            return part
        end
    end
    return nil
end

local function isInFOV(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    if not onScreen then return false end
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
    return dist <= getgenv().fov
end

local function getClosestVisibleTarget()
    local closest = nil
    local shortestDistance = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if not getgenv().teamCheck or plr.Team ~= LocalPlayer.Team then
                local part = getValidPart(plr.Character)
                if part then
                    local screenPos = Camera:WorldToViewportPoint(part.Position)
                    local mouseDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if mouseDist < shortestDistance then
                        shortestDistance = mouseDist
                        closest = part
                    end
                end
            end
        end
    end
    return closest
end

local function getPredictedPosition(part)
    local velocity = part.AssemblyLinearVelocity or Vector3.new(0,0,0)
    if getgenv().enablePrediction then
        local prediction = velocity * math.clamp(getgenv().predictionAmount, 0, 1)
        return part.Position + prediction
    else
        return part.Position
    end
end

local notificationQueue = {}
local maxActiveNotifications = 3
local activeNotifications = 0

local function processQueue()
    if activeNotifications >= maxActiveNotifications then return end
    local nextMsg = table.remove(notificationQueue, 1)
    if nextMsg then
        activeNotifications += 1
        library:SendNotification(nextMsg)
        task.delay(3, function()
            activeNotifications -= 1
            processQueue()
        end)
    end
end

local function queueNotification(msg)
    table.insert(notificationQueue, msg)
    processQueue()
end

local weaponDamageMap = {
    ["VM_MachineGun"] = 4,
    ["VM_MachineGun_UP1"] = 4,
    ["VM_MachineGun_UP2"] = 4,
    ["VM_Shotgun"] = 2,
    ["VM_Shotgun_UP1"] = 2,
    ["VM_Shotgun_UP2"] = 2,
    ["VM_CombatRifle_UP2"] = 6,
    ["VM_CombatRifle"] = 6,
    ["VM_CombatRifle_UP1"] = 6,
    ["VM_Ak48_UP2"] = 6,
    ["VM_Ak48"] = 6,
    ["VM_Ak48_UP1"] = 6,
    ["VM_SwatRifle_UP2"] = 12,
    ["VM_SwatRifle"] = 12,
    ["VM_SwatRifle_UP1"] = 12,
    ["VM_SteamPower_UP2"] = 29,
    ["VM_SteamPower"] = 29,
    ["VM_SteamPower_UP1"] = 29,
    ["VM_DualUzi_UP2"] = 7,
    ["VM_DualUzi"] = 7,
    ["VM_DualUzi_UP1"] = 7,
    ["VM_BravePatriot_UP1"] = 30,
    ["VM_BravePatriot"] = 30,
    ["VM_BravePatriot_UP2"] = 30,
    ["VM_Eindringling"] = 6,
    ["VM_Eindringling_UP1"] = 6,
    ["VM_Eindringling_UP2"] = 6,
    ["VM_PhotonShotgun_UP2"] = 23,
    ["VM_PhotonShotgun"] = 23,
    ["VM_PhotonShotgun_UP1"] = 23,
    ["VM_Hellraiser_UP2"] = 9,
    ["VM_Hellraiser"] = 9,
    ["VM_Hellraiser_UP1"] = 9,
    ["VM_CrystalLaserCannon_UP2"] = 7,
    ["VM_CrystalLaserCannon"] = 7,
    ["VM_CrystalLaserCannon_UP1"] = 7,
    ["VM_DesertFighter"] = 18,
    ["VM_DesertFighter_UP1"] = 18,
    ["VM_DesertFighter_UP2"] = 18,
    ["VM_XmasDestroyer_UP1"] = 5,
    ["VM_XmasDestroyer"] = 5,
    ["VM_XmasDestroyer_UP2"] = 5,
    ["VM_PixelGun"] = 14,
    ["VM_PixelGun_UP1"] = 14,
    ["VM_PixelGun_UP2"] = 14,
    ["VM_FastDeath_UP2"] = 8,
    ["VM_FastDeath"] = 8,
    ["VM_FastDeath_UP1"] = 8,
    ["VM_PlasmaPistol_UP2"] = 8,
    ["VM_PlasmaPistol"] = 8,
    ["VM_PlasmaPistol_UP1"] = 8,
    ["VM_SparklyBlaster"] = 8,
    ["VM_SparklyBlaster_UP1"] = 8,
    ["VM_SparklyBlaster_UP2"] = 8,
    ["VM_DualRevolvers_UP2"] = 18,
    ["VM_DualRevolvers"] = 18,
    ["VM_DualRevolvers_UP1"] = 18,
    ["VM_OldComrade"] = 22,
    ["VM_OldComrade_UP1"] = 22,
    ["VM_OldComrade_UP2"] = 22,
    ["VM_PhotonPistol"] = 19,
    ["VM_PhotonPistol_UP1"] = 19,
    ["VM_PhotonPistol_UP2"] = 19,
    ["VM_HotPlasmaPistol"] = 9,
    ["VM_HotPlasmaPistol_UP1"] = 9,
    ["VM_HotPlasmaPistol_UP2"] = 9,
    ["VM_SteamRevolver_UP2"] = 39,
    ["VM_SteamRevolver"] = 39,
    ["VM_SteamRevolver_UP1"] = 39,
    ["VM_DualMachineGuns_UP2"] = 14,
    ["VM_DualMachineGuns"] = 14,
    ["VM_DualMachineGuns_UP1"] = 14,
    ["VM_Exterminator"] = 103,
    ["VM_Exterminator_UP1"] = 103,
    ["VM_Exterminator_UP2"] = 103,
    ["VM_DualHawks_UP2"] = 28,
    ["VM_DualHawks"] = 28,
    ["VM_DualHawks_UP1"] = 28,
    ["VM_SniperRifle"] = 26,
    ["VM_SniperRifle_UP1"] = 26,
    ["VM_SniperRifle_UP2"] = 26,
    ["VM_HungerBow_UP1"] = 30,
    ["VM_HungerBow"] = 30,
    ["VM_HungerBow_UP2"] = 30,
    ["VM_GuerillaRifle_UP2"] = 24,
    ["VM_GuerillaRifle"] = 24,
    ["VM_GuerillaRifle_UP1"] = 24,
    ["VM_TacticalBow_UP2"] = 40,
    ["VM_TacticalBow"] = 40,
    ["VM_TacticalBow_UP1"] = 40,
    ["VM_BrutalHeadhunter_UP2"] = 74,
    ["VM_BrutalHeadhunter"] = 74,
    ["VM_BrutalHeadhunter_UP1"] = 74,
    ["VM_DaterHater_UP2"] = 56,
    ["VM_DaterHater"] = 56,
    ["VM_DaterHater_UP1"] = 56,
    ["VM_FreezeRayRifle_UP2"] = 3,
    ["VM_FreezeRayRifle"] = 3,
    ["VM_FreezeRayRifle_UP1"] = 3,
    ["VM_ElephantHunter_UP2"] = 84,
    ["VM_ElephantHunter"] = 84,
    ["VM_ElephantHunter_UP1"] = 84,
    ["VM_Prototype_UP2"] = 41,
    ["VM_Prototype"] = 41,
    ["VM_Prototype_UP1"] = 41,
    ["VM_SolarRayRifle_UP2"] = 10,
    ["VM_SolarRayRifle"] = 10,
    ["VM_SolarRayRifle_UP1"] = 10,
    ["VM_AntiHero"] = 167,
    ["VM_AntiHero_UP1"] = 167,
    ["VM_AntiHero_UP2"] = 167
}

local function fireMagicBullet(targetPart)
    if not targetPart then return end
    local function doFire(isDT)
        local weapon = getCurrentWeapon()
        local predictedPos = getPredictedPosition(targetPart)
        local direction = (predictedPos - Camera.CFrame.Position).Unit
        local damage = getgenv().infDamage and 9e9 or (weaponDamageMap[weapon] or 7)
        local args = {
            targetPart,
            damage,
            weapon,
            false,
            [6] = "Awd1jTmMCYdoI5gq5DXNFry,QGpe.q",
            [7] = direction,
            [8] = predictedPos,
            [9] = 93.03475952148438
        }
        local char = targetPart:FindFirstAncestorOfClass("Model")
        local player = Players:GetPlayerFromCharacter(char)
        if player then
            if isDT then
                queueNotification("Doubletap hit " .. player.Name .. " in the " .. targetPart.Name)
            else
                local displayDamage = getgenv().infDamage and "inf" or tostring(damage)
                queueNotification("Hit " .. player.Name .. " in the " .. targetPart.Name .. " for " .. displayDamage)
            end
        end
        ReplicatedStorage.Signals.damagesignal:FireServer(unpack(args))
        return predictedPos
    end

    local mainPos = doFire(false)
    if getgenv().bulletTracers then
        createBeam(Camera.CFrame.Position, mainPos)
    end

    if getgenv().doubleTap then
        task.delay(0.05, function()
            if passesHitchanceValue(getgenv().doubleTapHitchance) then
                local secondPos = doFire(true)
                if getgenv().bulletTracers then
                    createBeam(Camera.CFrame.Position, secondPos)
                end
            end
        end)
    end
end

task.spawn(function()
    while true do
        task.wait(getgenv().autoShoot and getgenv().autoShootDelay or 0.1)

        if getgenv().autoShoot then
            local target = getClosestVisibleTarget()
            if target then
                fireMagicBullet(target)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(getgenv().fireDelay or 0.1)

        if getgenv().killAll then
            local targets = getTargetsInRadius()
            for _, part in pairs(targets) do
                fireMagicBullet(part)
            end
        end
    end
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = { ... }
    if not checkcaller() and method == "FireServer" and tostring(self) == "u_replicateBulletTracer" then
        if typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
            local fromPos = args[1]
            local toPos = args[2]
            if getgenv().silentAim then
                local target = getClosestVisibleTarget()
                if target then
                    local predictedPos = getPredictedPosition(target)
                    toPos = predictedPos
                    fireMagicBullet(target)
                end
            end
            if getgenv().bulletTracers then
                createBeam(fromPos, toPos)
            end
        end
        return oldNamecall(self, unpack(args))
    end
    return oldNamecall(self, ...)
end)
