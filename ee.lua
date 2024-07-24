getgenv().Config = {
    AutoDigsite = {
        Enabled = true,
        ElevationLimit = false, -- Y-level to server hop at, false to disable
        TimeLimit = false, -- Time spent in server before changing servers, false to disable
    },
    Performance = {
        SetFpsCap = 999, -- Set Fps Cap
        Disable3dRendering = false, -- Should SIGNIFICANTLY boost performance, although you cannot see anything with this toggled on 
        SimpleFpsBooster = true -- Turns everything but blocks transparent, unsure if this impacts performance
    }
}

setfpscap(Config.Performance.SetFpsCap)
game:GetService("RunService"):Set3dRenderingEnabled((not Config.Performance.Disable3dRendering))

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ModuleScripts
local Library = ReplicatedStorage.Library
local Directory = ReplicatedStorage.__DIRECTORY
local Network = ReplicatedStorage.Network

local NetworkModule = require(Library.Client.Network)
local TabController = require(game.ReplicatedStorage.Library.Client.TabController)
local GUI = require(ReplicatedStorage.Library.Client.GUI)

local Save = require(Library.Client.Save)
local Signal = require(Library.Signal)
local Variables = require(Library.Variables)

local LocalPlayer = Players.LocalPlayer

-- Util
local MapUtil = require(Library.Util.MapUtil)
local EggsUtil = require(Library.Util.EggsUtil)
local WorldsUtil = require(Library.Util.WorldsUtil)
local ZonesUtil = require(Library.Util.ZonesUtil)

-- Cmds
local ZoneCmds = require(Library.Client.ZoneCmds)
local CurrencyCmds = require(Library.Client.CurrencyCmds)
local MasteryCmds = require(Library.Client.MasteryCmds)
local FlagCmds = require(Library.Client.ZoneFlagCmds)
local PotionCmds = require(Library.Client.PotionCmds)
local PetCmds = require(Library.Client.PetCmds)
local MapCmds = require(Library.Client.MapCmds)
local RankCmds = require(Library.Client.RankCmds)
local NotificationCmds = require(Library.Client.NotificationCmds)
local InstancingCmds = require(game.ReplicatedStorage.Library.Client.InstancingCmds)
local BreakableCmds = require(game.ReplicatedStorage.Library.Client.BreakableCmds)
local RebirthCmds = require(Library.Client.RebirthCmds)
local UltimateCmds = require(Library.Client.UltimateCmds)

-- LocalScripts
local RankUp = game.Players.LocalPlayer.PlayerScripts.Scripts.GUIs["Rank Up"]
local AutoTapper = getsenv(LocalPlayer.PlayerScripts.Scripts.GUIs["Auto Tapper"])
local EggAnim = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])

-- Variables
local gridSize, increment = 8, 3
local brokenChests = 0
local blocks = {}

local function suffix(number)
    local lastDigit = number % 10
    if (number % 100 - lastDigit == 10) then
        return number .. "th"
    end
    return number .. (lastDigit == 1 and "st" or lastDigit == 2 and "nd" or lastDigit == 3 and "rd" or "th")
end

local function serverHop()
    local Api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"

    while task.wait(1) do
        local response = game:HttpGet(Api)
        local data = HttpService:JSONDecode(response)
        if data and data.data then
            local Servers = data.data
            if Servers and #Servers > 0 then
                local Server
                repeat Server = Servers[math.random(1, #Servers)];task.wait() until Server.maxPlayers ~= Server.playing
                TeleportService:TeleportToPlaceInstance(game.PlaceId, Server.id, game.Players.LocalPlayer)
            else
                warn("No servers found.")
            end
        else
            warn("Failed to get server list.")
        end
    end
end

if WorldsUtil.GetWorldNumber() ~= 1 then
    Network["World1Teleport"]:InvokeServer()
end

if not InstancingCmds.IsInInstance() then
    LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.Instances.Digsite.Teleports.Enter.CFrame
    task.wait(7)
end

if Config.Performance.SimpleFpsBooster then
    local blacklist = {
        "Idle Tracking",
        "Mobile",
        "Server Closing",
        "Pending",
        "Inventory",
        "Ultimate",
        "ClientMagicOrbs",
        "Pet",
        "Egg"
    }
    
    for _, v in pairs(game:GetService("Players").LocalPlayer.PlayerScripts.Scripts:GetDescendants()) do
        if v:IsA("Script") and not table.match(blacklist, v.Name) and ((not v.Parent) or v.Parent.Name ~= "Breakables") and ((not v.Parent) or v.Parent.Name ~= "Random Events") and ((not v.Parent) or v.Parent.Name ~= "GUI") then
            v:Destroy()
        end
    end

    local paths = {
        (workspace:FindFirstChild("ALWAYS_RENDERING_"..WorldsUtil.GetWorldNumber()) or workspace.ALWAYS_RENDERING),
        (workspace:FindFirstChild("Border"..WorldsUtil.GetWorldNumber()) or workspace.Border),
        (workspace:FindFirstChild("FlyBorder"..WorldsUtil.GetWorldNumber()) or workspace.FlyBorder),
        --workspace.__DEBRIS
    }

    for _, v in pairs(paths) do
        if v.Parent then
            v:Destroy()
        end
    end

    for _, v in pairs(workspace.__THINGS:GetChildren()) do
        if v.Name ~= "__INSTANCE_CONTAINER" then
            v:Destroy()
        end
    end

    workspace.DescendantAdded:Connect(function(obj)
        if not obj.Parent.Name == "ActiveBlocks" and not obj.Parent.Name == "ActiveChests" then
            pcall(function()
                obj.Transparency = 0
            end)
        end
    end)

    for _, obj in pairs(workspace:GetDescendants()) do
        if not obj.Parent.Name == "ActiveBlocks" and not obj.Parent.Name == "ActiveChests" then
            pcall(function()
                obj.Transparency = 0
            end)
        end
    end

    workspace.__THINGS.__INSTANCE_CONTAINER.Active.Digsite.Important.ActiveBlocks.DescendantAdded:Connect(function(obj)
        repeat task.wait() until obj:GetAttribute("Coord")
        --print("CORD ATTRIBUTE FOUND")
        blocks[obj:GetAttribute("Coord")] = obj
        obj.Transparency = .5
    end)
    
    for _, v in pairs(workspace.__THINGS.__INSTANCE_CONTAINER.Active.Digsite.Important.ActiveBlocks:GetChildren()) do
        blocks[v:GetAttribute("Coord")] = v
        v.Transparency = .5
    end
end

if #workspace.__THINGS.__INSTANCE_CONTAINER.Active.Digsite.Important.ActiveChests:GetChildren() > 0 then
    for _, chest in pairs(workspace.__THINGS.__INSTANCE_CONTAINER.Active.Digsite.Important.ActiveChests:GetChildren()) do
        LocalPlayer.Character.HumanoidRootPart.CFrame = chest.Bottom.CFrame + Vector3.new(0, 5, 0)
        brokenChests += 1
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Breaking "..suffix(brokenChests).." Chest"})
        repeat task.wait(.25);game:GetService("ReplicatedStorage").Network.Instancing_FireCustomFromClient:FireServer("Digsite", "DigChest", chest:GetAttribute("Coord")) until not chest.Parent
    end
end

if Config.AutoDigsite.TimeLimit then
    task.spawn(function()
        task.wait(Config.AutoDigsite.TimeLimit)
        serverHop()
    end)
end

for y = 1, 100, 1 do
    for z = 2, gridSize, increment do
        for x = 2, gridSize, increment do
            --print("BEF_Vector3(" .. x .. ", " .. y .. ", " .. z .. ")")
            if blocks[Vector3.new(x, y, z)] and blocks[Vector3.new(x, y, z)].Parent then
                --print("AFT_Vector3(" .. x .. ", " .. y .. ", " .. z .. ")")
                LocalPlayer.Character.HumanoidRootPart.CFrame = blocks[Vector3.new(x, y, z)].CFrame + Vector3.new(0, 5, 0)
                repeat task.wait(.05);game:GetService("ReplicatedStorage").Network.Instancing_FireCustomFromClient:FireServer("Digsite", "DigBlock", Vector3.new(x, y, z)) until not blocks[Vector3.new(x, y, z)].Parent
                blocks[Vector3.new(x, y, z)] = nil
            end
            if #workspace.__THINGS.__INSTANCE_CONTAINER.Active.Digsite.Important.ActiveChests:GetChildren() > 0 then
                for _, chest in pairs(workspace.__THINGS.__INSTANCE_CONTAINER.Active.Digsite.Important.ActiveChests:GetChildren()) do
                    LocalPlayer.Character.HumanoidRootPart.CFrame = chest.Bottom.CFrame + Vector3.new(0, 5, 0)
                    brokenChests += 1
                    NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Breaking "..suffix(brokenChests).." Chest"})
                    repeat task.wait(.25);game:GetService("ReplicatedStorage").Network.Instancing_FireCustomFromClient:FireServer("Digsite", "DigChest", chest:GetAttribute("Coord")) until not chest.Parent
                end
            end
        end
    end

    for z = 1, gridSize, 1 do
        for x = 1, gridSize, 1 do
            if blocks[Vector3.new(x, y, z)] and blocks[Vector3.new(x, y, z)].Parent then
                blocks[Vector3.new(x, y, z)]:Destroy()
                blocks[Vector3.new(x, y, z)] = nil
            end
        end
    end

    if Config.AutoDigsite.ElevationLimit and y > Config.AutoDigsite.ElevationLimit then
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Changing Server"})
        serverHop()
        break
    end
end

NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Changing Server"})
serverHop()
