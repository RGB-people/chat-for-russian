-- Конфигурация для Chat for Russian
-- Этот файл загружается автоматически из main.lua

local Config = {
    -- 🔥 Firebase настройки
    Firebase = {
        baseUrl = "https://chat-for-russian-default-rtdb.europe-west1.firebasedatabase.app/",
        
        messagesPath = "/messages",
        usersPath = "/users",
        statsPath = "/stats"
    },
    
    -- 🎮 Интерфейс
    UI = {
        theme = "dark", -- "dark", "light", "blue", "purple"
        position = "bottom-left", -- "bottom-left", "bottom-right", "top-left", "top-right"
        width = 0.35, -- Ширина чата (0.35 = 35% экрана)
        height = 0.4, -- Высота чата (0.4 = 40% экрана)
        backgroundTransparency = 0.15, -- Прозрачность фона
        messageLimit = 100, -- Максимум сообщений в ленте
        showTimestamps = true, -- Показывать время сообщений
        timeFormat = "%H:%M", -- Формат времени (24 часа)
        showAvatars = false, -- Показывать аватары игроков
        animations = true, -- Анимации интерфейса
        font = Enum.Font.SourceSans, -- Шрифт
        fontSize = 14 -- Размер шрифта
    },
    
    -- ⌨️ Управление
    Controls = {
        openChat = Enum.KeyCode.T, -- Открыть чат
        toggleVisibility = Enum.KeyCode.F8, -- Скрыть/показать
        clearChat = Enum.KeyCode.F5, -- Очистить чат
        voiceTalk = Enum.KeyCode.V, -- Говорить
        screenshot = Enum.KeyCode.F12, -- Скриншот
        settings = Enum.KeyCode.F9 -- Настройки
    },
    
    -- 🛡️ Модерация
    Moderation = {
        filterEnabled = true, -- Включить антимат
        filterStrength = "strict", -- "strict", "moderate", "lenient"
        filterLanguages = {"ru", "en", "uk", "be", "kz"}, -- Языки фильтрации
        maxMessageLength = 500, -- Максимальная длина сообщения
        messageCooldown = 1, -- Кулдаун между сообщениями (секунды)
        allowLinks = false, -- Разрешить ссылки
        allowImages = false, -- Разрешить изображения
        reportSystem = false -- Система репортов (в разработке)
    },
    
    -- 🔊 Голосовой чат
    Voice = {
        enabled = true, -- Включить голосовой чат
        pushToTalk = true, -- Push-to-Talk (удерживать клавишу)
        voiceKey = Enum.KeyCode.V, -- Клавиша для голоса
        voiceActivity = false, -- Автоопределение голоса (не работает в Roblox)
        showIndicators = true, -- Показывать индикаторы говорящих
        indicatorSize = 0.02, -- Размер индикатора
        indicatorColor = Color3.fromRGB(0, 255, 0) -- Цвет индикатора
    },
    
    -- 🌍 Переводчик (в разработке)
    Translation = {
        enabled = false, -- Включить автоматический перевод
        autoDetect = true, -- Автоопределение языка
        defaultLanguage = "ru", -- Язык по умолчанию
        showOriginal = false -- Показывать оригинальный текст
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
    
    -- ⚙️ Дополнительные функции
    Features = {
        autoConnect = true, -- Автоподключение к Firebase
        saveHistory = true, -- Сохранять историю чата
        notifications = true, -- Уведомления о новых сообщениях
        soundEffects = false, -- Звуковые эффекты
        typingIndicator = false, -- Индикатор набора текста
        readReceipts = false, -- Галочки прочтения
        offlineMode = true -- Работа без интернета
    },
    
    -- 📦 Производительность
    Performance = {
        cacheMessages = true, -- Кэшировать сообщения
        cleanupInterval = 300, -- Очистка старых сообщений (5 минут)
        maxCachedMessages = 1000, -- Максимум сообщений в кэше
        syncInterval = 10 -- Интервал синхронизации (секунды)
    }
}

-- Функция автонастройки для РФ
local function autoConfigure()
    local success, locale = pcall(function()
        return game:GetService("LocalizationService").RobloxLocaleId
    end)
    
    if success and locale then
        if string.find(locue:lower(), "ru") then
            print("🌍 Обнаружен русский регион")
            Config.Translation.defaultLanguage = "ru"
        elseif string.find(locale:lower(), "en") then
            Config.Translation.defaultLanguage = "en"
        end
    end
end

-- Запускаем автонастройку
pcall(autoConfigure)

-- Экспорт конфигурации
return Config
