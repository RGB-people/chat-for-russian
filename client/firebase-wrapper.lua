-- 🇷🇺 Firebase Realtime Database Wrapper для Roblox
-- Поддержка чата, антимат, реальное время, автоподгрузка

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FirebaseWrapper = {
    _config = {
        baseUrl = nil,
        messagesPath = "/messages",
        usersPath = "/users",
        statsPath = "/stats",
        apiKey = nil,
        authToken = nil,
        connected = false,
        lastMessageId = nil,
        messageListeners = {},
        userListeners = {},
        cleanupInterval = 300, -- 5 минут
        maxMessages = 1000,
        reconnectAttempts = 3
    },
    
    _cache = {
        messages = {},
        users = {},
        lastSync = 0,
        pendingMessages = {},
        messageQueue = {}
    },
    
    _events = {
        OnMessage = Instance.new("BindableEvent"),
        OnUserJoin = Instance.new("BindableEvent"),
        OnUserLeave = Instance.new("BindableEvent"),
        OnError = Instance.new("BindableEvent"),
        OnConnected = Instance.new("BindableEvent"),
        OnDisconnected = Instance.new("BindableEvent")
    }
}

-- ========== ИНИЦИАЛИЗАЦИЯ ==========

-- Инициализация Firebase
function FirebaseWrapper:Init(config)
    if not config or not config.baseUrl then
        error("❌ Требуется baseUrl Firebase. Пример: https://project-id.firebaseio.com")
    end
    
    -- Настройки
    self._config.baseUrl = config.baseUrl:gsub("/$", "") -- Убираем слеш в конце
    self._config.apiKey = config.apiKey
    self._config.authToken = config.authToken
    self._config.connected = true
    
    -- Тестовое подключение
    local testSuccess = self:_testConnection()
    if not testSuccess then
        warn("⚠️ Не удалось подключиться к Firebase, работаем в оффлайн режиме")
        self._config.connected = false
    else
        print("✅ Firebase подключен:", self._config.baseUrl)
        self._events.OnConnected:Fire()
        
        -- Запускаем синхронизацию
        self:_startSync()
    end
    
    return self
end

-- Тестовое подключение
function FirebaseWrapper:_testConnection()
    local url = self._config.baseUrl .. ".json?shallow=true"
    
    local success, response = pcall(function()
        local result = HttpService:RequestAsync({
            Url = url,
            Method = "GET",
            Headers = self:_getHeaders()
        })
        
        return result.Success and result.StatusCode == 200
    end)
    
    return success
end

-- Получение заголовков
function FirebaseWrapper:_getHeaders()
    local headers = {
        ["Content-Type"] = "application/json"
    }
    
    if self._config.authToken then
        headers["Authorization"] = "Bearer " .. self._config.authToken
    end
    
    return headers
end

-- ========== РАБОТА С СООБЩЕНИЯМИ ==========

-- Отправка сообщения
function FirebaseWrapper:SendMessage(messageData)
    if not messageData or not messageData.text or #messageData.text == 0 then
        return false, "Пустое сообщение"
    end
    
    -- Ограничение длины
    if #messageData.text > 1000 then
        return false, "Сообщение слишком длинное"
    end
    
    -- Подготовка данных
    local player = Players.LocalPlayer
    local data = {
        id = HttpService:GenerateGUID(false),
        senderId = tostring(player.UserId),
        senderName = player.Name,
        text = messageData.text,
        originalText = messageData.originalText or messageData.text,
        timestamp = os.time(),
        gameId = tostring(game.GameId),
        placeId = tostring(game.PlaceId),
        filtered = messageData.filtered or false,
        language = messageData.language or "ru",
        color = messageData.color or "#FFFFFF",
        deleted = false,
        system = messageData.system or false
    }
    
    -- Если не подключены, добавляем в очередь
    if not self._config.connected then
        table.insert(self._cache.pendingMessages, data)
        return true, "Добавлено в очередь"
    end
    
    -- Отправка на сервер
    local url = self._config.baseUrl .. self._config.messagesPath .. "/" .. data.id .. ".json"
    local jsonData = HttpService:JSONEncode(data)
    
    local success, result = pcall(function()
        local response = HttpService:RequestAsync({
            Url = url,
            Method = "PUT",
            Headers = self:_getHeaders(),
            Body = jsonData
        })
        
        return response
    end)
    
    if success and result.Success then
        -- Кэшируем локально
        self:_addToCache(data)
        
        -- Триггерим событие
        self._events.OnMessage:Fire(data)
        
        -- Сохраняем последний ID
        self._config.lastMessageId = data.id
        
        -- Автоочистка старых сообщений
        if #self._cache.messages > self._config.maxMessages then
            self:_cleanupOldMessages()
        end
        
        return true, data.id
    else
        -- Добавляем в очередь на переотправку
        table.insert(self._cache.messageQueue, {
            data = data,
            attempts = 0,
            timestamp = os.time()
        })
        
        return false, result or "Ошибка отправки"
    end
end

-- Получение сообщений
function FirebaseWrapper:GetMessages(options)
    options = options or {}
    local limit = options.limit or 50
    local after = options.after or 0
    local orderBy = options.orderBy or "timestamp"
    
    -- Сначала проверяем кэш
    local cached = self:_getFromCache(limit, after, orderBy)
    if #cached > 0 and not options.forceRefresh then
        return cached
    end
    
    -- Если не подключены, возвращаем кэш
    if not self._config.connected then
        return cached
    end
    
    -- Загружаем с сервера
    local url = self._config.baseUrl .. self._config.messagesPath .. ".json"
    url = url .. "?orderBy=\"" .. orderBy .. "\""
    
    if after > 0 then
        url = url .. "&startAt=" .. tostring(after)
    end
    
    if limit > 0 then
        url = url .. "&limitToLast=" .. tostring(limit)
    end
    
    local success, result = pcall(function()
        local response = HttpService:RequestAsync({
            Url = url,
            Method = "GET",
            Headers = self:_getHeaders()
        })
        
        if response.Success and response.Body and response.Body ~= "null" then
            return HttpService:JSONDecode(response.Body)
        end
        return {}
    end)
    
    if success then
        -- Конвертируем объект в массив и кэшируем
        local messages = self:_processFirebaseData(result)
        self:_updateCache(messages)
        return messages
    end
    
    return cached
end

-- Получение последних N сообщений
function FirebaseWrapper:GetRecentMessages(count)
    return self:GetMessages({limit = count or 20})
end

-- Удаление сообщения
function FirebaseWrapper:DeleteMessage(messageId, isAdmin)
    if not messageId then return false end
    
    -- Проверяем права
    local player = Players.LocalPlayer
    local message = self:GetMessageById(messageId)
    
    if not message then return false end
    
    -- Можно удалять свои сообщения или если админ
    local canDelete = (message.senderId == tostring(player.UserId)) or isAdmin
    
    if not canDelete then
        return false, "Нет прав на удаление"
    end
    
    -- Отправляем запрос на удаление
    local url = self._config.baseUrl .. self._config.messagesPath .. "/" .. messageId .. ".json"
    
    local success, result = pcall(function()
        local response = HttpService:RequestAsync({
            Url = url,
            Method = "PATCH",
            Headers = self:_getHeaders(),
            Body = HttpService:JSONEncode({deleted = true})
        })
        
        return response.Success
    end)
    
    if success then
        -- Обновляем кэш
        self:_markAsDeleted(messageId)
        return true
    end
    
    return false
end

-- Получение сообщения по ID
function FirebaseWrapper:GetMessageById(messageId)
    -- Ищем в кэше
    for _, msg in ipairs(self._cache.messages) do
        if msg.id == messageId then
            return msg
        end
    end
    
    -- Если не в кэше, загружаем с сервера
    if self._config.connected then
        local url = self._config.baseUrl .. self._config.messagesPath .. "/" .. messageId .. ".json"
        
        local success, result = pcall(function()
            local response = HttpService:RequestAsync({
                Url = url,
                Method = "GET",
                Headers = self:_getHeaders()
            })
            
            if response.Success and response.Body and response.Body ~= "null" then
                return HttpService:JSONDecode(response.Body)
            end
        end)
        
        if success then
            return result
        end
    end
    
    return nil
end

-- ========== СИНХРОНИЗАЦИЯ В РЕАЛЬНОМ ВРЕМЕНИ ==========

-- Запуск синхронизации
function FirebaseWrapper:_startSync()
    if not self._config.connected then return end
    
    -- Слушаем новые сообщения
    self:_listenForNewMessages()
    
    -- Обработка очереди
    self:_processQueue()
    
    -- Периодическая синхронизация
    spawn(function()
        while self._config.connected do
            wait(10) -- Синхронизируем каждые 10 секунд
            
            -- Синхронизация сообщений
            self:_syncMessages()
            
            -- Очистка старых сообщений
            if os.time() - self._cache.lastSync > 60 then
                self:_cleanupOldMessages()
                self._cache.lastSync = os.time()
            end
        end
    end)
end

-- Прослушивание новых сообщений
function FirebaseWrapper:_listenForNewMessages()
    spawn(function()
        local lastCheck = 0
        
        while self._config.connected do
            wait(2) -- Проверяем каждые 2 секунды
            
            -- Получаем последние сообщения
            local messages = self:GetMessages({
                limit = 10,
                after = lastCheck,
                forceRefresh = true
            })
            
            -- Обрабатываем новые
            for _, msg in ipairs(messages) do
                if msg.timestamp > lastCheck then
                    -- Игнорируем свои сообщения
                    if msg.senderId ~= tostring(Players.LocalPlayer.UserId) then
                        self._events.OnMessage:Fire(msg)
                    end
                    lastCheck = math.max(lastCheck, msg.timestamp)
                end
            end
        end
    end)
end

-- Синхронизация сообщений
function FirebaseWrapper:_syncMessages()
    if not self._config.connected then return end
    
    -- Синхронизируем последние 100 сообщений
    local serverMessages = self:GetMessages({limit = 100, forceRefresh = true})
    
    -- Обновляем кэш
    self:_updateCache(serverMessages)
end

-- Обработка очереди сообщений
function FirebaseWrapper:_processQueue()
    spawn(function()
        while true do
            wait(5) -- Проверяем очередь каждые 5 секунд
            
            if #self._cache.messageQueue > 0 and self._config.connected then
                local toRemove = {}
                
                for i, item in ipairs(self._cache.messageQueue) do
                    if item.attempts < self._config.reconnectAttempts then
                        local success = self:_retrySendMessage(item.data)
                        if success then
                            table.insert(toRemove, i)
                        else
                            item.attempts = item.attempts + 1
                        end
                    else
                        -- Слишком много попыток, удаляем
                        table.insert(toRemove, i)
                    end
                end
                
                -- Удаляем обработанные
                for i = #toRemove, 1, -1 do
                    table.remove(self._cache.messageQueue, toRemove[i])
                end
            end
        end
    end)
end

-- Повторная отправка сообщения
function FirebaseWrapper:_retrySendMessage(data)
    local url = self._config.baseUrl .. self._config.messagesPath .. "/" .. data.id .. ".json"
    
    local success = pcall(function()
        local response = HttpService:RequestAsync({
            Url = url,
            Method = "PUT",
            Headers = self._config:getHeaders(),
            Body = HttpService:JSONEncode(data)
        })
        
        return response.Success
    end)
    
    return success
end

-- ========== РАБОТА С ПОЛЬЗОВАТЕЛЯМИ ==========

-- Регистрация пользователя в чате
function FirebaseWrapper:RegisterUser()
    local player = Players.LocalPlayer
    
    local userData = {
        id = tostring(player.UserId),
        name = player.Name,
        displayName = player.DisplayName,
        joined = os.time(),
        lastSeen = os.time(),
        messagesCount = 0,
        isOnline = true,
        gameId = tostring(game.GameId)
    }
    
    local url = self._config.baseUrl .. self._config.usersPath .. "/" .. userData.id .. ".json"
    
    local success, result = pcall(function()
        local response = HttpService:RequestAsync({
            Url = url,
            Method = "PUT",
            Headers = self:_getHeaders(),
            Body = HttpService:JSONEncode(userData)
        })
        
        return response.Success
    end)
    
    if success then
        print("👤 Пользователь зарегистрирован:", player.Name)
        return true
    end
    
    return false
end

-- Обновление статуса пользователя
function FirebaseWrapper:UpdateUserStatus(isOnline)
    local player = Players.LocalPlayer
    
    local updateData = {
        lastSeen = os.time(),
        isOnline = isOnline or false
    }
    
    local url = self._config.baseUrl .. self._config.usersPath .. "/" .. player.UserId .. ".json"
    
    pcall(function()
        HttpService:RequestAsync({
            Url = url,
            Method = "PATCH",
            Headers = self:_getHeaders(),
            Body = HttpService:JSONEncode(updateData)
        })
    end)
end

-- Получение списка онлайн пользователей
function FirebaseWrapper:GetOnlineUsers()
    if not self._config.connected then return {} end
    
    local url = self._config.baseUrl .. self._config.usersPath .. ".json"
    url = url .. "?orderBy=\"isOnline\"&equalTo=true"
    
    local success, result = pcall(function()
        local response = HttpService:RequestAsync({
            Url = url,
            Method = "GET",
            Headers = self:_getHeaders()
        })
        
        if response.Success and response.Body and response.Body ~= "null" then
            return HttpService:JSONDecode(response.Body)
        end
        return {}
    end)
    
    if success then
        local users = {}
        for id, data in pairs(result) do
            if data and data.isOnline then
                table.insert(users, {
                    id = id,
                    name = data.name,
                    displayName = data.displayName,
                    lastSeen = data.lastSeen
                })
            end
        end
        return users
    end
    
    return {}
end

-- ========== СТАТИСТИКА ==========

-- Отправка статистики
function FirebaseWrapper:SendStats(stats)
    if not stats then return end
    
    local url = self._config.baseUrl .. self._config.statsPath .. "/" .. os.date("%Y-%m-%d") .. ".json"
    
    pcall(function()
        HttpService:RequestAsync({
            Url = url,
            Method = "PATCH",
            Headers = self:_getHeaders(),
            Body = HttpService:JSONEncode(stats)
        })
    end)
end

-- Получение статистики
function FirebaseWrapper:GetStats(day)
    day = day or os.date("%Y-%m-%d")
    
    local url = self._config.baseUrl .. self._config.statsPath .. "/" .. day .. ".json"
    
    local success, result = pcall(function()
        local response = HttpService:RequestAsync({
            Url = url,
            Method = "GET",
            Headers = self:_getHeaders()
        })
        
        if response.Success and response.Body and response.Body ~= "null" then
            return HttpService:JSONDecode(response.Body)
        end
        return {}
    end)
    
    if success then
        return result
    end
    
    return {}
end

-- ========== КЭШИРОВАНИЕ ==========

-- Добавление в кэш
function FirebaseWrapper:_addToCache(message)
    table.insert(self._cache.messages, message)
    
    -- Сортируем по времени
    table.sort(self._cache.messages, function(a, b)
        return (a.timestamp or 0) < (b.timestamp or 0)
    })
    
    -- Ограничиваем размер кэша
    if #self._cache.messages > self._config.maxMessages then
        table.remove(self._cache.messages, 1)
    end
end

-- Получение из кэша
function FirebaseWrapper:_getFromCache(limit, after, orderBy)
    local filtered = {}
    local count = 0
    
    for i = #self._cache.messages, 1, -1 do
        local msg = self._cache.messages[i]
        
        if not msg.deleted then
            if after > 0 then
                if (msg.timestamp or 0) > after then
                    table.insert(filtered, msg)
                    count = count + 1
                end
            else
                table.insert(filtered, msg)
                count = count + 1
            end
        end
        
        if count >= limit then
            break
        end
    end
    
    -- Реверсируем, чтобы новые были последними
    if orderBy == "timestamp" then
        local reversed = {}
        for i = #filtered, 1, -1 do
            table.insert(reversed, filtered[i])
        end
        return reversed
    end
    
    return filtered
end

-- Обновление кэша
function FirebaseWrapper:_updateCache(messages)
    for _, newMsg in ipairs(messages) do
        local found = false
        
        for i, cachedMsg in ipairs(self._cache.messages) do
            if cachedMsg.id == newMsg.id then
                -- Обновляем существующее
                self._cache.messages[i] = newMsg
                found = true
                break
            end
        end
        
        if not found then
            self:_addToCache(newMsg)
        end
    end
end

-- Отметка как удаленного
function FirebaseWrapper:_markAsDeleted(messageId)
    for i, msg in ipairs(self._cache.messages) do
        if msg.id == messageId then
            self._cache.messages[i].deleted = true
            break
        end
    end
end

-- Очистка старых сообщений
function FirebaseWrapper:_cleanupOldMessages()
    local cutoff = os.time() - self._config.cleanupInterval
    local toRemove = {}
    
    for i, msg in ipairs(self._cache.messages) do
        if (msg.timestamp or 0) < cutoff then
            table.insert(toRemove, i)
        end
    end
    
    for i = #toRemove, 1, -1 do
        table.remove(self._cache.messages, toRemove[i])
    end
    
    if #toRemove > 0 then
        print("🧹 Очищено старых сообщений:", #toRemove)
    end
end

-- Обработка данных Firebase
function FirebaseWrapper:_processFirebaseData(firebaseData)
    if not firebaseData then return {} end
    
    local messages = {}
    
    for id, data in pairs(firebaseData) do
        if data and not data.deleted then
            data.id = id
            table.insert(messages, data)
        end
    end
    
    -- Сортируем по времени
    table.sort(messages, function(a, b)
        return (a.timestamp or 0) < (b.timestamp or 0)
    end)
    
    return messages
end

-- ========== СБОЙЫ И РЕКОНЕКТ ==========

-- Переподключение
function FirebaseWrapper:Reconnect()
    print("🔄 Попытка переподключения...")
    
    local success = self:_testConnection()
    if success then
        self._config.connected = true
        self._events.OnConnected:Fire()
        self:_startSync()
        return true
    end
    
    return false
end

-- Отключение
function FirebaseWrapper:Disconnect()
    self._config.connected = false
    
    -- Обновляем статус пользователя
    self:UpdateUserStatus(false)
    
    self._events.OnDisconnected:Fire()
    print("🔌 Отключено от Firebase")
end

-- ========== УТИЛИТЫ ==========

-- Получение событий
function FirebaseWrapper:GetEvents()
    return self._events
end

-- Проверка подключения
function FirebaseWrapper:IsConnected()
    return self._config.connected
end

-- Получение статистики кэша
function FirebaseWrapper:GetCacheStats()
    return {
        messages = #self._cache.messages,
        pending = #self._cache.pendingMessages,
        queue = #self._cache.messageQueue,
        lastSync = self._cache.lastSync
    }
end

-- Полная очистка кэша
function FirebaseWrapper:ClearCache()
    self._cache = {
        messages = {},
        users = {},
        lastSync = 0,
        pendingMessages = {},
        messageQueue = {}
    }
    
    print("🧹 Кэш очищен")
end

-- Экспорт
return FirebaseWrapper
