-- Плагин автоматического перевода для Chat for Russian
-- Пока заглушка, будет реализован в будущем

local AutoTranslate = {
    name = "Auto Translate",
    version = "0.1.0",
    enabled = false,
    languages = {},
    cache = {}
}

-- Инициализация плагина
function AutoTranslate:Init(chatSystem)
    self.chat = chatSystem
    print("🌍 Плагин перевода загружен")
    
    -- Загружаем языки
    self:LoadLanguages()
    
    return self
end

-- Загрузка языковых данных
function AutoTranslate:LoadLanguages()
    -- Пробуем загрузить из GitHub
    local url = "https://raw.githubusercontent.com/RGB-people/chat-for-russian/main/data/languages.json"
    
    local success, data = pcall(function()
        local content = game:HttpGet(url, true)
        if content then
            return game:GetService("HttpService"):JSONDecode(content)
        end
    end)
    
    if success and data then
        self.languages = data.languages or {}
        print("✅ Языковые данные загружены")
    else
        -- Минимальный набор
        self.languages = {
            ru = {code = "ru", name = "Russian", flag = "🇷🇺"},
            en = {code = "en", name = "English", flag = "🇺🇸"}
        }
        warn("⚠️ Не удалось загрузить языковые данные")
    end
end

-- Определение языка сообщения
function AutoTranslate:DetectLanguage(text)
    if not text or #text < 3 then return "unknown" end
    
    local cyrillicCount = 0
    local latinCount = 0
    
    for i = 1, #text do
        local char = text:sub(i, i)
        if char:match("[а-яА-ЯёЁ]") then
            cyrillicCount = cyrillicCount + 1
        elseif char:match("[a-zA-Z]") then
            latinCount = latinCount + 1
        end
    end
    
    local totalLetters = cyrillicCount + latinCount
    if totalLetters == 0 then return "unknown" end
    
    if cyrillicCount / totalLetters > 0.7 then
        return "ru"
    elseif latinCount / totalLetters > 0.7 then
        return "en"
    else
        return "mixed"
    end
end

-- Простой перевод (заглушка)
function AutoTranslate:Translate(text, targetLang, sourceLang)
    if not self.enabled then return text end
    
    sourceLang = sourceLang or self:DetectLanguage(text)
    
    if sourceLang == targetLang then
        return text -- Не переводим на тот же язык
    end
    
    -- Проверяем кэш
    local cacheKey = text .. "_" .. targetLang .. "_" .. sourceLang
    if self.cache[cacheKey] then
        return self.cache[cacheKey]
    end
    
    -- Простой словарь для часто используемых фраз
    local dictionary = {
        ["привет"] = {
            en = "hello",
            ru = "привет"
        },
        ["пока"] = {
            en = "bye",
            ru = "пока"
        },
        ["спасибо"] = {
            en = "thanks",
            ru = "спасибо"
        },
        ["hello"] = {
            ru = "привет",
            en = "hello"
        },
        ["bye"] = {
            ru = "пока",
            en = "bye"
        },
        ["thanks"] = {
            ru = "спасибо",
            en = "thanks"
        }
    }
    
    local lowerText = text:lower()
    if dictionary[lowerText] and dictionary[lowerText][targetLang] then
        local translated = dictionary[lowerText][targetLang]
        self.cache[cacheKey] = translated
        return translated
    end
    
    -- Если не нашли в словаре, возвращаем оригинал с меткой
    return text .. " [" .. targetLang .. "]"
end

-- Включение/выключение плагина
function AutoTranslate:Toggle()
    self.enabled = not self.enabled
    
    if self.chat then
        self.chat:ShowSystemMessage(
            "Переводчик " .. (self.enabled and "включен" : "выключен"),
            self.enabled and "success" or "info"
        )
    end
    
    return self.enabled
end

-- Получение списка поддерживаемых языков
function AutoTranslate:GetSupportedLanguages()
    local list = {}
    for code, lang in pairs(self.languages) do
        table.insert(list, {
            code = code,
            name = lang.name,
            flag = lang.flag,
            native = lang.native_name
        })
    end
    return list
end

-- Экспорт
return AutoTranslate
