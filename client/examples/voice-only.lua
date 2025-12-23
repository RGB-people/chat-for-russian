-- Только голосовые индикаторы
-- Без чата, только индикаторы кто говорит

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Голосовые индикаторы
local VoiceIndicators = {
    indicators = {},
    isTalking = false,
    gui = nil
}

function VoiceIndicators:Init()
    -- Создаем ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "VoiceIndicators"
    screenGui.ResetOnSpawn = false
    
    self.gui = screenGui
    screenGui.Parent = playerGui
    
    -- Создаем индикаторы для всех игроков
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            self:CreateIndicator(player)
        end
    end
    
    -- Отслеживаем новых игроков
    Players.PlayerAdded:Connect(function(player)
        if player ~= localPlayer then
            self:CreateIndicator(player)
        end
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        if self.indicators[player] then
            self.indicators[player]:Destroy()
            self.indicators[player] = nil
        end
    end)
    
    -- Push-to-Talk
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        
        if input.KeyCode == Enum.KeyCode.V then
            self:SetTalking(true)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, processed)
        if processed then return end
        
        if input.KeyCode == Enum.KeyCode.V then
            self:SetTalking(false)
        end
    end)
    
    print("✅ Голосовые индикаторы инициализированы")
    print("🎤 Нажми V для разговора")
    
    return self
end

function VoiceIndicators:CreateIndicator(player)
    local indicator = Instance.new("Frame")
    indicator.Name = "Voice_" .. player.Name
    indicator.Size = UDim2.new(0, 30, 0, 30)
    indicator.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    indicator.BackgroundTransparency = 0.3
    indicator.Visible = false
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = indicator
    
    local label = Instance.new("TextLabel")
    label.Text = string.sub(player.Name, 1, 3)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.white
    label.Font = Enum.Font.SourceSansBold
    
    label.Parent = indicator
    indicator.Parent = self.gui
    
    self.indicators[player] = indicator
    
    -- Обновляем позицию
    spawn(function()
        while indicator and indicator.Parent do
            if player.Character and player.Character:FindFirstChild("Head") then
                local headPos = player.Character.Head.Position + Vector3.new(0, 2, 0)
                local screenPos, visible = workspace.CurrentCamera:WorldToViewportPoint(headPos)
                
                if visible then
                    indicator.Position = UDim2.new(0, screenPos.X - 15, 0, screenPos.Y - 15)
                    indicator.Visible = true
                else
                    indicator.Visible = false
                end
            else
                indicator.Visible = false
            end
            
            wait(0.1)
        end
    end)
    
    return indicator
end

function VoiceIndicators:SetTalking(talking)
    self.isTalking = talking
    
    -- Обновляем свой индикатор
    if self.indicators[localPlayer] then
        self.indicators[localPlayer].BackgroundColor3 = talking and 
            Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 50, 50)
    end
    
    -- Симуляция других игроков (для теста)
    if talking then
        -- Случайный игрок "отвечает"
        spawn(function()
            wait(0.5)
            local players = Players:GetPlayers()
            if #players > 1 then
                local randomPlayer = players[math.random(2, #players)]
                if self.indicators[randomPlayer] then
                    self.indicators[randomPlayer].BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                    wait(1)
                    self.indicators[randomPlayer].BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                end
            end
        end)
    end
    
    print(talking and "🎤 Говорите..." : "🔇 Молчите")
end

-- Создаем индикатор для себя (скрытый)
VoiceIndicators:CreateIndicator(localPlayer)
VoiceIndicators.indicators[localPlayer].Visible = false

-- Инициализируем
VoiceIndicators:Init()

return VoiceIndicators
