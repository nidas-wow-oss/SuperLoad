-- La carpeta se llama "!!!SuperLoad" porque tiene que cargar antes que todo.

local cg              = collectgarbage
local tremove         = table.remove
local type            = type
local pairs           = pairs
local pcall           = pcall
local getmetatable    = getmetatable
local hooksecurefunc  = hooksecurefunc
local GetTime         = GetTime
local GetFramesForEvent = GetFramesRegisteredForEvent
local InCombatLockdown  = InCombatLockdown

-- =========================================================
-- Memoria
-- =========================================================
-- Tope durante el login: con el recolector parado, un addon muy sucio
-- podria agotar la memoria del proceso (KB).
local LOGIN_CAP = 1024 * 1024

local guarded = true    -- login o combate: se ignoran limpiezas de otros addons

-- Valores que devuelve Lua 5.1; "step" = true evita colgar bucles que esperen
-- el fin del ciclo. "count", "stop", etc. pasan para no falsear lecturas.
local BLOCKED = { collect = 0, step = true, restart = 0 }

-- Queda instalada siempre: los addons que la guardaron en un local durante
-- la carga se quedan con esta funcion para toda la sesion.
_G.collectgarbage = function(opt, arg)
	if guarded then
		if opt == nil then return 0 end
		local fake = BLOCKED[opt]
		if fake ~= nil then return fake end
	end
	return cg(opt, arg)
end

cg("stop")

-- =========================================================
-- Eventos ruidosos fuera durante las pantallas de carga
-- =========================================================
-- No se vuelven a disparar al terminar: no hay forma de saber sus argumentos
-- y llamar a los OnEvent a mano mancharia el codigo de Blizzard.
local SPEEDY_EVENTS = {
	"SPELLS_CHANGED",
	"SPELL_UPDATE_USABLE",
	"ACTIONBAR_SLOT_CHANGED",
	"USE_GLYPH",
	"PLAYER_TALENT_UPDATE",
	"PET_TALENT_UPDATE",
	"WORLD_MAP_UPDATE",
	"UPDATE_WORLD_STATES",
	"UPDATE_FACTION",
	"CRITERIA_UPDATE",
	"RECEIVED_ACHIEVEMENT_LIST",
}

local speedyTracked    = {}   -- [evento] = lista de frames, en orden de registro
local speedySuppressed = false
local speedyListen     = false

local function Forget(frame, event)
	local list = speedyTracked[event]
	if not list then return end
	for i = #list, 1, -1 do
		if list[i] == frame then
			tremove(list, i)
			return
		end
	end
end

-- Lo que un addon desregistra durante la carga no se vuelve a registrar.
local function OnUnregister(frame, event)
	if speedyListen then Forget(frame, event) end
end

local function OnUnregisterAll(frame)
	if speedyListen then
		for event in pairs(speedyTracked) do Forget(frame, event) end
	end
end

-- Cada tipo de widget tiene su propia tabla de metodos.
do
	local hooked = {}
	-- Sin "EditBox": uno nuevo se queda con el foco del teclado.
	for _, wtype in pairs({
		"Frame", "Button", "CheckButton", "StatusBar", "Slider",
		"ScrollFrame", "ScrollingMessageFrame", "MessageFrame", "Cooldown",
	}) do
		pcall(function()
			local probe = CreateFrame(wtype)
			probe:Hide()
			local meta = getmetatable(probe)
			local idx = meta and meta.__index
			if type(idx) == "table" and not hooked[idx] then
				hooked[idx] = true
				hooksecurefunc(idx, "UnregisterEvent", OnUnregister)
				hooksecurefunc(idx, "UnregisterAllEvents", OnUnregisterAll)
			end
		end)
	end
end

local function SpeedySuppress()
	if speedySuppressed then return end
	for i = 1, #SPEEDY_EVENTS do
		local event = SPEEDY_EVENTS[i]
		local list = {}
		speedyTracked[event] = list
		local registered = { GetFramesForEvent(event) }
		for j = 1, #registered do
			local frame = registered[j]
			if frame.UnregisterEvent and pcall(frame.UnregisterEvent, frame, event) then
				list[#list + 1] = frame
			end
		end
	end
	speedySuppressed = true
	speedyListen = true
end

local function SpeedyRestore()
	if not speedySuppressed then return end
	speedyListen = false
	speedySuppressed = false
	-- En orden: registrar es lo que decide a quien le llega primero el evento.
	for event, list in pairs(speedyTracked) do
		for i = 1, #list do
			pcall(list[i].RegisterEvent, list[i], event)
		end
	end
end

-- =========================================================
-- Eventos propios
-- =========================================================
local f = CreateFrame("Frame")
local handlers = {}
f:SetScript("OnEvent", function(self, event, ...)
	handlers[event](event, ...)
end)

local function On(event, fn)
	handlers[event] = fn
	f:RegisterEvent(event)
end

-- Unica red de seguridad posible: durante la carga los addons corren sin
-- frames de por medio, asi que no hay OnUpdate que pueda vigilar.
On("ADDON_LOADED", function()
	if cg("count") > LOGIN_CAP then
		cg("collect")
		cg("stop")
	end
end)

local lastCollect = -10

On("PLAYER_ENTERING_WORLD", function()
	f:UnregisterEvent("ADDON_LOADED")
	SpeedyRestore()
	guarded = InCombatLockdown() and true or false

	-- Se dispara dos veces seguidas en algunos cambios de zona. "collect" ya
	-- deja al recolector andando; un "restart" aca empezaria otro ciclo enseguida.
	local now = GetTime()
	if now - lastCollect >= 2 then
		lastCollect = now
		cg("collect")
	end
end)

On("PLAYER_LEAVING_WORLD", SpeedySuppress)

-- Primero en PLAYER_ENTERING_WORLD: los eventos tienen que estar devueltos
-- antes de que los demas addons reaccionen a la entrada al mundo.
On("PLAYER_LOGIN", function()
	f:UnregisterEvent("PLAYER_LOGIN")
	pcall(function()
		local frames = { GetFramesForEvent("PLAYER_ENTERING_WORLD") }
		for i = 1, #frames do
			if frames[i] ~= f then
				pcall(frames[i].UnregisterEvent, frames[i], "PLAYER_ENTERING_WORLD")
			end
		end
		f:RegisterEvent("PLAYER_ENTERING_WORLD")
		for i = 1, #frames do
			if frames[i] ~= f then
				pcall(frames[i].RegisterEvent, frames[i], "PLAYER_ENTERING_WORLD")
			end
		end
	end)
end)

-- Una limpieza completa en combate se notaria como un tiron.
On("PLAYER_REGEN_DISABLED", function() guarded = true end)
On("PLAYER_REGEN_ENABLED", function() guarded = false end)

-- =========================================================
-- Arreglos de la interfaz de Blizzard
-- =========================================================
-- Solo hooksecurefunc/HookScript: reemplazar funciones causaria taint.

-- Los botones de los menus desplegables quedaban por debajo del fondo.
pcall(function()
	hooksecurefunc("UIDropDownMenu_CreateFrames", function()
		for l = 1, UIDROPDOWNMENU_MAXLEVELS do
			for b = 1, UIDROPDOWNMENU_MAXBUTTONS do
				local button = _G["DropDownList" .. l .. "Button" .. b]
				local parent = button and button:GetParent()
				if parent and button:GetFrameLevel() <= parent:GetFrameLevel() then
					button:SetFrameLevel(parent:GetFrameLevel() + 2)
				end
			end
		end
	end)
end)

-- InterfaceOptionsFrame_OpenToCategory no abria ni mostraba la categoria.
pcall(function()
	local doNotRun = false

	local function PanelName(panel)
		local cat = INTERFACEOPTIONS_ADDONCATEGORIES
		if not cat then return end
		if type(panel) == "string" then
			for _, p in pairs(cat) do
				if p.name == panel then
					if p.parent then return PanelName(p.parent) end
					return panel
				end
			end
		elseif type(panel) == "table" then
			for _, p in pairs(cat) do
				if p == panel then
					if p.parent then return PanelName(p.parent) end
					return panel.name
				end
			end
		end
	end

	hooksecurefunc("InterfaceOptionsFrame_OpenToCategory", function(panel)
		if InCombatLockdown() then return end
		if doNotRun then
			doNotRun = false
			return
		end
		pcall(function()
			local name = PanelName(panel)
			if not name then return end

			local open, shown, mine = {}, 0, nil
			local t = {}
			for _, p in ipairs(INTERFACEOPTIONS_ADDONCATEGORIES) do
				if not p.parent or open[p.parent] then
					if p.name == name then
						p.collapsed = true
						t.element = p
						InterfaceOptionsListButton_ToggleSubCategories(t)
						open[p.name] = true
						mine = shown + 1
					end
					if not p.collapsed then open[p.name] = true end
					shown = shown + 1
				end
			end

			local bar = InterfaceOptionsFrameAddOnsListScrollBar
			if bar and mine and shown > 15 then
				local _, smax = bar:GetMinMaxValues()
				bar:SetValue((smax / (shown - 15)) * (mine - 2))
			end
			doNotRun = true
			InterfaceOptionsFrame_OpenToCategory(panel)
		end)
		-- Siempre se limpia, aunque la llamada anidada falle.
		doNotRun = false
	end)
end)

-- El ping del minimapa no seguia su posicion al moverte.
pcall(function()
	MinimapPing:HookScript("OnUpdate", function(self)
		if self.fadeOut or (self.timer and self.timer > MINIMAPPING_FADE_TIMER) then
			local x, y = Minimap:GetPingPosition()
			if x then
				Minimap_SetPing(x, y)
				-- Minimap_SetPing deja el alpha en 1: sin esto el ping
				-- desaparecia de golpe en vez de desvanecerse.
				if self.fadeOut and self.fadeOutTimer and self.fadeOutTimer > 0 then
					self:SetAlpha(self.fadeOutTimer / MINIMAPPING_FADE_TIMER)
				end
			end
		end
	end)
end)
