-- Chat for Russian - Загрузчик
-- Автоматически определяет executor и загружает скрипт

print("=" . rep(50, "="))
print("🇷🇺 Chat for Russian - Загрузчик")
print("=" . rep(50, "="))

-- Определяем executor
local ExecutorInfo = {
    Name = "Unknown",
    Version = "1.0",
    Features = {}
}

-- Автоопределение executor'а
if identifyexecutor then
    local info = identifyexecutor()
    if type(info) == "string" then
        ExecutorInfo.Name = info
    elseif type(info) == "table" then
        ExecutorInfo.Name = info.Name or "Delta"
        ExecutorInfo.Version = info.Version or "1.0"
    end
    print("✅ Определен executor:", ExecutorInfo.Name)
else
    -- Ручное определение
    if syn and syn.request then
        ExecutorInfo.Name = "Synapse X"
    elseif KRNL_LOADED then
        ExecutorInfo.Name = "Krnl"
    elseif getgenv and getgenv().Delta then
        ExecutorInfo.Name = "Delta"
    elseif fluxus then
        ExecutorInfo.Name = "Fluxus"
    elseif PROTOSMASHER_LOADED then
        ExecutorInfo.Name = "ProtoSmasher"
    end
end

-- URL репозитория (ЗАМЕНИ НА СВОЙ!)
local RepoURL = "https://raw.githubusercontent.com/ВАШ_НИК/chat-for-russian/main"

-- Функция безопасной загрузки
local function LoadModule(path)
    local url = RepoURL .. "/" .. path
    
    print("📥 Загрузка:", path)
    
    local success, content = pcall(function()
        return game:HttpGet(url, true)
    end)
    
    if success and content and #content > 0 then
        return content
    else
        warn("❌ Ошибка загрузки:", path)
        return nil
    end
end

-- Основная функция инициализации
local function InitializeChatSystem()
    print("🚀 Инициализация Chat for Russian...")
    
    -- Загружаем конфигурацию
    local configContent = LoadModule("client/config.lua")
    if configContent then
        local configSuccess, config = pcall(loadstring(configContent))
        if configSuccess and config then
            getgenv().ChatConfig = config
            print("✅ Конфигурация загружена")
        end
    else
        warn("⚠️ Конфигурация не загружена, используем настройки по умолчанию")
    end
    
    -- Загружаем основной скрипт
    local mainContent = LoadModule("client/main.lua")
    if not mainContent then
        error("❌ Не удалось загрузить основной скрипт")
    end
    
    -- Выполняем скрипт
    local success, result = pcall(function()
        return loadstring(mainContent)()
    end)
    
    if success then
        print("✅ Chat for Russian успешно загружен!")
        return result
    else
        error("❌ Ошибка выполнения: " .. tostring(result))
    end
end

-- Альтернатива: простой чат если основной не работает
local function LoadSimpleChat()
    print("🔄 Пробуем загрузить простой чат...")
    
    local simpleCode = [[
        -- Простой чат для теста
        local Players = game:GetService("Players")
        local player = Players.LocalPlayer
        local gui = player:WaitForChild("PlayerGui")
        
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "SimpleChat"
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.3, 0, 0.4, 0)
        frame.Position = UDim2.new(0.02, 0, 0.55, 0)
        frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        
        local label = Instance.new("TextLabel")
        label.Text = "🇷🇺 Chat for Russian\nПростой режим\nНажми T для ввода"
        label.Size = UDim2.new(1, -20, 1, -20)
        label.Position = UDim2.new(0, 10, 0, 10)
        label.TextColor3 = Color3.white
        label.TextWrapped = true
        
        label.Parent = frame
        frame.Parent = screenGui
        screenGui.Parent = gui
        
        print("✅ Простой чат создан")
        return screenGui
    ]]
    
    local success, result = pcall(function()
        return loadstring(simpleCode)()
    end)
    
    return success and result or nil
end

-- Главная функция загрузки
local function Main()
    print("\n" . rep(50, "="))
    print("Executor: " .. ExecutorInfo.Name)
    print("Версия: " .. ExecutorInfo.Version)
    print(rep(50, "="))
    
    -- Проверяем поддержку WebSocket
    local hasWebSocket = pcall(function()
        return WebSocket ~= nil
    end)
    
    if not hasWebSocket and ExecutorInfo.Name ~= "Synapse X" then
        warn("⚠️ WebSocket не поддерживается, некоторые функции ограничены")
    end
    
    -- Пробуем загрузить полную систему
    local chatSystem = InitializeChatSystem()
    
    if not chatSystem then
        warn("❌ Не удалось загрузить полную систему")
        
        -- Пробуем простой чат
        local simpleChat = LoadSimpleChat()
        if simpleChat then
            print("✅ Простой чат активирован")
        else
            error("❌ Не удалось загрузить даже простой чат")
        end
    end
    
    -- Выводим информацию
    print("\n" . rep(50, "="))
    print("🎉 СИСТЕМА ГОТОВА!")
    print(rep(50, "="))
    print("\n📋 Горячие клавиши:")
    print("   T - Открыть чат")
    print("   V - Говорить (удерживать)")
    print("   F8 - Скрыть/показать чат")
    print("   F5 - Очистить чат")
    print("\n💡 Советы:")
    print("   • Замени Firebase URL в конфиге")
    print("   • Используй /help в чате для команд")
    print("   • Настройки в client/config.lua")
    print(rep(50, "="))
    
    return chatSystem
end

-- Запуск
local success, result = pcall(Main)

if success then
    getgenv().ChatLoader = {
        Executor = ExecutorInfo.Name,
        ChatSystem = result,
        LoadTime = os.clock()
    }
    
    -- Команда для перезагрузки
    getgenv().ReloadChat = function()
        print("🔄 Перезагрузка чата...")
        if getgenv().ChatForRussian then
            pcall(function()
                getgenv().ChatForRussian.GUI.Main:Destroy()
            end)
            getgenv().ChatForRussian = nil
        end
        return Main()
    end
else
    warn("\n❌ Критическая ошибка загрузчика:")
    warn(result)
    
    -- Создаем окно с ошибкой
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local gui = player:WaitForChild("PlayerGui")
        
        local errorFrame = Instance.new("Frame")
        errorFrame.Size = UDim2.new(0.4, 0, 0.3, 0)
        errorFrame.Position = UDim2.new(0.3, 0, 0.35, 0)
        errorFrame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        
        local errorText = Instance.new("TextLabel")
        errorText.Text = "❌ Ошибка загрузки Chat for Russian\n\n" .. tostring(result):sub(1, 200)
        errorText.Size = UDim2.new(1, -20, 1, -20)
        errorText.Position = UDim2.new(0, 10, 0, 10)
        errorText.TextColor3 = Color3.white
        errorText.TextWrapped = true
        
        errorText.Parent = errorFrame
        errorFrame.Parent = gui
    end)
end

return getgenv().ChatLoader
