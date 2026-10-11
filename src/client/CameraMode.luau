-- Vista aérea isométrica: al alejar un poco la cámara cambia a una vista desde arriba
-- (ideal para colocar equipo). Acercar de nuevo vuelve a la cámara normal.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local M = {}
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

local ENTER_DIST = 30 -- distancia de zoom normal a la que se pasa a aérea
local ISO_MIN, ISO_MAX, ISO_START = 90, 260, 130
local ISO_ROT = CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(math.rad(-52), 0, 0)
local ISO_FOV = 30 -- poco ángulo + mucha distancia ≈ isométrica sin perspectiva

local iso, blend, zoom = false, 0, ISO_START
local armed = true -- solo entra si antes la cámara estuvo cerca (evita rebotar al salir)
local normalFov = cam.FieldOfView
local onChange = function(_) end

local function focusPos()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or cam.Focus.Position
end

local function enter()
	if iso then return end
	iso, zoom = true, ISO_START
	normalFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	onChange(true)
end

local function exit()
	if not iso then return end
	iso, armed = false, false
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = normalFov
	-- fuerza la cámara normal a acercarse unos cuadros y luego devuelve el límite
	local max = player.CameraMaxZoomDistance
	player.CameraMaxZoomDistance = 14
	task.delay(0.3, function() player.CameraMaxZoomDistance = max end)
	onChange(false)
end

local function zoomBy(delta)
	zoom += delta
	if zoom < ISO_MIN - 15 then
		exit()
	else
		zoom = math.clamp(zoom, ISO_MIN, ISO_MAX)
	end
end

-- la cámara de Roblox marca la rueda como "procesada", así que no se filtra por eso;
-- solo se ignora si el mouse está sobre una lista con scroll de la interfaz
local function overScrollingUI(pos)
	for _, g in player.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		if g:IsA("ScrollingFrame") then return true end
	end
	return false
end

UserInputService.InputChanged:Connect(function(input)
	if not iso or input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
	if overScrollingUI(UserInputService:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()) then return end
	zoomBy(-input.Position.Z * 18)
end)

local lastPinch
UserInputService.TouchPinch:Connect(function(_, scale, _, state)
	if not iso then return end
	if state == Enum.UserInputState.Begin then lastPinch = scale return end
	if lastPinch then zoomBy((lastPinch - scale) * 160) end
	lastPinch = scale
end)

RunService:BindToRenderStep("VistaAerea", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not iso then
		blend = 0
		-- detectar que el jugador alejó la cámara normal
		if cam.CameraType == Enum.CameraType.Custom then
			local dist = (cam.CFrame.Position - cam.Focus.Position).Magnitude
			if dist < ENTER_DIST - 4 then armed = true end
			if armed and dist > ENTER_DIST then enter() end
		end
		return
	end
	blend = math.min(1, blend + dt * 3)
	local goal = CFrame.new(focusPos()) * ISO_ROT * CFrame.new(0, 0, zoom)
	local a = 1 - (1 - blend) ^ 3 -- entrada suave
	cam.CFrame = cam.CFrame:Lerp(goal, blend < 1 and a or math.min(1, dt * 8))
	cam.FieldOfView = normalFov + (ISO_FOV - normalFov) * a
end)

function M.init(cb) onChange = cb end
function M.isIso() return iso end

return M
