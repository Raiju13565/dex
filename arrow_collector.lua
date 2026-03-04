-- AFK Stand Arrow Farm (NO GUI) - Auto-loads after teleport/kick

-- Проверка queue_on_teleport для автозагрузки
local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

print("=== AFK STAND ARROW FARM ===")
print("Starting in 3 seconds...")

-- Переменные
local foundItems = {}
local currentIndex = 1
local collectDelay = 1.5
local lastCollectTime = 0
local isProcessing = false
local consecutiveFailures = 0

-- Защита от кика - автоматический rejoin
local function setupKickProtection()
    local CoreGui = game:GetService("CoreGui")
    
    -- Метод 1: Отслеживание появления окна кика
    CoreGui.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "ErrorPrompt" or descendant.Name == "ErrorTitle" then
            task.wait(0.5)
            pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
        end
    end)
    
    -- Метод 2: Отслеживание потери соединения
    game:GetService("GuiService").ErrorMessageChanged:Connect(function()
        task.wait(0.5)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)
end

-- Функция активации ProximityPrompt
local function activatePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    
    local success = pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            wait(prompt.HoldDuration or 0.5)
            prompt:InputHoldEnd()
        end
    end)
    
    return success
end

-- Функция поиска стрелок
local function findStandArrows()
    foundItems = {}
    print("Searching for Stand Arrows...")
    
    local workspace = game:GetService("Workspace")
    local allObjects = workspace:GetDescendants()
    
    for _, obj in ipairs(allObjects) do
        pcall(function()
            if obj:IsA("Model") and obj.Name == "Model" then
                local standArrow = obj:FindFirstChild("Stand Arrow", true)
                
                if standArrow then
                    local prompt = standArrow:FindFirstChildOfClass("ProximityPrompt", true)
                    
                    if prompt and prompt.Enabled then
                        local position = standArrow:IsA("BasePart") and standArrow.Position or 
                                       (obj.PrimaryPart and obj.PrimaryPart.Position) or
                                       (obj:FindFirstChildOfClass("BasePart") and obj:FindFirstChildOfClass("BasePart").Position)
                        
                        if position then
                            table.insert(foundItems, {
                                model = obj,
                                item = standArrow,
                                prompt = prompt,
                                position = position,
                                holdDuration = prompt.HoldDuration
                            })
                        end
                    end
                end
            end
        end)
    end
    
    print("Found " .. #foundItems .. " Stand Arrows")
    return #foundItems
end

-- Функция телепорта к стрелке
local function teleportToItem(index)
    if not foundItems[index] then return false end
    
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    
    if not hrp then return false end
    
    local itemData = foundItems[index]
    if not itemData.position then return false end
    
    local success = pcall(function()
        hrp.CFrame = CFrame.new(itemData.position + Vector3.new(0, 3, 0))
    end)
    
    return success
end

-- Функция использования стрелки
local function useItem(index)
    if not foundItems[index] then return false end
    
    local itemData = foundItems[index]
    
    if not itemData.prompt or not itemData.prompt.Parent or not itemData.prompt.Enabled then
        return false
    end
    
    local success = activatePrompt(itemData.prompt)
    
    if success then
        print("Collected Stand Arrow #" .. index)
    end
    
    return success
end

-- Основной цикл фарма
RunService.Heartbeat:Connect(function()
    if #foundItems > 0 and not isProcessing then
        local currentTime = tick()
        
        if currentTime - lastCollectTime >= math.max(collectDelay + 3, 4) then
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            
            if character and hrp then
                isProcessing = true
                
                if currentIndex > #foundItems then
                    currentIndex = 1
                end
                
                if #foundItems > 0 and foundItems[currentIndex] then
                    local itemData = foundItems[currentIndex]
                    
                    if itemData.prompt and itemData.prompt.Parent and itemData.prompt.Enabled then
                        if teleportToItem(currentIndex) then
                            task.wait(0.8)
                            
                            local success = useItem(currentIndex)
                            
                            if success then
                                lastCollectTime = currentTime
                                consecutiveFailures = 0
                                task.wait(2)
                                currentIndex = currentIndex + 1
                            else
                                consecutiveFailures = consecutiveFailures + 1
                                currentIndex = currentIndex + 1
                            end
                        else
                            consecutiveFailures = consecutiveFailures + 1
                            currentIndex = currentIndex + 1
                        end
                    else
                        table.remove(foundItems, currentIndex)
                    end
                    
                    if consecutiveFailures >= 3 or #foundItems == 0 then
                        print("Searching for new items...")
                        task.wait(2)
                        findStandArrows()
                        currentIndex = 1
                        consecutiveFailures = 0
                    end
                end
                
                isProcessing = false
            end
        end
    end
end)

-- Автозагрузка скрипта после телепорта/реджойна
local TeleportCheck = false
if queueteleport then
    LocalPlayer.OnTeleport:Connect(function(State)
        if not TeleportCheck then
            TeleportCheck = true
            queueteleport([[
                if not game:IsLoaded() then 
                    game.Loaded:Wait() 
                end
                task.wait(1)
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Raiju13565/dex/refs/heads/main/arrow_collector.lua"))()
            ]])
        end
    end)
end

-- Запуск
setupKickProtection()

task.wait(3)

print("Starting AFK farm...")
findStandArrows()

print("AFK Farm active!")
print("- Auto-collects Stand Arrows")
print("- Auto-rejoins on kick")
print("- Auto-loads after teleport")
print("- Waits peacefully when no arrows found")
