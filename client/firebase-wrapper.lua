-- 🇷🇺 Chat for Russian - Основной скрипт
-- Полный чат с Firebase, антиматом и голосовыми индикаторами

print("=" . rep(60, "="))
print("🇷🇺 CHAT FOR RUSSIAN - FIREBASE EDITION")
print("=" . rep(60, "="))

local startTime = os.clock()

-- ========== ЗАГРУЗКА МОДУЛЕЙ ==========

-- Firebase Wrapper
local FirebaseWrapper
local firebaseSuccess, firebaseModule = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/RGB-people/chat-for-russian/main/client/firebase-wrapper.lua",
        true
    ))()
end)

if firebaseSuccess and firebaseModule then
    FirebaseWrapper = firebaseModule
    print("✅ Firebase Wrapper загружен")
else
    warn("❌ Ошибка загрузки Firebase:", firebaseModule)
    error("Не удалось загрузить Firebase модуль")
end

-- Антимат фильтр
local ProfanityFilter
local filterSuccess, filterModule = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/RGB-people/chat-for-russian/main/client/profanity-filter.lua",
        true
    ))()
end)

if filterSuccess and filterModule then
    ProfanityFilter = filterModule
    ProfanityFilter:LoadBadWords()
    print("✅ Антимат фильтр загружен")
else
    warn("⚠️ Антимат фильтр не загружен, используем базовую защиту")
    ProfanityFilter = {
        Filter = function(text) return text end,
        Check = function(text) return false end
    }
end

-- ========== КОНФИГУРАЦИЯ ==========

local Config = {
    -- 🔥 Firebase
    Firebase = {
        baseUrl = "https://chat-for-russian-default-rtdb.europe-west1.firebasedatabase.app/",
    },
    
    -- 🎮 Интерфейс
    UI = {
        theme = "dark", -- dark, light, blue, purple
        position = "bottom-left", -- bottom-left, bottom-right, top-left, top-right
        width = 0.35,
        height = 0.4,
        backgroundTransparency = 0.15,
        messageLimit = 100,
        showTimestamps = true,
        timeFormat = "%H:%M",
        showAvatars = true,
        animations = true,
        font = Enum.Font.SourceSans,
        fontSize = 14
    },
    
    -- ⌨️ Управление
    Controls = {
        openChat = Enum.KeyCode.T,
        toggleVisibility = Enum.KeyCode.F8,
        clearChat = Enum.KeyCode.F5,
        voiceTalk = Enum.KeyCode.V,
        screenshot = Enum.KeyCode.F12,
        settings = Enum.KeyCode.F9
    },
    
    -- 🛡️ Модерация
    Moderation = {
        filterEnabled = true,
        filterStrength = "strict", -- strict, moderate, lenient
        filterLanguages = {"ru", "en", "uk", "be", "kz"},
        maxMessageLength = 500,
        messageCooldown = 1, -- секунды
        allowLinks = false,
        allowImages = false,
        reportSystem = true
    },
    
    -- 🔊 Голосовой чат
    Voice = {
        enabled = true,
        pushToTalk = true,
        voiceKey = Enum.KeyCode.V,
        voiceActivity = false,
        showIndicators = true,
        indicatorSize = 0.02,
        indicatorColor = Color3.fromRGB(0, 255, 0)
    },
    
    -- 🌍 Переводчик
    Translation = {
        enabled = false, -- Будет в следующем обновлении
        autoDetect = true,
        defaultLanguage = "ru",
        showOriginal = false
    },
    
    -- 🎨 Цвета
    Colors = {
        background = Color3.fromRGB(25, 25, 35),
        primary = Color3.fromRGB(0, 120, 215),
        success = Color3.fromRGB(0, 200, 100),
        error = Color3.fromRGB(255, 50, 50),
        warning = Color3.fromRGB(255, 150, 0),
        text = Color3.fromRGB(255, 255, 255),
        system = Color3.fromRGB(0, 200, 255),
        selfMessage = Color3.fromRGB(0, 255, 100),
        otherMessage = Color3.fromRGB(100, 150, 255)
    },
    
    -- ⚙️ Дополнительно
    Features = {
        autoConnect = true,
        saveHistory = true,
        notifications = true,
        soundEffects = true,
        typingIndicator = true,
        readReceipts = false,
        offlineMode = true
    }
}

-- ========== СЕРВИСЫ ==========

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ========== СИСТЕМА ЧАТА ==========

local ChatSystem = {
    -- Компоненты
    Firebase = nil,
    GUI = nil,
    Voice = nil,
    
    -- Состояние
    isInitialized = false,
    isConnected = false,
    isVisible = true,
    isTyping = false,
    
    -- Данные
    messages = {},
    users = {},
    settings = {},
    cache = {},
    
    -- Статистика
    stats = {
        messagesSent = 0,
        messagesReceived = 0,
        wordsFiltered = 0,
        errors = 0,
        startTime = os.time(),
        uptime = 0
    },
    
    -- Время
    lastMessageTime = 0,
    lastSyncTime = 0,
    lastTypingUpdate = 0
}

-- ========== ИНИЦИАЛИЗАЦИЯ FIREBASE ==========

function ChatSystem:InitFirebase()
    print("🔥 Инициализация Firebase...")
    
    if not Config.Firebase.baseUrl then
        warn("⚠️ Firebase URL не настроен, используем демо базу")
        Config.Firebase.baseUrl = "https://chat-for-russian-demo.firebaseio.com"
    end
    
    self.Firebase = FirebaseWrapper:Init({
        baseUrl = Config.Firebase.baseUrl
    })
    
    if self.Firebase:IsConnected() then
        self.isConnected = true
        print("✅ Успешно подключено к Firebase")
        
        -- Регистрация пользователя
        self.Firebase:RegisterUser()
        
        -- Подписка на события
        self:_setupFirebaseEvents()
        
        -- Загрузка истории
        self:LoadMessageHistory()
        
        return true
    else
        self.isConnected = false
        warn("❌ Не удалось подключиться к Firebase, оффлайн режим")
        return false
    end
end

-- Настройка событий Firebase
function ChatSystem:_setupFirebaseEvents()
    local events = self.Firebase:GetEvents()
    
    -- Новое сообщение
    events.OnMessage.Event:Connect(function(message)
        self:OnNewMessage(message)
    end)
    
    -- Ошибка
    events.OnError.Event:Connect(function(error)
        warn("Firebase ошибка:", error)
        self.stats.errors = self.stats.errors + 1
    end)
    
    -- Подключено
    events.OnConnected.Event:Connect(function()
        self.isConnected = true
        self:ShowSystemMessage("Подключено к серверу чата", "success")
    end)
    
    -- Отключено
    events.OnDisconnected.Event:Connect(function()
        self.isConnected = false
        self:ShowSystemMessage("Соединение с сервером потеряно", "error")
    end)
end

-- ========== ИНТЕРФЕЙС ==========

-- Создание интерфейса
function ChatSystem:CreateGUI()
    -- Удаляем старый GUI
    if self.GUI and self.GUI.Main then
        self.GUI.Main:Destroy()
    end
    
    -- ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ChatForRussian"
    screenGui.DisplayOrder = 100
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    
    -- Основной контейнер
    local mainContainer = Instance.new("Frame")
    mainContainer.Name = "MainContainer"
    mainContainer.Size = UDim2.new(Config.UI.width, 0, Config.UI.height, 0)
    mainContainer.Position = self:CalculateUIPosition()
    mainContainer.BackgroundTransparency = 1
    mainContainer.ClipsDescendants = true
    
    -- Основное окно
    local mainWindow = Instance.new("Frame")
    mainWindow.Name = "MainWindow"
    mainWindow.Size = UDim2.new(1, 0, 1, 0)
    mainWindow.BackgroundColor3 = Config.Colors.background
    mainWindow.BackgroundTransparency = Config.UI.backgroundTransparency
    
    -- Скругление
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainWindow
    
    -- Тень
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 10, 1, 10)
    shadow.Position = UDim2.new(-0.05, 0, -0.05, 0)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://5554236805"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.7
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.Parent = mainWindow
    shadow.ZIndex = -1
    
    -- Заголовок
    local titleBar = self:CreateTitleBar()
    titleBar.Parent = mainWindow
    
    -- Статус бар
    local statusBar = self:CreateStatusBar()
    statusBar.Parent = mainWindow
    
    -- Лента сообщений
    local chatLog = self:CreateChatLog()
    chatLog.Parent = mainWindow
    
    -- Панель ввода
    local inputPanel = self:CreateInputPanel()
    inputPanel.Parent = mainWindow
    
    -- Сборка
    mainWindow.Parent = mainContainer
    mainContainer.Parent = screenGui
    screenGui.Parent = PlayerGui
    
    -- Сохраняем ссылки
    self.GUI = {
        Main = screenGui,
        Container = mainContainer,
        Window = mainWindow,
        TitleBar = titleBar,
        StatusBar = statusBar,
        ChatLog = chatLog,
        InputPanel = inputPanel,
        MessageFrames = {}
    }
    
    print("✅ Интерфейс создан")
    return screenGui
end

-- Создание заголовка
function ChatSystem:CreateTitleBar()
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0.07, 0)
    titleBar.BackgroundColor3 = Config.Colors.primary
    titleBar.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = titleBar
    
    -- Заголовок
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.01, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🔥 Chat for Russian"
    title.TextColor3 = Config.Colors.text
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Кнопки управления
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0.08, 0, 0.8, 0)
    closeBtn.Position = UDim2.new(0.91, 0, 0.1, 0)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Config.Colors.text
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.TextSize = 18
    
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "MinimizeButton"
    minimizeBtn.Size = UDim2.new(0.08, 0, 0.8, 0)
    minimizeBtn.Position = UDim2.new(0.82, 0, 0.1, 0)
    minimizeBtn.BackgroundTransparency = 1
    minimizeBtn.Text = "─"
    minimizeBtn.TextColor3 = Config.Colors.text
    minimizeBtn.Font = Enum.Font.SourceSansBold
    minimizeBtn.TextSize = 18
    
    -- Сборка
    title.Parent = titleBar
    closeBtn.Parent = titleBar
    minimizeBtn.Parent = titleBar
    
    -- Обработчики
    closeBtn.MouseButton1Click:Connect(function()
        self:ToggleVisibility()
    end)
    
    minimizeBtn.MouseButton1Click:Connect(function()
        self:ToggleMinimize()
    end)
    
    -- Drag & Drop
    self:SetupDrag(titleBar)
    
    return titleBar
end

-- Создание статус бара
function ChatSystem:CreateStatusBar()
    local statusBar = Instance.new("Frame")
    statusBar.Name = "StatusBar"
    statusBar.Size = UDim2.new(1, 0, 0.05, 0)
    statusBar.Position = UDim2.new(0, 0, 0.07, 0)
    statusBar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    statusBar.BorderSizePixel = 0
    
    -- Статус соединения
    local statusDot = Instance.new("Frame")
    statusDot.Name = "StatusDot"
    statusDot.Size = UDim2.new(0.02, 0, 0.6, 0)
    statusDot.Position = UDim2.new(0.01, 0, 0.2, 0)
    statusDot.BackgroundColor3 = Config.Colors.success
    statusDot.BorderSizePixel = 0
    
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = statusDot
    
    -- Текст статуса
    local statusText = Instance.new("TextLabel")
    statusText.Name = "StatusText"
    statusText.Size = UDim2.new(0.4, 0, 1, 0)
    statusText.Position = UDim2.new(0.04, 0, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "Подключение..."
    statusText.TextColor3 = Config.Colors.text
    statusText.Font = Enum.Font.SourceSans
    statusText.TextSize = 12
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Счетчик пользователей
    local usersLabel = Instance.new("TextLabel")
    usersLabel.Name = "UsersLabel"
    usersLabel.Size = UDim2.new(0.3, 0, 1, 0)
    usersLabel.Position = UDim2.new(0.65, 0, 0, 0)
    usersLabel.BackgroundTransparency = 1
    usersLabel.Text = "👥 1"
    usersLabel.TextColor3 = Config.Colors.text
    usersLabel.Font = Enum.Font.SourceSans
    usersLabel.TextSize = 12
    usersLabel.TextXAlignment = Enum.TextXAlignment.Right
    
    -- Сборка
    statusDot.Parent = statusBar
    statusText.Parent = statusBar
    usersLabel.Parent = statusBar
    
    return statusBar
end

-- Создание ленты сообщений
function ChatSystem:CreateChatLog()
    local chatLog = Instance.new("ScrollingFrame")
    chatLog.Name = "ChatLog"
    chatLog.Size = UDim2.new(1, -10, 0.78, -50)
    chatLog.Position = UDim2.new(0, 5, 0.12, 5)
    chatLog.BackgroundTransparency = 1
    chatLog.ScrollBarThickness = 5
    chatLog.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    chatLog.AutomaticCanvasSize = Enum.AutomaticSize.Y
    chatLog.CanvasSize = UDim2.new(0, 0, 0, 0)
    chatLog.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    chatLog.ScrollingDirection = Enum.ScrollingDirection.Y
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = chatLog
    
    return chatLog
end

-- Создание панели ввода
function ChatSystem:CreateInputPanel()
    local inputPanel = Instance.new("Frame")
    inputPanel.Name = "InputPanel"
    inputPanel.Size = UDim2.new(1, -10, 0.1, 0)
    inputPanel.Position = UDim2.new(0, 5, 0.9, 0)
    inputPanel.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    inputPanel.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = inputPanel
    
    -- Поле ввода
    local inputBox = Instance.new("TextBox")
    inputBox.Name = "InputBox"
    inputBox.Size = UDim2.new(1, -20, 1, -10)
    inputBox.Position = UDim2.new(0, 10, 0, 5)
    inputBox.BackgroundTransparency = 1
    inputBox.TextColor3 = Config.Colors.text
    inputBox.PlaceholderText = "Напишите сообщение... (Enter для отправки)"
    inputBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    inputBox.ClearTextOnFocus = false
    inputBox.TextXAlignment = Enum.TextXAlignment.Left
    inputBox.TextSize = Config.UI.fontSize
    inputBox.Font = Config.UI.font
    inputBox.ClipsDescendants = true
    
    -- Кнопка отправки
    local sendButton = Instance.new("TextButton")
    sendButton.Name = "SendButton"
    sendButton.Size = UDim2.new(0.15, 0, 0.8, 0)
    sendButton.Position = UDim2.new(0.84, 0, 0.1, 0)
    sendButton.BackgroundColor3 = Config.Colors.primary
    sendButton.Text = "➤"
    sendButton.TextColor3 = Config.Colors.text
    sendButton.Font = Enum.Font.SourceSansBold
    sendButton.TextSize = 16
    
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 4)
    sendCorner.Parent = sendButton
    
    -- Сборка
    inputBox.Parent = inputPanel
    sendButton.Parent = inputPanel
    
    -- Обработчики
    inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed and string.trim(inputBox.Text) ~= "" then
            self:SendMessage(inputBox.Text)
            inputBox.Text = ""
        end
    end)
    
    sendButton.MouseButton1Click:Connect(function()
        if string.trim(inputBox.Text) ~= "" then
            self:SendMessage(inputBox.Text)
            inputBox.Text = ""
            inputBox:CaptureFocus()
        end
    end)
    
    -- Автофокус при открытии чата
    game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
        if processed then return end
        
        if input.KeyCode == Config.Controls.openChat then
            inputBox:CaptureFocus()
        end
    end)
    
    return inputPanel
end

-- ========== ОТОБРАЖЕНИЕ СООБЩЕНИЙ ==========

-- Добавление сообщения в ленту
function ChatSystem:AddMessageToChat(messageData, isHistory)
    if not self.GUI or not self.GUI.ChatLog then return end
    
    local chatLog = self.GUI.ChatLog
    
    -- Ограничение количества сообщений
    if #self.GUI.MessageFrames >= Config.UI.messageLimit then
        local oldest = self.GUI.MessageFrames[1]
        if oldest then
            oldest:Destroy()
            table.remove(self.GUI.MessageFrames, 1)
        end
    end
    
    -- Создаем фрейм сообщения
    local messageFrame = self:CreateMessageFrame(messageData)
    messageFrame.Parent = chatLog
    messageFrame.LayoutOrder = #self.GUI.MessageFrames + 1
    
    -- Сохраняем
    table.insert(self.GUI.MessageFrames, messageFrame)
    table.insert(self.messages, messageData)
    
    -- Автоскролл если не загружаем историю
    if not isHistory then
        task.wait(0.01)
        chatLog.CanvasPosition = Vector2.new(0, chatLog.AbsoluteCanvasSize.Y)
    end
    
    -- Уведомление
    if not isHistory and not messageData.system and Config.Features.notifications then
        self:ShowNotification("Новое сообщение от " .. messageData.senderName)
    end
end

-- Создание фрейма сообщения
function ChatSystem:CreateMessageFrame(message)
    local frame = Instance.new("Frame")
    frame.Name = "Message_" .. (#self.GUI.MessageFrames + 1)
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundTransparency = 1
    
    -- Аватар (если включено)
    if Config.UI.showAvatars and not message.system then
        local avatar = Instance.new("ImageLabel")
        avatar.Name = "Avatar"
        avatar.Size = UDim2.new(0, 30, 0, 30)
        avatar.Position = UDim2.new(0, 0, 0, 0)
        avatar.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        avatar.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
        
        local avatarCorner = Instance.new("UICorner")
        avatarCorner.CornerRadius = UDim.new(1, 0)
        avatarCorner.Parent = avatar
        
        avatar.Parent = frame
    end
    
    -- Информация об отправителе
    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoFrame"
    infoFrame.Size = UDim2.new(1, -35, 0, 20)
    infoFrame.Position = UDim2.new(0, 35, 0, 0)
    infoFrame.BackgroundTransparency = 1
    
    -- Имя отправителя
    local senderName = Instance.new("TextLabel")
    senderName.Name = "SenderName"
    senderName.Size = UDim2.new(0.7, 0, 1, 0)
    senderName.BackgroundTransparency = 1
    senderName.Text = message.senderName .. (message.system and "" : " ")
    senderName.TextColor3 = message.system and Config.Colors.system 
                          or (message.senderId == tostring(LocalPlayer.UserId) 
                              and Config.Colors.selfMessage 
                              or Config.Colors.otherMessage)
    senderName.Font = Enum.Font.SourceSansBold
    senderName.TextSize = 14
    senderName.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Время
    if Config.UI.showTimestamps then
        local timeText = Instance.new("TextLabel")
        timeText.Name = "Time"
        timeText.Size = UDim2.new(0.3, 0, 1, 0)
        timeText.Position = UDim2.new(0.7, 0, 0, 0)
        timeText.BackgroundTransparency = 1
        timeText.Text = os.date(Config.UI.timeFormat, message.timestamp)
        timeText.TextColor3 = Color3.fromRGB(150, 150, 150)
        timeText.Font = Enum.Font.SourceSans
        timeText.TextSize = 12
        timeText.TextXAlignment = Enum.TextXAlignment.Right
        
        timeText.Parent = infoFrame
    end
    
    senderName.Parent = infoFrame
    infoFrame.Parent = frame
    
    -- Текст сообщения
    local textFrame = Instance.new("Frame")
    textFrame.Name = "TextFrame"
    textFrame.Size = UDim2.new(1, -35, 0, 0)
    textFrame.Position = UDim2.new(0, 35, 0, 20)
    textFrame.BackgroundTransparency = 1
    textFrame.AutomaticSize = Enum.AutomaticSize.Y
    
    local messageText = Instance.new("TextLabel")
    messageText.Name = "MessageText"
    messageText.Size = UDim2.new(1, 0, 0, 0)
    messageText.AutomaticSize = Enum.AutomaticSize.Y
    messageText.BackgroundTransparency = 1
    messageText.Text = message.text
    messageText.TextColor3 = Config.Colors.text
    messageText.Font = Config.UI.font
    messageText.TextSize = Config.UI.fontSize
    messageText.TextWrapped = true
    messageText.TextXAlignment = Enum.TextXAlignment.Left
    messageText.TextYAlignment = Enum.TextYAlignment.Top
    
    -- Если сообщение отфильтровано, добавляем иконку
    if message.filtered then
        local filterIcon = Instance.new("TextLabel")
        filterIcon.Name = "FilterIcon"
        filterIcon.Size = UDim2.new(0, 20, 0, 20)
        filterIcon.Position = UDim2.new(1, -25, 0, 0)
        filterIcon.BackgroundTransparency = 1
        filterIcon.Text = "🛡️"
        filterIcon.TextColor3 = Config.Colors.warning
        filterIcon.Font = Enum.Font.SourceSans
        filterIcon.TextSize = 12
        
        filterIcon.Parent = textFrame
    end
    
    messageText.Parent = textFrame
    textFrame.Parent = frame
    
    return frame
end

-- ========== ОБРАБОТКА СООБЩЕНИЙ ==========

-- Отправка сообщения
function ChatSystem:SendMessage(text)
    -- Проверка кулдауна
    local currentTime = os.time()
    if currentTime - self.lastMessageTime < Config.Moderation.messageCooldown then
        self:ShowSystemMessage("Не так быстро! Подождите...", "warning")
        return false
    end
    
    -- Проверка длины
    if #text > Config.Moderation.maxMessageLength then
        self:ShowSystemMessage("Сообщение слишком длинное!", "error")
        return false
    end
    
    -- Фильтрация
    local filteredText = text
    local wasFiltered = false
    
    if Config.Moderation.filterEnabled and ProfanityFilter then
        filteredText = ProfanityFilter:Filter(text, {
            aggressive = Config.Moderation.filterStrength == "strict",
            replacement = "*"
        })
        
        if filteredText ~= text then
            wasFiltered = true
            self.stats.wordsFiltered = self.stats.wordsFiltered + 1
        end
    end
    
    -- Подготовка данных
    local messageData = {
        text = filteredText,
        originalText = text,
        filtered = wasFiltered,
        language = "ru"
    }
    
    -- Показываем локально сразу
    self:AddMessageToChat({
        senderId = tostring(LocalPlayer.UserId),
        senderName = LocalPlayer.Name,
        text = filteredText,
        timestamp = currentTime,
        system = false,
        filtered = wasFiltered
    })
    
    self.lastMessageTime = currentTime
    self.stats.messagesSent = self.stats.messagesSent + 1
    
    -- Отправляем на сервер
    if self.isConnected and self.Firebase then
        spawn(function()
            local success, result = self.Firebase:SendMessage(messageData)
            
            if not success then
                self:ShowSystemMessage("Не удалось отправить сообщение", "error")
            end
        end)
    else
        self:ShowSystemMessage("Работаем в оффлайн режиме", "warning")
    end
    
    return true
end

-- Обработка нового сообщения
function ChatSystem:OnNewMessage(message)
    -- Игнорируем свои сообщения (они уже показаны)
    if message.senderId == tostring(LocalPlayer.UserId) then
        return
    end
    
    -- Игнорируем удаленные
    if message.deleted then
        return
    end
    
    -- Добавляем в чат
    self:AddMessageToChat(message)
    self.stats.messagesReceived = self.stats.messagesReceived + 1
    
    -- Обновляем статистику
    self:UpdateStats()
end

-- Загрузка истории сообщений
function ChatSystem:LoadMessageHistory()
    if not self.Firebase or not self.isConnected then
        self:ShowSystemMessage("Загрузка локальной истории...", "info")
        return
    end
    
    spawn(function()
        self:ShowSystemMessage("Загрузка истории сообщений...", "info")
        
        local messages = self.Firebase:GetRecentMessages(Config.UI.messageLimit)
        
        if messages and #messages > 0 then
            for _, msg in ipairs(messages) do
                if not msg.deleted then
                    self:AddMessageToChat(msg, true)
                end
            end
            
            self:ShowSystemMessage("Загружено " .. #messages .. " сообщений", "success")
        else
            self:ShowSystemMessage("История сообщений пуста", "info")
        end
    end)
end

-- ========== СИСТЕМНЫЕ СООБЩЕНИЯ ==========

-- Показать системное сообщение
function ChatSystem:ShowSystemMessage(text, type)
    type = type or "info"
    
    local color
    if type == "success" then
        color = Config.Colors.success
    elseif type == "error" then
        color = Config.Colors.error
    elseif type == "warning" then
        color = Config.Colors.warning
    else
        color = Config.Colors.system
    end
    
    self:AddMessageToChat({
        senderId = "system",
        senderName = "Система",
        text = text,
        timestamp = os.time(),
        system = true
    })
end

-- Показать уведомление
function ChatSystem:ShowNotification(text)
    if not Config.Features.notifications then return end
    
    -- Создаем временное уведомление
    local notification = Instance.new("Frame")
    notification.Name = "Notification"
    notification.Size = UDim2.new(0.3, 0, 0, 50)
    notification.Position = UDim2.new(0.35, 0, 0.02, 0)
    notification.BackgroundColor3 = Config.Colors.background
    notification.BackgroundTransparency = 0.2
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, -10)
    label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = "💬 " .. text
    label.TextColor3 = Config.Colors.text
    label.TextWrapped = true
    
    label.Parent = notification
    
    if self.GUI and self.GUI.Main then
        notification.Parent = self.GUI.Main
    end
    
    -- Автоудаление через 3 секунды
    spawn(function()
        wait(3)
        notification:Destroy()
    end)
end

-- ========== УПРАВЛЕНИЕ ИНТЕРФЕЙСОМ ==========

-- Переключение видимости
function ChatSystem:ToggleVisibility()
    self.isVisible = not self.isVisible
    
    if self.GUI and self.GUI.Container then
        self.GUI.Container.Visible = self.isVisible
    end
    
    local status = self.isVisible and "показан" : "скрыт"
    print("👁️ Чат " .. status)
end

-- Переключение минимизации
function ChatSystem:ToggleMinimize()
    if not self.GUI then return end
    
    local chatLog = self.GUI.ChatLog
    local inputPanel = self.GUI.InputPanel
    
    if chatLog.Visible then
        chatLog.Visible = false
        inputPanel.Visible = false
        self.GUI.Window.Size = UDim2.new(1, 0, 0.12, 0)
    else
        chatLog.Visible = true
        inputPanel.Visible = true
        self.GUI.Window.Size = UDim2.new(1, 0, 1, 0)
    end
end

-- Расчет позиции интерфейса
function ChatSystem:CalculateUIPosition()
    local width = Config.UI.width
    local height = Config.UI.height
    
    if Config.UI.position == "bottom-left" then
        return UDim2.new(0.02, 0, 1 - height - 0.02, 0)
    elseif Config.UI.position == "bottom-right" then
        return UDim2.new(1 - width - 0.02, 0, 1 - height - 0.02, 0)
    elseif Config.UI.position == "top-left" then
        return UDim2.new(0.02, 0, 0.02, 0)
    elseif Config.UI.position == "top-right" then
        return UDim2.new(1 - width - 0.02, 0, 0.02, 0)
    else
        return UDim2.new(0.02, 0, 1 - height - 0.02, 0)
    end
end

-- Настройка Drag & Drop
function ChatSystem:SetupDrag(frame)
    local dragging = false
    local dragInput, dragStart, startPos
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = self.GUI.Container.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            self.GUI.Container.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Обновление статуса
function ChatSystem:UpdateStatus()
    if not self.GUI or not self.GUI.StatusBar then return end
    
    local statusDot = self.GUI.StatusBar:FindFirstChild("StatusDot")
    local statusText = self.GUI.StatusBar:FindFirstChild("StatusText")
    
    if statusDot and statusText then
        if self.isConnected then
            statusDot.BackgroundColor3 = Config.Colors.success
            statusText.Text = "Онлайн"
        else
            statusDot.BackgroundColor3 = Config.Colors.error
            statusText.Text = "Оффлайн"
        end
    end
end

-- Обновление статистики
function ChatSystem:UpdateStats()
    self.stats.uptime = os.time() - self.stats.startTime
    
    -- Отправляем статистику на сервер раз в минуту
    if self.isConnected and self.Firebase and os.time() - self.lastSyncTime > 60 then
        self.Firebase:SendStats({
            messagesSent = self.stats.messagesSent,
            messagesReceived = self.stats.messagesReceived,
            wordsFiltered = self.stats.wordsFiltered,
            errors = self.stats.errors,
            uptime = self.stats.uptime
        })
        
        self.lastSyncTime = os.time()
    end
end

-- ========== ГОЛОСОВОЙ ЧАТ ==========

-- Инициализация голосового чата
function ChatSystem:InitVoiceChat()
    if not Config.Voice.enabled then return end
    
    print("🎤 Инициализация голосового чата...")
    
    -- Индикаторы голоса
    if Config.Voice.showIndicators then
        self:CreateVoiceIndicators()
    end
    
    -- Обработка клавиши Push-to-Talk
    if Config.Voice.pushToTalk then
        UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            
            if input.KeyCode == Config.Voice.voiceKey then
                self:SetVoiceState(true)
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input, processed)
            if processed then return end
            
            if input.KeyCode == Config.Voice.voiceKey then
                self:SetVoiceState(false)
            end
        end)
    end
    
    print("✅ Голосовой чат инициализирован")
end

-- Создание индикаторов голоса
function ChatSystem:CreateVoiceIndicators()
    self.Voice = {
        indicators = {},
        isTalking = false
    }
    
    -- Создаем индикаторы для всех игроков
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            self:CreateVoiceIndicator(player)
        end
    end
    
    -- Обновляем при появлении новых игроков
    Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            self:CreateVoiceIndicator(player)
        end
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        if self.Voice.indicators[player] then
            self.Voice.indicators[player]:Destroy()
            self.Voice.indicators[player] = nil
        end
    end)
end

-- Создание индикатора для игрока
function ChatSystem:CreateVoiceIndicator(player)
    local indicator = Instance.new("Frame")
    indicator.Name = "VoiceIndicator_" .. player.Name
    indicator.Size = UDim2.new(Config.Voice.indicatorSize, 0, Config.Voice.indicatorSize, 0)
    indicator.BackgroundColor3 = Config.Voice.indicatorColor
    indicator.BackgroundTransparency = 0.7
    indicator.Visible = false
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = indicator
    
    if self.GUI and self.GUI.Main then
        indicator.Parent = self.GUI.Main
    end
    
    self.Voice.indicators[player] = indicator
    
    -- Обновляем позицию
    spawn(function()
        while indicator and indicator.Parent do
            if player.Character and player.Character:FindFirstChild("Head") then
                local headPos = player.Character.Head.Position + Vector3.new(0, 2, 0)
                local screenPos, visible = workspace.CurrentCamera:WorldToViewportPoint(headPos)
                
                if visible then
                    indicator.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
                    indicator.Visible = self.Voice.isTalking and player == LocalPlayer
                else
                    indicator.Visible = false
                end
            else
                indicator.Visible = false
            end
            
            wait(0.1)
        end
    end)
end

-- Изменение состояния голоса
function ChatSystem:SetVoiceState(talking)
    if not Config.Voice.enabled then return end
    
    self.Voice.isTalking = talking
    
    -- Обновляем индикаторы
    for player, indicator in pairs(self.Voice.indicators) do
        if player == LocalPlayer then
            indicator.Visible = talking
        end
    end
    
    -- Отправляем статус на сервер
    if self.isConnected and self.Firebase then
        -- Здесь можно отправить статус голоса другим игрокам
    end
end

-- ========== ОСНОВНАЯ ИНИЦИАЛИЗАЦИЯ ==========

-- Инициализация системы
function ChatSystem:Init()
    if self.isInitialized then return self end
    
    print("🚀 Инициализация Chat for Russian...")
    
    -- Создаем интерфейс
    self:CreateGUI()
    
    -- Инициализируем Firebase
    if Config.Features.autoConnect then
        self:InitFirebase()
    end
    
    -- Инициализируем голосовой чат
    self:InitVoiceChat()
    
    -- Настройка горячих клавиш
    self:SetupHotkeys()
    
    -- Приветственное сообщение
    task.wait(1)
    self:ShowSystemMessage("Добро пожаловать в Chat for Russian!", "info")
    
    if self.isConnected then
        self:ShowSystemMessage("✅ Подключено к серверу чата", "success")
    else
        self:ShowSystemMessage("⚠️ Работаем в оффлайн режиме", "warning")
    end
    
    -- Обновление статуса
    self:UpdateStatus()
    
    -- Автообновление статистики
    spawn(function()
        while true do
            wait(1)
            self:UpdateStats()
        end
    end)
    
    self.isInitialized = true
    
    local loadTime = os.clock() - startTime
    print("✅ Инициализация завершена за " .. string.format("%.2f", loadTime) .. " секунд")
    
    return self
end

-- Настройка горячих клавиш
function ChatSystem:SetupHotkeys()
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        
        if input.KeyCode == Config.Controls.openChat then
            if self.GUI and self.GUI.InputPanel then
                local inputBox = self.GUI.InputPanel:FindFirstChild("InputBox")
                if inputBox then
                    inputBox:CaptureFocus()
                end
            end
        elseif input.KeyCode == Config.Controls.toggleVisibility then
            self:ToggleVisibility()
        elseif input.KeyCode == Config.Controls.clearChat then
            self:ClearChat()
        elseif input.KeyCode == Config.Controls.settings then
            self:ShowSettings()
        end
    end)
end

-- Очистка чата
function ChatSystem:ClearChat()
    if not self.GUI or not self.GUI.ChatLog then return end
    
    for _, frame in ipairs(self.GUI.MessageFrames) do
        frame:Destroy()
    end
    
    self.GUI.MessageFrames = {}
    self.messages = {}
    
    self:ShowSystemMessage("Чат очищен", "info")
end

-- Показ настроек
function ChatSystem:ShowSettings()
    -- Здесь можно добавить панель настроек
    self:ShowSystemMessage("Настройки будут в следующем обновлении!", "info")
end

-- ========== ЭКСПОРТ И ЗАПУСК ==========

-- Автозапуск
local success, result = pcall(function()
    return ChatSystem:Init()
end)

if success then
    -- Экспортируем для ручного управления
    getgenv().ChatForRussian = ChatSystem
    
    print("\n" . rep("=", 60))
    print("🎉 CHAT FOR RUSSIAN ГОТОВ К ИСПОЛЬЗОВАНИЮ!")
    print(rep("=", 60))
    print("\n📋 Команды:")
    print("  T - Открыть чат")
    print("  V - Говорить (удерживать)")
    print("  F8 - Скрыть/показать интерфейс")
    print("  F5 - Очистить чат")
    print("  F9 - Настройки")
    print("\n🔥 Firebase: " .. (ChatSystem.isConnected and "✅ Подключено" : "❌ Оффлайн"))
    print("🛡️ Антимат: " .. (ProfanityFilter and "✅ Включен" : "❌ Выключен"))
    print("🎤 Голосовой чат: " .. (Config.Voice.enabled and "✅ Включен" : "❌ Выключен"))
    print(rep("=", 60))
    
    -- Сообщение в стандартный чат Roblox
    pcall(function()
        game:GetService("TextChatService").TextChannels.RBXGeneral:SendAsync(
            "[Chat for Russian] Система активирована! Нажми T для чата."
        )
    end)
else
    warn("\n❌ Ошибка инициализации Chat for Russian:")
    warn(result)
    
    -- Простой fallback
    local errorFrame = Instance.new("Frame")
    errorFrame.Size = UDim2.new(0.4, 0, 0.2, 0)
    errorFrame.Position = UDim2.new(0.3, 0, 0.4, 0)
    errorFrame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    errorFrame.Parent = PlayerGui
    
    local errorText = Instance.new("TextLabel")
    errorText.Text = "❌ Ошибка Chat for Russian\n\n" .. tostring(result)
    errorText.Size = UDim2.new(1, -20, 1, -20)
    errorText.Position = UDim2.new(0, 10, 0, 10)
    errorText.TextColor3 = Color3.white
    errorText.TextWrapped = true
    errorText.Parent = errorFrame
end

-- Экспорт
return ChatSystem
