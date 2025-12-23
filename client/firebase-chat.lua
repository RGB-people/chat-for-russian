local Firebase = {
    URL = "https://chat-for-russian-default-rtdb.europe-west1.firebasedatabase.app/",
    Messages = {}
}

function Firebase:SendMessage(text)
    local message = {
        sender = game:GetService("Players").LocalPlayer.Name,
        text = text,
        timestamp = os.time()
    }
    
    -- Отправляем в Firebase
    local success = pcall(function()
        game:HttpService:PostAsync(
            self.URL .. "messages.json",
            game:HttpService:JSONEncode(message)
        )
    end)
    
    return success
end

function Firebase:ListenForMessages()
    -- Слушаем новые сообщения
    spawn(function()
        while true do
            wait(2)
            pcall(function()
                local response = game:HttpGet(self.URL .. "messages.json")
                local messages = game:HttpService:JSONDecode(response)
                -- Обрабатываем новые сообщения
            end)
        end
    end)
end

return Firebase
