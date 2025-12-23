-- Плагин мини-игр для чата
-- Пока заглушка

local ChatGames = {
    name = "Chat Games",
    version = "0.1.0",
    enabled = false,
    games = {},
    activeGame = nil
}

-- Инициализация
function ChatGames:Init(chatSystem)
    self.chat = chatSystem
    print("🎮 Плагин игр загружен")
    
    -- Регистрируем игры
    self:RegisterGames()
    
    return self
end

-- Регистрация игр
function ChatGames:RegisterGames()
    self.games = {
        {
            name = "Угадай число",
            command = "/guess",
            description = "Угадай число от 1 до 100",
            minPlayers = 1,
            handler = function(args)
                return self:NumberGuessGame(args)
            end
        },
        {
            name = "Викторина",
            command = "/quiz",
            description = "Ответь на вопрос",
            minPlayers = 1,
            handler = function(args)
                return self:QuizGame(args)
            end
        },
        {
            name = "Крестики-нолики",
            command = "/tictactoe",
            description = "Сыграй в крестики-нолики",
            minPlayers = 2,
            handler = function(args)
                return self:TicTacToeGame(args)
            end
        }
    }
end

-- Игра "Угадай число"
function ChatGames:NumberGuessGame(args)
    if not self.activeGame then
        local number = math.random(1, 100)
        self.activeGame = {
            type = "guess",
            target = number,
            attempts = 0,
            maxAttempts = 10,
            players = {}
        }
        
        return "🎮 Игра 'Угадай число' началась! Угадай число от 1 до 100. У тебя 10 попыток."
    else
        local guess = tonumber(args[1])
        if not guess then
            return "❌ Введи число!"
        end
        
        self.activeGame.attempts = self.activeGame.attempts + 1
        
        if guess == self.activeGame.target then
            local attempts = self.activeGame.attempts
            self.activeGame = nil
            return "🎉 Поздравляю! Ты угадал число за " .. attempts .. " попыток!"
        elseif guess < self.activeGame.target then
            return "📈 Больше! Попыток осталось: " .. (self.activeGame.maxAttempts - self.activeGame.attempts)
        else
            return "📉 Меньше! Попыток осталось: " .. (self.activeGame.maxAttempts - self.activeGame.attempts)
        end
    end
end

-- Игра "Викторина"
function ChatGames:QuizGame(args)
    local questions = {
        {
            question = "Столица России?",
            answer = "москва",
            options = {"Москва", "Санкт-Петербург", "Казань"}
        },
        {
            question = "2 + 2 = ?",
            answer = "4",
            options = {"3", "4", "5"}
        },
        {
            question = "Какой язык программирования используется в Roblox?",
            answer = "lua",
            options = {"Lua", "Python", "JavaScript"}
        }
    }
    
    if not self.activeGame then
        local randomQuestion = questions[math.random(1, #questions)]
        self.activeGame = {
            type = "quiz",
            question = randomQuestion.question,
            answer = randomQuestion.answer,
            options = randomQuestion.options
        }
        
        local optionsText = ""
        for i, opt in ipairs(randomQuestion.options) do
            optionsText = optionsText .. i .. ") " .. opt .. " "
        end
        
        return "🧠 Вопрос: " .. randomQuestion.question .. "\nВарианты: " .. optionsText
    else
        local answer = table.concat(args, " "):lower()
        
        if answer == self.activeGame.answer or answer == "1" then
            self.activeGame = nil
            return "✅ Правильно! Молодец!"
        else
            self.activeGame = nil
            return "❌ Неправильно. Правильный ответ: " .. self.activeGame.answer
        end
    end
end

-- Игра "Крестики-нолики"
function ChatGames:TicTacToeGame(args)
    return "🎮 Игра 'Крестики-нолики' в разработке..."
end

-- Обработка команд
function ChatGames:ProcessCommand(command, args)
    if not self.enabled then return end
    
    for _, game in ipairs(self.games) do
        if command == game.command then
            if game.minPlayers > 1 then
                return "⚠️ Для этой игры нужно " .. game.minPlayers .. " игроков"
            end
            return game.handler(args)
        end
    end
end

-- Включение/выключение
function ChatGames:Toggle()
    self.enabled = not self.enabled
    
    if self.chat then
        self.chat:ShowSystemMessage(
            "Игры в чате " .. (self.enabled and "включены" : "выключены"),
            self.enabled and "success" or "info"
        )
    end
    
    return self.enabled
end

-- Получение списка игр
function ChatGames:GetGamesList()
    local list = {}
    for _, game in ipairs(self.games) do
        table.insert(list, {
            name = game.name,
            command = game.command,
            description = game.description
        })
    end
    return list
end

-- Экспорт
return ChatGames
