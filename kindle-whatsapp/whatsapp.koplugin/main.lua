-- Hafif WhatsApp istemcisi. Ağır modüller sadece kullanılınca yüklenir.
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local LIMIT = 15

local WhatsApp = WidgetContainer:extend{
    name = "whatsapp",
    is_doc_only = false,
}

local function urlencode(s)
    return (s:gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", c:byte()) end))
end

function WhatsApp:init()
    self.ui.menu:registerToMainMenu(self)
end

local function cfg(key, default)
    return G_reader_settings:readSetting(key) or default
end

function WhatsApp:msg(text, timeout)
    local UIManager = require("ui/uimanager")
    local InfoMessage = require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new{ text = text, timeout = timeout or 4 })
end

-- Eski/yeni KOReader sürümleriyle uyumlu "online olunca çalıştır"
function WhatsApp:online(fn)
    local NetworkMgr = require("ui/network/manager")
    if NetworkMgr.runWhenOnline then
        NetworkMgr:runWhenOnline(fn)
    elseif NetworkMgr.isOnline and NetworkMgr:isOnline() then
        fn()
    elseif NetworkMgr.promptWifiOn then
        NetworkMgr:promptWifiOn()
    else
        fn()
    end
end

-- Döner: tablo, ya da nil + hata metni
function WhatsApp:api(method, path, body)
    local http = require("socket.http")
    local ltn12 = require("ltn12")
    local JSON = require("json")
    local okS, socketutil = pcall(require, "socketutil")

    local resp = {}
    local headers = { ["X-Token"] = cfg("whatsapp_token", "changeme") }
    local source
    if body then
        local s = JSON.encode(body)
        headers["Content-Type"] = "application/json"
        headers["Content-Length"] = tostring(#s)
        source = ltn12.source.string(s)
    end
    if okS and socketutil.set_timeout then socketutil:set_timeout(10, 30) else http.TIMEOUT = 15 end
    local ok, code = http.request{
        url = cfg("whatsapp_server", "http://192.168.1.10:3000") .. path,
        method = method,
        headers = headers,
        source = source,
        sink = ltn12.sink.table(resp),
    }
    if okS and socketutil.reset_timeout then socketutil:reset_timeout() end
    if not ok then return nil, _("Sunucuya bağlanılamadı") end
    local okj, data = pcall(JSON.decode, table.concat(resp))
    if not okj or type(data) ~= "table" then
        return nil, _("Geçersiz yanıt") .. " (" .. tostring(code) .. ")"
    end
    if code ~= 200 then return nil, data.error or ("HTTP " .. tostring(code)) end
    return data
end

function WhatsApp:ask(title, default, cb, hint)
    local UIManager = require("ui/uimanager")
    local InputDialog = require("ui/widget/inputdialog")
    local dlg
    dlg = InputDialog:new{
        title = title,
        input = default or "",
        input_hint = hint,
        buttons = {{
            { text = _("İptal"), id = "close", callback = function() UIManager:close(dlg) end },
            { text = _("Tamam"), is_enter_default = true, callback = function()
                local t = dlg:getInputText()
                UIManager:close(dlg)
                cb(t)
            end },
        }},
    }
    UIManager:show(dlg)
    dlg:onShowKeyboard()
end

function WhatsApp:pair()
    self:ask(_("Telefon numarası (905xxxxxxxxx)"), "", function(phone)
        self:online(function()
            local data, err = self:api("POST", "/pair", { phone = phone })
            if not data then return self:msg(err) end
            if data.error then return self:msg(data.error) end
            self:msg(_("Eşleştirme kodu:") .. "\n\n" .. data.code ..
                "\n\n" .. _("Telefonda WhatsApp > Bağlı cihazlar > Cihaz bağla > Telefon numarasıyla bağla"), 60)
        end)
    end, "905551234567")
end

function WhatsApp:showChat(jid, name)
    self:online(function()
        local data, err = self:api("GET", "/messages?limit=" .. LIMIT .. "&jid=" .. urlencode(jid))
        if not data then return self:msg(err) end
        local UIManager = require("ui/uimanager")
        local TextViewer = require("ui/widget/textviewer")
        local Screen = require("device").screen
        local lines = {}
        for i = #data.messages, 1, -1 do   -- en yeni üstte
            local m = data.messages[i]
            local who = m.fromMe and _("Ben") or (m.name or name)
            lines[#lines + 1] = who .. " [" .. m.time .. "]\n" .. m.text .. "\n"
        end
        if #lines == 0 then lines[1] = _("(mesaj yok)") end
        if self.viewer then UIManager:close(self.viewer) end
        self.viewer = TextViewer:new{
            title = name,
            text = table.concat(lines, "\n"),
            width = Screen:getWidth(),
            height = Screen:getHeight(),
            buttons_table = {{
                { text = _("Yaz"), callback = function()
                    self:ask(_("Mesaj"), "", function(text)
                        if text == "" then return end
                        local r, e = self:api("POST", "/send", { jid = jid, text = text })
                        if not r then return self:msg(e) end
                        self:showChat(jid, name)
                    end)
                end },
                { text = _("Yenile"), callback = function() self:showChat(jid, name) end },
                { text = _("Kapat"), callback = function()
                    UIManager:close(self.viewer)
                    self.viewer = nil
                end },
            }},
        }
        UIManager:show(self.viewer)
    end)
end

function WhatsApp:showChats()
    self:online(function()
        local data, err = self:api("GET", "/chats")
        if not data then return self:msg(err) end
        local UIManager = require("ui/uimanager")
        local Menu = require("ui/widget/menu")
        local Screen = require("device").screen
        if self.chat_menu then UIManager:close(self.chat_menu) end
        local items = {{
            text = "↻ " .. _("Yenile"),
            callback = function() self:showChats() end,
        }}
        for _i, c in ipairs(data.chats) do
            items[#items + 1] = {
                text = c.name .. " - " .. c.last,
                mandatory = c.time,
                callback = function() self:showChat(c.jid, c.name) end,
            }
        end
        self.chat_menu = Menu:new{
            title = "WhatsApp",
            item_table = items,
            is_borderless = true,
            is_popout = false,
            covers_fullscreen = true,
            width = Screen:getWidth(),
            height = Screen:getHeight(),
            close_callback = function() self.chat_menu = nil end,
        }
        UIManager:show(self.chat_menu)
    end)
end

function WhatsApp:newMessage()
    self:ask(_("Kişi numarası (905xxxxxxxxx)"), "", function(num)
        num = num:gsub("%D", "")
        if num == "" then return end
        self:showChat(num .. "@s.whatsapp.net", num)
    end, "905551234567")
end

function WhatsApp:addToMainMenu(menu_items)
    menu_items.whatsapp = {
        text = _("WhatsApp"),
        sorting_hint = "tools",
        sub_item_table = {
            { text = _("Sohbetler"), callback = function() self:showChats() end },
            { text = _("Yeni mesaj (numara ile)"), callback = function() self:newMessage() end },
            { text = _("Telefonla eşleştir"), callback = function() self:pair() end },
            { text = _("Bağlantı durumu"), callback = function()
                self:online(function()
                    local d, e = self:api("GET", "/status")
                    if not d then return self:msg(e) end
                    self:msg(d.connected and _("WhatsApp bağlı") or _("WhatsApp bağlı değil"))
                end)
            end },
            { text = _("Sunucu adresi"), keep_menu_open = true, callback = function()
                self:ask(_("Sunucu adresi"), cfg("whatsapp_server", "http://192.168.1.10:3000"), function(t)
                    G_reader_settings:saveSetting("whatsapp_server", (t:gsub("/+$", "")))
                end, "http://192.168.1.10:3000")
            end },
            { text = _("Token"), keep_menu_open = true, callback = function()
                self:ask(_("Token"), cfg("whatsapp_token", "changeme"), function(t)
                    G_reader_settings:saveSetting("whatsapp_token", t)
                end)
            end },
        },
    }
end

return WhatsApp
