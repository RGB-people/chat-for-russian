-- 🇷🇺 Умный антимат фильтр с поддержкой 5 языков
-- Автоматическая загрузка из JSON + морфология + leet-speak детекция

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ProfanityFilter = {
    _badWords = {},
    _replacements = {},
    _loaded = false,
    _patterns = {},
    _characterMap = {},
    
    -- Настройки
    Config = {
        enabled = true,
        replacementChar = "*",
        aggressiveMode = true,  -- Более строгая проверка
        checkPartial = true,    -- Проверка частичных совпадений
        checkLeet = true,       -- Детектирование leet-speak
        languages = {"ru", "en", "uk", "be", "kz"},
        logFiltered = false,
        maxWordLength = 50,
        minWordLength = 2
    }
}

-- ========== ЗАГРУЗКА БАЗ ДАННЫХ ==========

-- Загрузка базы матов из JSON
function ProfanityFilter:LoadBadWords()
    if self._loaded then return true end
    
    print("📦 Загрузка базы матов...")
    
    -- Попробуем загрузить из разных источников
    local urls = {
        "https://raw.githubusercontent.com/ВАШ_НИК/chat-for-russian/main/data/bad-words.json",
        "https://raw.githubusercontent.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/master/ru",
        "https://raw.githubusercontent.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/master/en"
    }
    
    for _, url in ipairs(urls) do
        local success, data = pcall(function()
            local content = game:HttpGet(url, true)
            if content and content ~= "" then
                if url:find("%.json$") then
                    return HttpService:JSONDecode(content)
                else
                    -- Текстовый файл, парсим построчно
                    local words = {}
                    for line in content:gmatch("[^\r\n]+") do
                        if #line > 1 and not line:match("^#") then
                            table.insert(words, line:lower())
                        end
                    end
                    return {ru = {exact = words}}
                end
            end
        end)
        
        if success and data then
            self:_processLoadedData(data)
            print("✅ База матов загружена")
            self._loaded = true
            return true
        end
    end
    
    -- Если не удалось загрузить, используем встроенную базу
    warn("⚠️ Не удалось загрузить базу матов, используем встроенную")
    self:_loadBuiltInDatabase()
    self._loaded = true
    return true
end

-- Загрузка таблицы замен символов
function ProfanityFilter:LoadReplacements()
    local url = "https://raw.githubusercontent.com/ВАШ_НИК/chat-for-russian/main/data/replacements.json"
    
    local success, data = pcall(function()
        local content = game:HttpGet(url, true)
        if content then
            return HttpService:JSONDecode(content)
        end
    end)
    
    if success and data then
        self._replacements = data
        self._characterMap = data.character_map or {}
        print("✅ Таблица замен загружена")
        return true
    end
    
    -- Встроенная таблица замен
    self._characterMap = {
        а = {"a", "@", "а"},
        е = {"e", "ё", "е"},
        о = {"o", "0", "о"},
        с = {"c", "с", "$"},
        у = {"y", "у"},
        х = {"x", "х", "}{"},
        р = {"p", "р"},
        к = {"k", "к"},
        н = {"h", "н"},
        в = {"b", "в"},
        и = {"u", "и", "i"},
        т = {"t", "т"},
        л = {"l", "л", "1"},
        д = {"d", "д"},
        п = {"n", "п"},
        м = {"m", "м"},
        з = {"3", "z", "з"}
    }
    
    return true
end

-- ========== ОБРАБОТКА ДАННЫХ ==========

-- Обработка загруженных данных
function ProfanityFilter:_processLoadedData(data)
    self._badWords = data.languages or {}
    self._patterns = data.patterns or {}
    
    -- Создаем общий список всех слов для быстрого поиска
    self._allWords = {
        exact = {},
        partial = {},
        leet = {}
    }
    
    -- Собираем все слова из всех языков
    for langCode, langData in pairs(self._badWords) do
        -- Точные совпадения
        if langData.exact then
            for _, word in ipairs(langData.exact) do
                table.insert(self._allWords.exact, word:lower())
            end
        end
        
        -- Частичные совпадения
        if langData.partial then
            for _, word in ipairs(langData.partial) do
                table.insert(self._allWords.partial, word:lower())
            end
        end
        
        -- Обходы фильтров
        if langData.bypass_attempts then
            for _, word in ipairs(langData.bypass_attempts) do
                table.insert(self._allWords.leet, word:lower())
            end
        end
    end
    
    -- Создаем регулярные выражения для паттернов
    self:_compilePatterns()
end

-- Компиляция паттернов в эффективные регулярки
function ProfanityFilter:_compilePatterns()
    self._regexPatterns = {}
    
    -- Паттерны leet-speak
    if self._patterns.leet_speak then
        for _, replacements in ipairs(self._patterns.leet_speak) do
            local original = replacements[1]
            if original and #original == 1 then
                local pattern = "[" .. table.concat(replacements, "") .. "]"
                self._regexPatterns[original] = pattern
            end
        end
    end
    
    -- Общие замены
    if self._patterns.common_replacements then
        for original, replacements in pairs(self._patterns.common_replacements) do
            if #original == 1 then
                local pattern = "[" .. table.concat(replacements, "") .. "]"
                self._regexPatterns[original] = pattern
            end
        end
    end
end

-- Встроенная база данных (на случай если JSON не загрузился)
function ProfanityFilter:_loadBuiltInDatabase()
    self._badWords = {
        ru = {
            exact = {
                "хуй", "пизда", "блядь", "ебать", "ебан", "сука", "мудак", 
                "говно", "залупа", "елда", "шлюха", "пидор", "пезда", "манда",
                "гандон", "дрочить", "выебываться", "отсоси", "конча", "хер",
                "пиздец", "бля", "ебло", "ебал", "выеб", "отъеб", "заеб",
                "пидар", "пидорас", "педераст", "гомосек", "педик", "гомик",
                "шалава", "блудница", "проститутка", "шмара", "дешевка",
                "мандавошка", "гнида", "тварь", "ублюдок", "выродок", "падла",
                "сволочь", "мразь", "скотина", "дрянь", "отродье", "недоделок"
            },
            partial = {
                "хуя", "пизд", "бля", "еб", "сук", "муд", "говн", "залуп",
                "елд", "шлюх", "пидр", "пезд", "манд", "гандо", "дроч",
                "выеб", "хер", "пизде", "ебл", "пида", "гомо", "пед",
                "шал", "блуд", "простит", "шмар", "мандав", "гнид", "твар",
                "ублю", "вырод", "падл", "сволоч", "мраз", "скотин", "дрян"
            },
            bypass_attempts = {
                "хуё", "пизде", "блять", "ёбать", "суки", "xyй", "пиzда",
                "бл9дь", "е6ать", "cyka", "хуi", "пiзда", "блять", "ебат",
                "suka", "huy", "pizda", "blyat", "yebat", "хую", "пиздя",
                "бляди", "еби", "суки", "муди", "говни", "залупи", "елди"
            }
        },
        en = {
            exact = {
                "fuck", "shit", "asshole", "bitch", "cunt", "dick", "pussy",
                "cock", "whore", "slut", "bastard", "motherfucker", "damn",
                "hell", "crap", "piss", "dickhead", "twat", "wanker", "tosser",
                "bellend", "knob", "prick", "arse", "arsehole", "bullshit",
                "faggot", "queer", "retard", "nigga", "nigger", "chink",
                "spic", "kike", "gook", "wetback", "cracker", "honky"
            },
            partial = {
                "fck", "sh1t", "b1tch", "c0ck", "d1ck", "puss", "wh0re",
                "slu", "bast", "mofo", "dam", "hel", "cra", "pis", "dickh",
                "twa", "wank", "toss", "bell", "kno", "pri", "ars", "bull",
                "fagg", "que", "reta", "nigg", "chi", "spi", "kik", "goo",
                "wet", "crac", "honk"
            }
        },
        uk = {
            exact = {
                "йобаний", "пиздатий", "хуйовий", "блять", "сука", "мудак",
                "говно", "шльондра", "курва", "паскуда", "холуй", "негідник",
                "підлюка", "сволота", "наволоч", "отморозок", "дегенерат"
            },
            partial = {
                "йоб", "пізд", "хуй", "бл", "сук", "муд", "гов", "шльон",
                "курв", "паск", "хол", "негід", "підлю", "свол", "навол",
                "отмороз", "дегенер"
            }
        },
        be = {
            exact = {
                "хуй", "пізда", "блядь", "ебаць", "сука", "падла", "дурань",
                "дэбіл", "ідыёт", "дурны", "скот", "сволоч", "гад", "паскуда"
            },
            partial = {
                "ху", "пізд", "бл", "еб", "сук", "падл", "дур", "дэб",
                "ід", "ск", "свол", "га", "паск"
            }
        },
        kz = {
            exact = {
                "жынсыз", "сәтсіз", "жем", "жаман", "жарамсыз", "жәбір",
                "жауыз", "жын", "сайқы", "салқын", "сатақы", "сексіз"
            },
            partial = {
                "жын", "сәт", "жем", "жам", "жарам", "жәб", "жау", "сай",
                "сал", "сат", "сек"
            }
        }
    }
    
    self:_processLoadedData({
        languages = self._badWords,
        patterns = {
            leet_speak = {
                {"a", "4", "@", "а"},
                {"e", "3", "е", "ё"},
                {"i", "1", "!", "|", "и", "й"},
                {"o", "0", "о"},
                {"s", "5", "$", "с"},
                {"t", "7", "т"},
                {"z", "2", "з"},
                {"ч", "4"},
                {"ш", "6"}
            }
        }
    })
end

-- ========== МОРФОЛОГИЧЕСКАЯ ОБРАБОТКА ==========

-- Генерация всех возможных форм слова
function ProfanityFilter:_generateWordForms(word)
    local forms = {word}
    
    -- Русские окончания
    local russianEndings = {"", "а", "у", "ом", "е", "ы", "ов", "ам", "ами", "ах"}
    
    -- Английские окончания
    local englishEndings = {"", "s", "ed", "ing", "er", "est"}
    
    -- Украинские окончания  
    local ukrainianEndings = {"", "а", "у", "ом", "і", "и", "ів", "ам", "ами", "ах"}
    
    -- Определяем язык по первой букве
    local firstChar = word:sub(1, 1)
    local endings = {}
    
    if firstChar:match("[а-яё]") then
        endings = russianEndings
    elseif firstChar:match("[a-z]") then
        endings = englishEndings
    elseif firstChar:match("[іїєґ]") then
        endings = ukrainianEndings
    else
        endings = {}
    end
    
    -- Генерируем формы с окончаниями
    for _, ending in ipairs(endings) do
        local form = word .. ending
        if form ~= word then
            table.insert(forms, form)
        end
    end
    
    -- Генерируем формы без окончаний (основы)
    for _, ending in ipairs(endings) do
        if #word > #ending and word:sub(-#ending) == ending then
            local stem = word:sub(1, -#ending - 1)
            table.insert(forms, stem)
        end
    end
    
    return forms
end

-- Генерация leet-speak вариантов
function ProfanityFilter:_generateLeetVariants(word)
    local variants = {word}
    
    -- Простые замены
    local leetMap = {
        a = {"4", "@", "а"},
        e = {"3", "е", "ё"},
        i = {"1", "!", "|", "и"},
        o = {"0", "о"},
        s = {"5", "$", "с"},
        t = {"7", "т"},
        z = {"2", "з"},
        ч = {"4"},
        ш = {"6"},
        б = {"6"},
        в = {"8"},
        г = {"9"},
        д = {"9"},
        ж = {"><"},
        л = {"1"},
        м = {"w"},
        н = {"h"},
        п = {"n"},
        р = {"p"},
        у = {"y"},
        ф = {"f"},
        х = {"x", "}{"},
        ц = {"c"},
        ь = {"b"},
        ю = {"io"},
        я = {"r"}
    }
    
    -- Генерируем варианты для каждой буквы
    local function generateRecursive(current, remaining, results)
        if #remaining == 0 then
            table.insert(results, current)
            return
        end
        
        local char = remaining:sub(1, 1)
        local rest = remaining:sub(2)
        
        -- Оригинальный символ
        generateRecursive(current .. char, rest, results)
        
        -- Leet-замены
        local lowerChar = char:lower()
        if leetMap[lowerChar] then
            for _, replacement in ipairs(leetMap[lowerChar]) do
                generateRecursive(current .. replacement, rest, results)
            end
        end
        
        -- Пропуск символов (для обхода типа "х*й")
        if #current > 0 then
            generateRecursive(current .. self.Config.replacementChar, rest, results)
        end
    end
    
    local results = {}
    generateRecursive("", word:lower(), results)
    
    -- Добавляем уникальные варианты
    for _, variant in ipairs(results) do
        if variant ~= word then
            table.insert(variants, variant)
        end
    end
    
    return variants
end

-- ========== ОСНОВНАЯ ФУНКЦИЯ ФИЛЬТРАЦИИ ==========

-- Основная функция фильтрации
function ProfanityFilter:Filter(text, options)
    if not self._loaded then
        self:LoadBadWords()
        self:LoadReplacements()
    end
    
    if not self.Config.enabled then
        return text
    end
    
    if not text or type(text) ~= "string" or #text == 0 then
        return text
    end
    
    -- Настройки
    options = options or {}
    local replacement = options.replacement or self.Config.replacementChar
    local aggressive = options.aggressive or self.Config.aggressiveMode
    
    -- Разбиваем текст на слова
    local words = self:_splitText(text)
    local filteredWords = {}
    
    for _, originalWord in ipairs(words) do
        local word = originalWord:lower()
        local shouldFilter = false
        
        -- Проверка на точное совпадение
        for _, badWord in ipairs(self._allWords.exact) do
            if word == badWord or self:_isSimilar(word, badWord) then
                shouldFilter = true
                break
            end
        end
        
        -- Проверка на частичное совпадение
        if not shouldFilter and self.Config.checkPartial then
            for _, badWord in ipairs(self._allWords.partial) do
                if word:find(badWord, 1, true) or self:_containsWord(word, badWord) then
                    shouldFilter = true
                    break
                end
            end
        end
        
        -- Проверка leet-speak
        if not shouldFilter and self.Config.checkLeet then
            shouldFilter = self:_checkLeetSpeak(word)
        end
        
        -- Агрессивный режим: проверка всех форм слова
        if not shouldFilter and aggressive then
            shouldFilter = self:_checkAggressive(word)
        end
        
        -- Заменяем если нужно
        if shouldFilter then
            local filtered = self:_replaceWord(originalWord, replacement)
            table.insert(filteredWords, filtered)
            
            if self.Config.logFiltered then
                print("🚫 Отфильтровано:", originalWord, "→", filtered)
            end
        else
            table.insert(filteredWords, originalWord)
        end
    end
    
    -- Собираем текст обратно
    local result = table.concat(filteredWords, " ")
    
    -- Удаляем лишние пробелы
    result = result:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
    
    return result
end

-- Разбиение текста на слова с сохранением знаков препинания
function ProfanityFilter:_splitText(text)
    local words = {}
    local currentWord = ""
    
    for i = 1, #text do
        local char = text:sub(i, i)
        
        if char:match("%w") or char:match("[а-яА-ЯёЁіІїЇєЄґҐ]") then
            currentWord = currentWord .. char
        else
            if #currentWord > 0 then
                table.insert(words, currentWord)
                currentWord = ""
            end
            table.insert(words, char)
        end
    end
    
    if #currentWord > 0 then
        table.insert(words, currentWord)
    end
    
    return words
end

-- Проверка похожести слов (с учетом замен символов)
function ProfanityFilter:_isSimilar(word1, word2)
    if word1 == word2 then return true end
    
    -- Нормализуем слова (убираем повторяющиеся символы)
    local normalized1 = self:_normalizeWord(word1)
    local normalized2 = self:_normalizeWord(word2)
    
    if normalized1 == normalized2 then return true end
    
    -- Проверка расстояния Левенштейна (для опечаток)
    if #word1 <= 10 and #word2 <= 10 then
        local distance = self:_levenshtein(word1, word2)
        if distance <= 2 then  -- Допускаем 2 опечатки
            return true
        end
    end
    
    return false
end

-- Нормализация слова (убираем дубликаты символов)
function ProfanityFilter:_normalizeWord(word)
    local result = ""
    local lastChar = ""
    
    for i = 1, #word do
        local char = word:sub(i, i)
        if char ~= lastChar then
            result = result .. char
            lastChar = char
        end
    end
    
    return result
end

-- Проверка содержания слова внутри другого
function ProfanityFilter:_containsWord(text, word)
    if #word < 3 then return false end
    
    -- Прямое вхождение
    if text:find(word, 1, true) then return true end
    
    -- Вхождение с учетом замен символов
    for i = 1, #text - #word + 1 do
        local substring = text:sub(i, i + #word - 1)
        if self:_isSimilar(substring, word) then
            return true
        end
    end
    
    return false
end

-- Проверка leet-speak
function ProfanityFilter:_checkLeetSpeak(word)
    -- Нормализуем слово (заменяем leet-символы на обычные)
    local normalized = self:_normalizeLeet(word)
    
    -- Проверяем нормализованное слово
    for _, badWord in ipairs(self._allWords.exact) do
        if normalized:find(badWord, 1, true) then
            return true
        end
    end
    
    for _, badWord in ipairs(self._allWords.leet) do
        if word:find(badWord, 1, true) or normalized:find(badWord, 1, true) then
            return true
        end
    end
    
    return false
end

-- Нормализация leet-speak
function ProfanityFilter:_normalizeLeet(word)
    local normalized = word
    
    -- Заменяем leet-символы на обычные
    local replacements = {
        ["4"] = "а", ["@"] = "а",
        ["3"] = "е", ["ё"] = "е",
        ["1"] = "и", ["!"] = "и", ["|"] = "и",
        ["0"] = "о",
        ["5"] = "с", ["$"] = "с",
        ["7"] = "т",
        ["2"] = "з",
        ["6"] = "ш",
        ["8"] = "в",
        ["9"] = "г",
        ["><"] = "ж",
        ["w"] = "ш",
        ["h"] = "н",
        ["n"] = "п",
        ["p"] = "р",
        ["y"] = "у",
        ["f"] = "ф",
        ["x"] = "х", ["}{"] = "х",
        ["c"] = "ц",
        ["b"] = "ь",
        ["io"] = "ю",
        ["r"] = "я"
    }
    
    for leet, normal in pairs(replacements) do
        normalized = normalized:gsub(leet, normal)
    end
    
    return normalized
end

-- Агрессивная проверка (все формы слова)
function ProfanityFilter:_checkAggressive(word)
    -- Генерируем все формы слова
    local forms = self:_generateWordForms(word)
    
    -- Проверяем каждую форму
    for _, form in ipairs(forms) do
        for _, badWord in ipairs(self._allWords.exact) do
            if self:_isSimilar(form, badWord) then
                return true
            end
        end
    end
    
    -- Проверяем leet-варианты
    local leetVariants = self:_generateLeetVariants(word)
    for _, variant in ipairs(leetVariants) do
        for _, badWord in ipairs(self._allWords.exact) do
            if self:_isSimilar(variant, badWord) then
                return true
            end
        end
    end
    
    return false
end

-- Замена слова на цензуру
function ProfanityFilter:_replaceWord(word, replacement)
    if #word <= 2 then
        return string.rep(replacement, #word)
    end
    
    -- Оставляем первую и последнюю букву (если они не плохие)
    local firstChar = word:sub(1, 1)
    local lastChar = word:sub(-1, -1)
    local middle = string.rep(replacement, #word - 2)
    
    return firstChar .. middle .. lastChar
end

-- Расстояние Левенштейна для проверки опечаток
function ProfanityFilter:_levenshtein(str1, str2)
    local len1, len2 = #str1, #str2
    
    if len1 == 0 then return len2 end
    if len2 == 0 then return len1 end
    
    local matrix = {}
    
    for i = 0, len1 do
        matrix[i] = {i}
    end
    
    for j = 0, len2 do
        matrix[0][j] = j
    end
    
    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (str1:sub(i, i) == str2:sub(j, j)) and 0 or 1
            matrix[i][j] = math.min(
                matrix[i-1][j] + 1,     -- удаление
                matrix[i][j-1] + 1,     -- вставка
                matrix[i-1][j-1] + cost -- замена
            )
        end
    end
    
    return matrix[len1][len2]
end

-- ========== УТИЛИТЫ ==========

-- Проверка текста без фильтрации (только проверка)
function ProfanityFilter:Check(text)
    if not self._loaded then
        self:LoadBadWords()
    end
    
    local filtered = self:Filter(text, {replacement = ""})
    return filtered ~= text
end

-- Получение статистики
function ProfanityFilter:GetStats()
    if not self._loaded then return {} end
    
    local totalWords = 0
    for _, words in pairs(self._allWords) do
        totalWords = totalWords + #words
    end
    
    return {
        languages = table.count(self._badWords),
        exactWords = #self._allWords.exact,
        partialWords = #self._allWords.partial,
        leetWords = #self._allWords.leet,
        totalWords = totalWords,
        loaded = self._loaded
    }
end

-- Обновление базы данных
function ProfanityFilter:UpdateDatabase()
    self._loaded = false
    self:LoadBadWords()
    self:LoadReplacements()
    return self._loaded
end

-- Экспорт
return ProfanityFilter
