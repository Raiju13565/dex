-- Stand Arrow Auto-Collector + TP Under NPC (CLEAN VERSION)

-- Проверка queue_on_teleport для автозагрузки
local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Raiju13565/WhyO/refs/heads/main/orion.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- Переменные для Stand Arrow
local scriptEnabled = false
local foundItems = {}
local currentIndex = 1
local collectDelay = 1.5
local autoMode = false
local lastCollectTime = 0
local serverHopEnabled = true -- Включено по умолчанию
local autoStartFarm = true -- Автостарт фарма

-- Защита от кика - автоматический rejoin
local function setupKickProtection()
    -- Детект кика через CoreGui
    local CoreGui = game:GetService("CoreGui")
    
    -- Метод 1: Отслеживание появления окна кика
    CoreGui.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "ErrorPrompt" or descendant.Name == "ErrorTitle" then
            task.wait(0.5)
            
            -- Пробуем реджойн
            pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
        end
    end)
    
    -- Метод 2: Отслеживание потери соединения
    game:GetService("GuiService").ErrorMessageChanged:Connect(function()
        task.wait(0.5)
        
        -- Пробуем реджойн
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)
end

-- Запускаем защиту от кика
setupKickProtection()

-- Переменные для TP Under NPC
local tpUnderEnabled = false
local tpUnderDistance = 5
local selectedTarget = nil
local highlightEnabled = true
local highlightColor = Color3.fromRGB(138, 43, 226)
local currentHighlights = {}
local nearbyNPCs = {}
local nearbyPlayers = {}
local tpUnderPlayerName = ""
local scanRange = 100
local savedCFrame = nil
local noclipConnection = nil
local savedCollisionStates = {}

-- Создание окна
local Window = OrionLib:MakeWindow({
    Name = "Stand Arrow Collector",
    HidePremium = true,
    SaveConfig = true,
    ConfigFolder = "StandArrowConfig"
})

local MainTab = Window:MakeTab({
    Name = "Main",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local TeleportTab = Window:MakeTab({
    Name = "TP Under NPC",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- ============================================
-- MAIN TAB: STAND ARROW COLLECTOR
-- ============================================

local ItemCountLabel = MainTab:AddLabel("Found items: 0")
local StatusLabel = MainTab:AddLabel("Status: Ready")

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

local function findStandArrows()
    foundItems = {}
    StatusLabel:Set("Status: Searching...")
    
    local workspace = game:GetService("Workspace")
    local scanned = 0
    local chunkSize = 50
    
    local allObjects = workspace:GetDescendants()
    
    for i = 1, #allObjects, chunkSize do
        for j = i, math.min(i + chunkSize - 1, #allObjects) do
            local obj = allObjects[j]
            
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
                scanned = scanned + 1
            end)
        end
        
        task.wait()
    end
    
    ItemCountLabel:Set("Found items: " .. #foundItems)
    StatusLabel:Set("Status: Found " .. #foundItems .. " items")
    
    return #foundItems
end

local function teleportToItem(index)
    if not foundItems[index] then return false end
    
    local character = LocalPlayer.Character
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local itemData = foundItems[index]
    hrp.CFrame = CFrame.new(itemData.position + Vector3.new(0, 3, 0))
    
    StatusLabel:Set("Status: Teleported to item " .. index .. "/" .. #foundItems)
    return true
end

local function useItem(index)
    if not foundItems[index] then return false end
    
    local itemData = foundItems[index]
    
    if itemData.prompt and itemData.prompt.Parent and itemData.prompt.Enabled then
        StatusLabel:Set("Status: Using item (hold " .. itemData.holdDuration .. "s)...")
        
        task.wait(collectDelay)
        
        if itemData.prompt and itemData.prompt.Parent and itemData.prompt.Enabled then
            if activatePrompt(itemData.prompt) then
                StatusLabel:Set("Status: Item used! Waiting for respawn...")
                return true
            end
        end
    end
    
    StatusLabel:Set("Status: Item no longer available")
    table.remove(foundItems, index)
    ItemCountLabel:Set("Found items: " .. #foundItems)
    
    return false
end

MainTab:AddSlider({
    Name = "Wait Time Before Use",
    Min = 0.5,
    Max = 5,
    Default = 1.5,
    Color = Color3.fromRGB(100, 255, 150),
    Increment = 0.1,
    ValueName = "sec",
    Callback = function(Value)
        collectDelay = Value
    end
})

MainTab:AddButton({
    Name = "Find Stand Arrows",
    Callback = function()
        local count = findStandArrows()
        currentIndex = 1
        OrionLib:MakeNotification({
            Name = "Search Complete",
            Content = "Found " .. count .. " Stand Arrows",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
    end
})

MainTab:AddToggle({
    Name = "Auto Mode (Find & Use)",
    Default = false,
    Callback = function(Value)
        autoMode = Value
        if Value then
            if #foundItems == 0 then
                findStandArrows()
            end
            StatusLabel:Set("Status: Auto mode enabled")
        else
            StatusLabel:Set("Status: Auto mode disabled")
        end
    end
})

MainTab:AddToggle({
    Name = "Server Hop When No Arrows",
    Default = true,
    Save = true,
    Flag = "ServerHop",
    Callback = function(Value)
        serverHopEnabled = Value
        OrionLib:MakeNotification({
            Name = "Server Hop",
            Content = Value and "Enabled - will hop when no arrows" or "Disabled",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

MainTab:AddButton({
    Name = "Server Hop Now",
    Callback = function()
        OrionLib:MakeNotification({
            Name = "Server Hop",
            Content = "Hopping to new server...",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
        
        task.wait(1)
        
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
})

MainTab:AddLabel("Kick protection: Enabled")
MainTab:AddLabel("Auto rejoin on any kick/disconnect")

local isProcessing = false
local consecutiveFailures = 0
local noArrowsCheckCount = 0
local noArrowsStartTime = nil -- Время когда стрелки пропали

RunService.Heartbeat:Connect(function()
    if autoMode and #foundItems > 0 and not isProcessing then
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
                                noArrowsCheckCount = 0
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
                        ItemCountLabel:Set("Found items: " .. #foundItems)
                    end
                    
                    if consecutiveFailures >= 3 or #foundItems == 0 then
                        StatusLabel:Set("Status: Searching for new items...")
                        task.wait(2)
                        findStandArrows()
                        currentIndex = 1
                        consecutiveFailures = 0
                        
                        -- Проверка на отсутствие стрелок
                        if #foundItems == 0 then
                            -- Если стрелки пропали - запускаем таймер
                            if noArrowsStartTime == nil then
                                noArrowsStartTime = tick()
                            end
                            
                            local noArrowsTime = tick() - noArrowsStartTime
                            
                            if noArrowsTime >= 30 and serverHopEnabled then
                                -- 30 секунд без стрелок - хопаем
                                StatusLabel:Set("Status: No arrows for 30s - Server hopping...")
                                
                                OrionLib:MakeNotification({
                                    Name = "Server Hop",
                                    Content = "No arrows for 30 seconds! Hopping to new server...",
                                    Image = "rbxassetid://4483345998",
                                    Time = 5
                                })
                                
                                task.wait(3)
                                
                                TeleportService:Teleport(game.PlaceId, LocalPlayer)
                            end
                        else
                            -- Стрелки нашлись - сбрасываем таймер
                            noArrowsStartTime = nil
                            noArrowsCheckCount = 0
                        end
                    end
                end
                
                isProcessing = false
            end
        end
    end
end)

-- ============================================
-- TP UNDER NPC TAB
-- ============================================

local function clearHighlights()
    for _, highlight in pairs(currentHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    currentHighlights = {}
end

local function highlightTarget(target)
    clearHighlights()
    
    if not highlightEnabled or not target then return end
    
    local character = target:IsA("Model") and target or (target:IsA("Player") and target.Character)
    if not character then return end
    
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            local highlight = Instance.new("Highlight")
            highlight.FillColor = highlightColor
            highlight.OutlineColor = highlightColor
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.Parent = part
            table.insert(currentHighlights, highlight)
        end
    end
end

local function findNearbyNPCs()
    nearbyNPCs = {}
    
    local character = LocalPlayer.Character
    if not character then return {} end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    
    local playerPos = hrp.Position
    
    for _, model in pairs(workspace:GetDescendants()) do
        if model:IsA("Model") and model:FindFirstChild("Humanoid") then
            local isPlayer = false
            for _, player in pairs(Players:GetPlayers()) do
                if player.Character == model then
                    isPlayer = true
                    break
                end
            end
            
            if not isPlayer then
                local npcHRP = model:FindFirstChild("HumanoidRootPart")
                if npcHRP then
                    local distance = (npcHRP.Position - playerPos).Magnitude
                    if distance <= scanRange then
                        table.insert(nearbyNPCs, {
                            name = model.Name,
                            model = model,
                            distance = math.floor(distance)
                        })
                    end
                end
            end
        end
    end
    
    table.sort(nearbyNPCs, function(a, b) return a.distance < b.distance end)
    
    return nearbyNPCs
end

local function findNearbyPlayers()
    nearbyPlayers = {}
    
    local character = LocalPlayer.Character
    if not character then return {} end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    
    local playerPos = hrp.Position
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local playerHRP = player.Character:FindFirstChild("HumanoidRootPart")
            if playerHRP then
                local distance = (playerHRP.Position - playerPos).Magnitude
                if distance <= scanRange then
                    table.insert(nearbyPlayers, {
                        name = player.Name,
                        player = player,
                        distance = math.floor(distance)
                    })
                end
            end
        end
    end
    
    table.sort(nearbyPlayers, function(a, b) return a.distance < b.distance end)
    
    return nearbyPlayers
end

local function enableNoclip()
    local character = LocalPlayer.Character
    if not character then return end
    
    if next(savedCollisionStates) == nil then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                savedCollisionStates[part] = part.CanCollide
            end
        end
    end
    
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    
    if not noclipConnection then
        noclipConnection = RunService.Stepped:Connect(function()
            if tpUnderEnabled then
                local char = LocalPlayer.Character
                if char then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end)
    end
end

local function disableNoclip()
    local character = LocalPlayer.Character
    if not character then return end
    
    for part, originalState in pairs(savedCollisionStates) do
        if part and part.Parent then
            part.CanCollide = originalState
        end
    end
    
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
end

local function teleportUnderTarget(target, savePos)
    local character = LocalPlayer.Character
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    if savePos and not savedCFrame then
        savedCFrame = hrp.CFrame
    end
    
    local targetChar = target:IsA("Model") and target or (target:IsA("Player") and target.Character)
    if not targetChar then return false end
    
    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return false end
    
    -- Позиция под целью
    local targetPos = targetHRP.Position
    local underPos = targetPos - Vector3.new(0, tpUnderDistance, 0)
    
    -- CFrame смотрящий ВВЕРХ на цель
    local lookAtCFrame = CFrame.lookAt(underPos, targetPos)
    
    -- НЕ якорим - просто телепортируем очень часто
    hrp.CFrame = lookAtCFrame
    hrp.Velocity = Vector3.new(0, 0, 0)
    hrp.RotVelocity = Vector3.new(0, 0, 0)
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    
    return true
end

local function returnToSavedPosition()
    local character = LocalPlayer.Character
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    if savedCFrame then
        task.wait(0.1)
        hrp.CFrame = savedCFrame
        savedCFrame = nil
        return true
    end
    
    return false
end

TeleportTab:AddSlider({
    Name = "Distance Under Target",
    Min = 1,
    Max = 20,
    Default = 5,
    Color = Color3.fromRGB(138, 43, 226),
    Increment = 0.5,
    ValueName = "studs",
    Save = true,
    Flag = "TPUnderDistance",
    Callback = function(Value)
        tpUnderDistance = Value
    end
})

TeleportTab:AddSlider({
    Name = "Scan Range",
    Min = 50,
    Max = 500,
    Default = 100,
    Color = Color3.fromRGB(100, 200, 255),
    Increment = 10,
    ValueName = "studs",
    Save = true,
    Flag = "ScanRange",
    Callback = function(Value)
        scanRange = Value
    end
})

local HighlightSection = TeleportTab:AddSection({Name = "Highlight Settings"})

TeleportTab:AddToggle({
    Name = "Enable Highlight",
    Default = true,
    Save = true,
    Flag = "HighlightEnabled",
    Callback = function(Value)
        highlightEnabled = Value
        if not Value then
            clearHighlights()
        elseif selectedTarget then
            highlightTarget(selectedTarget)
        end
    end
})

TeleportTab:AddColorpicker({
    Name = "Highlight Color",
    Default = Color3.fromRGB(138, 43, 226),
    Save = true,
    Flag = "HighlightColor",
    Callback = function(Value)
        highlightColor = Value
        if selectedTarget and highlightEnabled then
            highlightTarget(selectedTarget)
        end
    end
})

local NPCSection = TeleportTab:AddSection({Name = "Closest NPCs"})

local NPCListLabel = TeleportTab:AddLabel("Click 'Scan' to find NPCs")

local npcNames = {}
local NPCDropdown = TeleportTab:AddDropdown({
    Name = "Select NPC",
    Default = "",
    Options = npcNames,
    Callback = function(Value)
        for _, npcData in pairs(nearbyNPCs) do
            if npcData.name .. " (" .. npcData.distance .. "m)" == Value then
                selectedTarget = npcData.model
                highlightTarget(selectedTarget)
                break
            end
        end
    end
})

TeleportTab:AddButton({
    Name = "Scan Nearby NPCs",
    Callback = function()
        findNearbyNPCs()
        
        npcNames = {}
        for _, npcData in pairs(nearbyNPCs) do
            table.insert(npcNames, npcData.name .. " (" .. npcData.distance .. "m)")
        end
        
        NPCDropdown:Refresh(npcNames, true)
        NPCListLabel:Set("Found " .. #nearbyNPCs .. " NPCs nearby")
        
        OrionLib:MakeNotification({
            Name = "Scan Complete",
            Content = "Found " .. #nearbyNPCs .. " NPCs",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

TeleportTab:AddButton({
    Name = "Set Selected NPC as Target",
    Callback = function()
        if not selectedTarget then
            OrionLib:MakeNotification({
                Name = "Error",
                Content = "Select an NPC from dropdown first!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
            return
        end
        
        OrionLib:MakeNotification({
            Name = "Target Set",
            Content = "NPC target ready for Auto Follow",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

local PlayerSection = TeleportTab:AddSection({Name = "Closest Players"})

local PlayerListLabel = TeleportTab:AddLabel("Click 'Scan' to find players")

local playerNames = {}
local PlayerDropdown = TeleportTab:AddDropdown({
    Name = "Select Player",
    Default = "",
    Options = playerNames,
    Callback = function(Value)
        for _, playerData in pairs(nearbyPlayers) do
            if playerData.name .. " (" .. playerData.distance .. "m)" == Value then
                selectedTarget = playerData.player
                highlightTarget(selectedTarget)
                break
            end
        end
    end
})

TeleportTab:AddButton({
    Name = "Scan Nearby Players",
    Callback = function()
        findNearbyPlayers()
        
        playerNames = {}
        for _, playerData in pairs(nearbyPlayers) do
            table.insert(playerNames, playerData.name .. " (" .. playerData.distance .. "m)")
        end
        
        PlayerDropdown:Refresh(playerNames, true)
        PlayerListLabel:Set("Found " .. #nearbyPlayers .. " players nearby")
        
        OrionLib:MakeNotification({
            Name = "Scan Complete",
            Content = "Found " .. #nearbyPlayers .. " players",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

TeleportTab:AddButton({
    Name = "Set Selected Player as Target",
    Callback = function()
        if not selectedTarget then
            OrionLib:MakeNotification({
                Name = "Error",
                Content = "Select a player from dropdown first!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
            return
        end
        
        OrionLib:MakeNotification({
            Name = "Target Set",
            Content = "Player target ready for Auto Follow",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

local ManualSection = TeleportTab:AddSection({Name = "Manual Player Name"})

TeleportTab:AddTextbox({
    Name = "Player Name",
    Default = "",
    TextDisappear = false,
    Callback = function(Value)
        tpUnderPlayerName = Value
    end
})

local FollowSection = TeleportTab:AddSection({Name = "Auto Follow"})

TeleportTab:AddButton({
    Name = "Set Target by Name",
    Callback = function()
        if tpUnderPlayerName == "" then
            OrionLib:MakeNotification({
                Name = "Error",
                Content = "Enter a player name!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
            return
        end
        
        local targetPlayer = Players:FindFirstChild(tpUnderPlayerName)
        if targetPlayer and targetPlayer.Character then
            selectedTarget = targetPlayer
            highlightTarget(selectedTarget)
            
            OrionLib:MakeNotification({
                Name = "Target Set",
                Content = "Target: " .. tpUnderPlayerName,
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        else
            OrionLib:MakeNotification({
                Name = "Error",
                Content = "Player not found!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})

TeleportTab:AddToggle({
    Name = "Auto Follow Target",
    Default = false,
    Save = false,
    Flag = "AutoFollow",
    Callback = function(Value)
        tpUnderEnabled = Value
        
        if Value then
            if not selectedTarget then
                OrionLib:MakeNotification({
                    Name = "Error",
                    Content = "Select a target first!",
                    Image = "rbxassetid://4483345998",
                    Time = 3
                })
                tpUnderEnabled = false
                return
            end
            
            local character = LocalPlayer.Character
            if character then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp and not savedCFrame then
                    savedCFrame = hrp.CFrame
                end
            end
            
            enableNoclip()
            
            OrionLib:MakeNotification({
                Name = "Auto Follow",
                Content = "Following enabled - Noclip ON!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        else
            disableNoclip()
            
            if returnToSavedPosition() then
                OrionLib:MakeNotification({
                    Name = "Auto Follow",
                    Content = "Returned - Noclip OFF",
                    Image = "rbxassetid://4483345998",
                    Time = 2
                })
            else
                OrionLib:MakeNotification({
                    Name = "Auto Follow",
                    Content = "Following disabled - Noclip OFF",
                    Image = "rbxassetid://4483345998",
                    Time = 2
                })
            end
        end
    end
})

TeleportTab:AddButton({
    Name = "Return to Saved Position",
    Callback = function()
        if returnToSavedPosition() then
            OrionLib:MakeNotification({
                Name = "Returned",
                Content = "Returned to saved position",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        else
            OrionLib:MakeNotification({
                Name = "Error",
                Content = "No saved position!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})

TeleportTab:AddButton({
    Name = "Clear Highlight",
    Callback = function()
        clearHighlights()
        selectedTarget = nil
    end
})

TeleportTab:AddButton({
    Name = "Clear Target",
    Callback = function()
        clearHighlights()
        selectedTarget = nil
        tpUnderPlayerName = ""
        
        OrionLib:MakeNotification({
            Name = "Cleared",
            Content = "Target and input cleared",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

TeleportTab:AddButton({
    Name = "Reset Collision Memory",
    Callback = function()
        savedCollisionStates = {}
        OrionLib:MakeNotification({
            Name = "Reset",
            Content = "Collision states cleared",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
})

local lastFollowTime = 0
RunService.Heartbeat:Connect(function()
    if tpUnderEnabled and selectedTarget then
        local currentTime = tick()
        
        -- Проверяем существование цели
        local targetChar = selectedTarget:IsA("Model") and selectedTarget or (selectedTarget:IsA("Player") and selectedTarget.Character)
        
        if targetChar and targetChar.Parent then
            local targetHumanoid = targetChar:FindFirstChild("Humanoid")
            
            -- Проверяем ТОЛЬКО что цель умерла (HP = 0)
            if targetHumanoid and targetHumanoid.Health <= 0 then
                -- Цель умерла - выключаем
                tpUnderEnabled = false
                disableNoclip()
                
                if returnToSavedPosition() then
                    OrionLib:MakeNotification({
                        Name = "Auto Follow",
                        Content = "Target died - Returned to saved position",
                        Image = "rbxassetid://4483345998",
                        Time = 3
                    })
                end
                return
            end
        end
        
        -- Обновляем ОЧЕНЬ ЧАСТО (каждый кадр) для синхронизации с сервером
        if currentTime - lastFollowTime >= 0.01 then
            teleportUnderTarget(selectedTarget, false)
            lastFollowTime = currentTime
        end
    end
end)

OrionLib:Init()

OrionLib:MakeNotification({
    Name = "Loaded!",
    Content = "Stand Arrow Collector ready",
    Image = "rbxassetid://4483345998",
    Time = 5
})

-- Автостарт фарма при загрузке (для autoexec)
if autoStartFarm then
    task.wait(3) -- Ждем 3 секунды после загрузки
    
    -- Автоматически включаем фарм
    autoMode = true
    
    OrionLib:MakeNotification({
        Name = "Auto Start",
        Content = "Auto farm started! Server hop enabled.",
        Image = "rbxassetid://4483345998",
        Time = 5
    })
    
    -- Начинаем поиск
    task.wait(1)
    findStandArrows()
end

-- Автозагрузка скрипта после телепорта/реджойна
local TeleportCheck = false
if queueteleport then
    LocalPlayer.OnTeleport:Connect(function(State)
        if not TeleportCheck then
            TeleportCheck = true
            -- Загружаем скрипт снова после телепорта
            queueteleport([[
                -- Ждем загрузки игры
                if not game:IsLoaded() then 
                    game.Loaded:Wait() 
                end
                task.wait(1)
                
                -- Загружаем скрипт заново
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Raiju13565/dex/refs/heads/main/arrow_collector.lua"))()
            ]])
        end
    end)
end
