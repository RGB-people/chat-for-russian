-- Firebase Realtime Database Wrapper для Roblox
-- Автор: RGB_people

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Firebase = {
    _url = nil,
    _listeners = {},
    _connected = false,
    _lastMessageId = nil
}

-- Инициализация Firebase
function Firebase:Init(firebaseUrl)
    if not firebaseUrl or type(firebaseUrl) ~= "string" then
        error("❌ Неверный Firebase URL. Пример: https://project-id.firebaseio.com/messages.json")
    end
    
    self._url = firebaseUrl
    self._connected = true
    
    -- Убираем .json если есть (добавим позже)
    self._url = string.gsub(self._url, "%.json$", "")
    
    print("🔥 Firebase инициализирован:", self._url)
    return self
end

-- Отправка сообщения
function Firebase:SendMessage(sender, message, options)
    if not self._connected then
        warn("⚠️ Firebase не инициализирован. Используй :Init() сначала.")
        return false
    end
    
    if #message > 500 then
        warn("⚠️ Сообщение слишком длинное (макс. 500 символов)")
        return false
    end
    
    local messageData = {
        sender = sender,
        message = message,
        timestamp = os.time(),
        playerId = tostring(Players.LocalPlayer.UserId),
        gameId = tostring(game.GameId),
        placeId = tostring(game.PlaceId)
    }
    
    -- Добавляем дополнительные поля если есть
    if options then
        for key, value in pairs(options) do
            messageData[key] = value
        end
    end
    
    -- Генерируем уникальный ID
    local messageId = string.format("%d_%s", os.time(), HttpService:GenerateGUID(false):sub(1, 8))
    messageData.id = messageId
    
    local jsonData = HttpService:JSONEncode(messageData)
    
    -- Используем PATCH для создания с уникальным ID
    local fullUrl = self._url .. "/" .. messageId .. ".json"
    
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = fullUrl,
            Method = "PUT",  -- Используем PUT вместо POST для контроля ID
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = jsonData
        })
    end)
    
    if success then
        self._lastMessageId = messageId
        print("✅ Сообщение отправлено в Firebase")
        return true, messageId
    else
        warn("❌ Ошибка отправки в Firebase:", response)
        return false, response
    end
end

-- Получение всех сообщений
function Firebase:GetMessages(limit)
    if not self._connected then return {} end
    
    local url = self._url .. ".json"
    
    if limit then
        url = url .. "?orderBy=\"timestamp\"&limitToLast=" .. tostring(limit)
    end
    
    local success, response = pcall(function()
        local result = HttpService:GetAsync(url, true)
        if result and result ~= "null" then
            return HttpService:JSONDecode(result)
        end
        return {}
    end)
    
    if success then
        -- Конвертируем объект в массив
        local messagesArray = {}
        if response then
            for id, data in pairs(response) do
                if data then
                    data.id = id
                    table.insert(messagesArray, data)
                end
            end
        end
        
        -- Сортируем по времени
        table.sort(messagesArray, function(a, b)
            return (a.timestamp or 0) < (b.timestamp or 0)
        end)
        
        return messagesArray
    else
        warn("❌ Ошибка получения сообщений:", response)
        return {}
    end
end

-- Удаление сообщения
function Firebase:DeleteMessage(messageId)
    if not self._connected then return false end
    
    local url = self._url .. "/" .. messageId .. ".json"
    
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = url,
            Method = "DELETE"
        })
    end)
    
    return success
end

-- Подписка на новые сообщения (реальное время)
function Firebase:ListenForNewMessages(callback, checkInterval)
    if not self._connected then return end
    
    checkInterval = checkInterval or 2 -- секунды
    
    local lastCheckTime = 0
    
    -- Функция проверки новых сообщений
    local function checkForNewMessages()
        if not self._connected then return end
        
        local currentTime = os.time()
        if currentTime - lastCheckTime < checkInterval then return end
        lastCheckTime = currentTime
        
        -- Получаем последние сообщения
        local messages = self:GetMessages(50)
        
        -- Находим новые
        for _, msg in ipairs(messages) do
            if msg.timestamp and msg.timestamp > (self._lastReceivedTime or 0) then
                if callback then
                    callback(msg)
                end
                self._lastReceivedTime = msg.timestamp
            end
        end
    end
    
    -- Запускаем проверку в фоне
    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        pcall(checkForNewMessages)
    end)
    
    table.insert(self._listeners, connection)
    
    print("👂 Слушаем новые сообщения (интервал: " .. checkInterval .. "с)")
    
    return function()
        -- Функция для отписки
        if connection then
            connection:Disconnect()
        end
    end
end

-- Очистка старых сообщений (старше N секунд)
function Firebase:CleanupOldMessages(maxAge)
    if not self._connected then return 0 end
    
    maxAge = maxAge or 3600 -- 1 час по умолчанию
    
    local messages = self:GetMessages()
    local deletedCount = 0
    local currentTime = os.time()
    
    for _, msg in ipairs(messages) do
        if msg.timestamp and msg.id and (currentTime - msg.timestamp) > maxAge then
            if self:DeleteMessage(msg.id) then
                deletedCount = deletedCount + 1
            end
        end
    end
    
    print("🧹 Удалено старых сообщений: " .. deletedCount)
    return deletedCount
end

-- Отправка сообщения от текущего игрока
function Firebase:SendFromCurrentPlayer(message, options)
    local player = Players.LocalPlayer
    if not player then return false end
    
    return self:SendMessage(player.Name, message, options)
end

-- Получение статистики
function Firebase:GetStats()
    if not self._connected then return {} end
    
    local messages = self:GetMessages()
    local playerCount = {}
    
    for _, msg in ipairs(messages) do
        if msg.sender then
            playerCount[msg.sender] = (playerCount[msg.sender] or 0) + 1
        end
    end
    
    return {
        totalMessages = #messages,
        uniquePlayers = #playerCount,
        mostActivePlayer = self:_getMostActivePlayer(playerCount),
        lastMessageTime = self._lastReceivedTime
    }
end

function Firebase:_getMostActivePlayer(playerCount)
    local topPlayer, maxCount = nil, 0
    for player, count in pairs(playerCount) do
        if count > maxCount then
            topPlayer, maxCount = player, count
        end
    end
    return topPlayer
end

-- Отключение
function Firebase:Disconnect()
    self._connected = false
    
    -- Отключаем все слушатели
    for _, listener in ipairs(self._listeners) do
        pcall(function() listener:Disconnect() end)
    end
    
    self._listeners = {}
    print("🔌 Отключен от Firebase")
end

-- Экспорт
return Firebase
