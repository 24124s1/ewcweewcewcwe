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
    Head = 100, Torso = 100, HumanoidRootPart = 100,
    ["Left Arm"] = 100, ["Left Leg"] = 100, ["Right Arm"] = 100
}
getgenv().BulletTracerColor = getgenv().BulletTracerColor or Color3.fromRGB(0,170,255)
getgenv().autoShoot = getgenv().autoShoot or false
getgenv().autoShootDelay = getgenv().autoShootDelay or 1
getgenv().doubleTap = getgenv().doubleTap or false
getgenv().doubleTapHitchance = getgenv().doubleTapHitchance or 85
getgenv().DoubleTapTracer = getgenv().DoubleTapTracer or false
getgenv().DoubleTapTracerColor = getgenv().DoubleTapTracerColor or Color3.fromRGB(140,140,140)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local RunService = game:GetService("RunService")
local realHitboxes = {"Head","Torso","HumanoidRootPart","Left Arm","Left Leg","Right Arm"}
local adjusting = false

local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(0,170,255)
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.Radius = getgenv().fov
fovCircle.Visible = getgenv().showFOV
fovCircle.Transparency = 1

RunService.RenderStepped:Connect(function()
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    fovCircle.Radius = getgenv().fov
    fovCircle.Visible = getgenv().showFOV
end)

local function getTargetsInRadius()
    local t={} local o=Camera.CFrame.Position
    for _,p in pairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character and p.Character:FindFirstChild(getgenv().targetPartName) then
            if not getgenv().teamCheck or p.Team~=LocalPlayer.Team then
                local part=p.Character[getgenv().targetPartName]
                if (part.Position-o).Magnitude<=getgenv().radius then table.insert(t, part) end
            end
        end
    end
    return t
end

local function normalizeChances(ex)
    if adjusting then return end
    adjusting=true
    local total=0
    for _,h in ipairs(realHitboxes) do total+=getgenv().hitboxChances[h] or 0 end
    if total>100 then
        local excess=total-100
        local at=0
        for _,h in ipairs(realHitboxes) do if h~=ex then at+=getgenv().hitboxChances[h] or 0 end end
        if at==0 then getgenv().hitboxChances[ex]=100
        else
            for _,h in ipairs(realHitboxes) do if h~=ex then
                local ov=getgenv().hitboxChances[h] or 0
                getgenv().hitboxChances[h]=math.max(0, ov - (ov/at)*excess)
            end end
        end
    end
    adjusting=false
end

local function createBeam(a,b,c)
    local p=Instance.new("Part")
    p.Size=Vector3.new(0.1,0.1,0.1)
    p.CFrame=CFrame.new(a)
    p.Anchored=true
    p.CanCollide=false
    p.Transparency=1
    p.Name="TracerPart"
    p.Parent=workspace
    local a0=Instance.new("Attachment",p)
    local a1=Instance.new("Attachment",p)
    a1.WorldPosition=b
    local beam=Instance.new("Beam")
    beam.Attachment0=a0
    beam.Attachment1=a1
    beam.Color=ColorSequence.new(c)
    beam.Width0=0.035
    beam.Width1=0.035
    beam.LightEmission=1
    beam.FaceCamera=true
    beam.Transparency=NumberSequence.new(0.1)
    beam.Parent=p
    task.delay(2, function() if p then p:Destroy() end end)
end

local function isInFOV(p)
    local sp,on=Camera:WorldToViewportPoint(p)
    if not on then return false end
    local mp=Vector2.new(Mouse.X,Mouse.Y)
    return (Vector2.new(sp.X,sp.Y)-mp).Magnitude<=getgenv().fov
end

local function passesH(v) return math.random(1,100)<=v end
local function passesHc() return math.random(1,100)<=getgenv().hitchance end

local function getCurrentWeapon()
    local v=workspace:FindFirstChild("vmfolder")
    if v and #v:GetChildren()>0 then return v:GetChildren()[1].Name end
    return "VM_AntiHero_UP2"
end

local function isVisible(p)
    local o=Camera.CFrame.Position
    local d=(p.Position-o)
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Blacklist
    rp.FilterDescendantsInstances={LocalPlayer.Character}
    local r=workspace:Raycast(o,d,rp)
    return not r or r.Instance:IsDescendantOf(p.Parent)
end

local function getWeightedRandomHitbox(c)
    local total=0
    for _,h in ipairs(realHitboxes) do total+=c[h] or 0 end
    if total==0 then return nil end
    local roll=math.random()*total
    local cum=0
    for _,h in ipairs(realHitboxes) do
        cum+=c[h] or 0
        if roll<=cum then return h end
    end
end

local function getValidPart(ch)
    if getgenv().useRandomHitbox then
        for i=1,10 do
            local h=getWeightedRandomHitbox(getgenv().hitboxChances)
            if h then
                local part=ch:FindFirstChild(h)
                if part and isInFOV(part.Position) and passesHc() and isVisible(part) then return part end
            end
        end
        return nil
    else
        local part=ch:FindFirstChild(getgenv().selectedHitbox)
        if part and isInFOV(part.Position) and passesHc() and isVisible(part) then return part end
    end
    return nil
end

local function getClosestVisibleTarget()
    local c=nil
    local sd=math.huge
    local sc=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            if not getgenv().teamCheck or p.Team~=LocalPlayer.Team then
                local part=getValidPart(p.Character)
                if part then
                    local sp=Camera:WorldToViewportPoint(part.Position)
                    local md=(Vector2.new(sp.X,sp.Y)-sc).Magnitude
                    if md<sd then sd=md; c=part end
                end
            end
        end
    end
    return c
end

local function getPredictedPosition(p)
    local v=p.AssemblyLinearVelocity or Vector3.new(0,0,0)
    if getgenv().enablePrediction then
        return p.Position + v*math.clamp(getgenv().predictionAmount,0,1)
    else return p.Position end
end

local notificationQueue={} local maxActive=3 local active=0
local function processQueue()
    if active>=maxActive then return end
    local m=table.remove(notificationQueue,1)
    if m then
        active+=1
        library:SendNotification(m)
        task.delay(3,function() active-=1; processQueue() end)
    end
end
local function queueNotification(m) table.insert(notificationQueue,m); processQueue() end

local weaponDamageMap = {["VM_MachineGun"]=4,["VM_MachineGun_UP1"]=4,["VM_MachineGun_UP2"]=4,["VM_Shotgun"]=2,["VM_Shotgun_UP1"]=2,["VM_Shotgun_UP2"]=2,["VM_CombatRifle_UP2"]=6,["VM_CombatRifle"]=6,["VM_CombatRifle_UP1"]=6,["VM_Ak48_UP2"]=6,["VM_Ak48"]=6,["VM_Ak48_UP1"]=6,["VM_SwatRifle_UP2"]=12,["VM_SwatRifle"]=12,["VM_SwatRifle_UP1"]=12,["VM_SteamPower_UP2"]=29,["VM_SteamPower"]=29,["VM_SteamPower_UP1"]=29,["VM_DualUzi_UP2"]=7,["VM_DualUzi"]=7,["VM_DualUzi_UP1"]=7,["VM_BravePatriot_UP1"]=30,["VM_BravePatriot"]=30,["VM_BravePatriot_UP2"]=30,["VM_Eindringling"]=6,["VM_Eindringling_UP1"]=6,["VM_Eindringling_UP2"]=6,["VM_PhotonShotgun_UP2"]=23,["VM_PhotonShotgun"]=23,["VM_PhotonShotgun_UP1"]=23,["VM_Hellraiser_UP2"]=9,["VM_Hellraiser"]=9,["VM_Hellraiser_UP1"]=9,["VM_CrystalLaserCannon_UP2"]=7,["VM_CrystalLaserCannon"]=7,["VM_CrystalLaserCannon_UP1"]=7,["VM_DesertFighter"]=18,["VM_DesertFighter_UP1"]=18,["VM_DesertFighter_UP2"]=18,["VM_XmasDestroyer_UP1"]=5,["VM_XmasDestroyer"]=5,["VM_XmasDestroyer_UP2"]=5,["VM_PixelGun"]=14,["VM_PixelGun_UP1"]=14,["VM_PixelGun_UP2"]=14,["VM_FastDeath_UP2"]=8,["VM_FastDeath"]=8,["VM_FastDeath_UP1"]=8,["VM_PlasmaPistol_UP2"]=8,["VM_PlasmaPistol_UP1"]=8,["VM_SparklyBlaster"]=8,["VM_SparklyBlaster_UP1"]=8,["VM_SparklyBlaster_UP2"]=8,["VM_DualRevolvers_UP2"]=18,["VM_DualRevolvers"]=18,["VM_DualRevolvers_UP1"]=18,["VM_OldComrade"]=22,["VM_OldComrade_UP1"]=22,["VM_OldComrade_UP2"]=22,["VM_PhotonPistol"]=19,["VM_PhotonPistol_UP1"]=19,["VM_PhotonPistol_UP2"]=19,["VM_HotPlasmaPistol"]=9,["VM_HotPlasmaPistol_UP1"]=9,["VM_HotPlasmaPistol_UP2"]=9,["VM_SteamRevolver_UP2"]=39,["VM_SteamRevolver"]=39,["VM_SteamRevolver_UP1"]=39,["VM_DualMachineGuns_UP2"]=14,["VM_DualMachineGuns"]=14,["VM_DualMachineGuns_UP1"]=14,["VM_Exterminator"]=103,["VM_Exterminator_UP1"]=103,["VM_Exterminator_UP2"]=103,["VM_DualHawks_UP2"]=28,["VM_DualHawks"]=28,["VM_DualHawks_UP1"]=28,["VM_SniperRifle"]=26,["VM_SniperRifle_UP1"]=26,["VM_SniperRifle_UP2"]=26,["VM_HungerBow_UP1"]=30,["VM_HungerBow"]=30,["VM_HungerBow_UP2"]=30,["VM_GuerillaRifle_UP2"]=24,["VM_GuerillaRifle"]=24,["VM_GuerillaRifle_UP1"]=24,["VM_TacticalBow_UP2"]=40,["VM_TacticalBow"]=40,["VM_TacticalBow_UP1"]=40,["VM_BrutalHeadhunter_UP2"]=74,["VM_BrutalHeadhunter"]=74,["VM_BrutalHeadhunter_UP1"]=74,["VM_DaterHater_UP2"]=56,["VM_DaterHater"]=56,["VM_DaterHater_UP1"]=56,["VM_FreezeRayRifle_UP2"]=3,["VM_FreezeRayRifle"]=3,["VM_FreezeRayRifle_UP1"]=3,["VM_ElephantHunter_UP2"]=84,["VM_ElephantHunter"]=84,["VM_ElephantHunter_UP1"]=84,["VM_Prototype_UP2"]=41,["VM_Prototype"]=41,["VM_Prototype_UP1"]=41,["VM_SolarRayRifle_UP2"]=10,["VM_SolarRayRifle"]=10,["VM_SolarRayRifle_UP1"]=10,["VM_AntiHero"]=167,["VM_AntiHero_UP1"]=167,["VM_AntiHero_UP2"]=167}

local function fireMagicBullet(t)
    if not t then return end
    local function doFire(dt)
        local w=getCurrentWeapon()
        local p=getPredictedPosition(t)
        local d=getgenv().infDamage and 9e9 or (weaponDamageMap[w] or 7)
        local dir=(p-Camera.CFrame.Position).Unit
        local args={t,d,w,false,[6]="Awd1jTmMCYdoI5gq5DXNFry,QGpe.q",[7]=dir,[8]=p,[9]=93.03475952148438}
        local pl=Players:GetPlayerFromCharacter(t:FindFirstAncestorOfClass("Model"))
        if pl then queueNotification((dt and "Doubletap hit " or "Hit ")..pl.Name.." in the "..t.Name..(not dt and (" for "..(getgenv().infDamage and "inf" or tostring(d))) or "")) end
        ReplicatedStorage.Signals.damagesignal:FireServer(unpack(args))
        return p
    end
    local mpos=doFire(false)
    if getgenv().bulletTracers then createBeam(Camera.CFrame.Position,mpos,getgenv().BulletTracerColor) end
    if getgenv().doubleTap then
        task.delay(0.05, function()
            if passesH(getgenv().doubleTapHitchance) then
                local spos=doFire(true)
                if getgenv().DoubleTapTracer then createBeam(Camera.CFrame.Position,spos,getgenv().DoubleTapTracerColor)
                elseif getgenv().bulletTracers then createBeam(Camera.CFrame.Position,spos,getgenv().BulletTracerColor) end
            end
        end)
    end
end

task.spawn(function()
    while true do
        task.wait(getgenv().autoShoot and getgenv().autoShootDelay or 0.1)
        if getgenv().autoShoot then
            local tgt=getClosestVisibleTarget()
            if tgt then fireMagicBullet(tgt) end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(getgenv().fireDelay or 0.1)
        if getgenv().killAll then
            for _,p in pairs(getTargetsInRadius()) do fireMagicBullet(p) end
        end
    end
end)

local old
old=hookmetamethod(game,"__namecall",function(self,...)
    local m=getnamecallmethod()
    local a={...}
    if not checkcaller() and m=="FireServer" and tostring(self)=="u_replicateBulletTracer" then
        if typeof(a[1])=="Vector3" and typeof(a[2])=="Vector3" then
            local f=a[1] local tpos=a[2]
            if getgenv().silentAim then
                local tgt=getClosestVisibleTarget()
                if tgt then
                    local pred=getPredictedPosition(tgt)
                    tpos=pred
                    fireMagicBullet(tgt)
                end
            end
            if getgenv().DoubleTapTracer then createBeam(f,tpos,getgenv().DoubleTapTracerColor)
            elseif getgenv().bulletTracers then createBeam(f,tpos,getgenv().BulletTracerColor) end
        end
        return old(self,unpack(a))
    end
    return old(self,...)
end)
