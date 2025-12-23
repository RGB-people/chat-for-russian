-- Простой чат для быстрого теста
-- Работает без Firebase, только локально

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Простой чат без сервера
local SimpleChat = {
    messages = {},
    gui = nil,
    isVisible = true
}

function SimpleChat:Create()
    -- Удаляем старый GUI
    if self.gui then
        self.gui:Destroy()
    end
    
    -- Создаем интерфейс
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SimpleChat"
    screenGui.ResetOnSpawn = false
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0.3, 0, 0.4, 0)
    mainFrame.Position = UDim2.new(0.02, 0, 0.55, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    mainFrame.BackgroundTransparency = 0.1
    
    -- Заголовок
    local title = Instance.new("TextLabel")
    title.Text = "💬 Простой чат"
    title.Size = UDim2.new(1, 0, 0.1, 0)
    title.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
    title.TextColor3 = Color3.white
    title.Font = Enum.Font.SourceSansBold
    
    -- Лента сообщений
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ChatLog"
    scrollFrame.Size = UDim2.new(1, -10, 0.8, -10)
    scrollFrame.Position = UDim2.new(0, 5, 0.1, 5)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 5
    
    -- Поле ввода
    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(1, -10, 0.1, 0)
    inputBox.Position = UDim2.new(0, 5, 0.9, 0)
    inputBox.PlaceholderText = "Напиши сообщение... (Enter)"
    inputBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    inputBox.TextColor3 = Color3.white
    
    -- Сборка
    title.Parent = mainFrame
    scrollFrame.Parent = mainFrame
    inputBox.Parent = mainFrame
    mainFrame.Parent = screenGui
    screenGui.Parent = playerGui
    
    self.gui = {
        main = screenGui,
        frame = mainFrame,
        scroll = scrollFrame,
        input = inputBox
    }
    
    -- Обработка ввода
    inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed and inputBox.Text ~= "" then
            self:AddMessage(localPlayer.Name, inputBox.Text)
            inputBox.Text = ""
        end
    end)
    
    -- Горячая клавиша T
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.T then
            inputBox:CaptureFocus()
        end
    end)
    
    -- Тестовое сообщение
    self:AddMessage("Система", "Простой чат готов! Пиши сообщения.")
    
    print("✅ Простой чат создан")
    return self
end

function SimpleChat:AddMessage(sender, text)
    if not self.gui or not self.gui.scroll then return end
    
    local scrollFrame = self.gui.scroll
    
    -- Создаем сообщение
    local messageFrame = Instance.new("Frame")
    messageFrame.Size = UDim2.new(1, 0, 0, 0)
    messageFrame.AutomaticSize = Enum.AutomaticSize.Y
    messageFrame.BackgroundTransparency = 1
    
    local senderLabel = Instance.new("TextLabel")
    senderLabel.Text = sender .. ":"
    senderLabel.Size = UDim2.new(1, 0, 0, 20)
    senderLabel.TextColor3 = sender == "Система" and Color3.fromRGB(0, 200, 255) 
                          or sender == localPlayer.Name and Color3.fromRGB(0, 255, 100)
                          or Color3.fromRGB(100, 150, 255)
    senderLabel.Font = Enum.Font.SourceSansBold
    senderLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Text = text
    textLabel.Size = UDim2.new(1, 0, 0, 0)
    textLabel.Position = UDim2.new(0, 0, 0, 20)
    textLabel.AutomaticSize = Enum.AutomaticSize.Y
    textLabel.TextColor3 = Color3.white
    textLabel.TextWrapped = true
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Добавляем
    senderLabel.Parent = messageFrame
    textLabel.Parent = messageFrame
    messageFrame.Parent = scrollFrame
    
    -- Сохраняем
    table.insert(self.messages, {
        sender = sender,
        text = text,
        time = os.time()
    })
    
    -- Автоскролл
    task.wait()
    scrollFrame.CanvasPosition = Vector2.new(0, scrollFrame.AbsoluteCanvasSize.Y)
end

-- Создаем чат
SimpleChat:Create()

print("🎮 Простой чат готов! Нажми T для ввода.")

return SimpleChat
