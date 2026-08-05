--!strict

--  ____                 _ _ _____
-- / ___|  ___ _ __ ___ | | |  ___| __ __ _ _ __ ___   ___
-- \___ \ / __| '__/ _ \| | | |_ | '__/ _` | '_ ` _ \ / _ \
--  ___) | (__| | | (_) | | |  _|| | | (_| | | | | | |  __/
-- |____/ \___|_|  \___/|_|_|_|  |_|  \__,_|_| |_| |_|\___|
-- / ___|  ___ __ _| | ___ _ __
-- \___ \ / __/ _` | |/ _ \ '__|
--  ___) | (_| (_| | |  __/ |
-- |____/ \___\__,_|_|\___|_|

-- made with ❤️ by biotoxin495

-- ScrollFrameScaler
-- Automatically keeps a ScrollingFrame's CanvasSize fitted to its content.

-- Supported content:
-- - UIListLayout, including wrapping layouts
-- - UIGridLayout
-- - UIPadding
-- - Directly positioned GuiObjects when no supported layout is present

-- Basic usage:
-- 	local ScrollFrameScaler = require(path.To.ScrollFrameScaler)

-- 	ScrollFrameScaler.Setup(scrollingFrame, {
-- 		Axis = "Y",
-- 	})

-- 	-- Optional manual refresh:
-- 	ScrollFrameScaler.Update(scrollingFrame)

-- 	-- Disconnect all listeners:
-- 	ScrollFrameScaler.Cleanup(scrollingFrame)

local TweenService = game:GetService("TweenService")

local ScrollFrameScaler = {}

export type Axis = "X" | "Y" | "XY"

export type SetupOptions = {
	Axis: Axis?,
	IncludeInvisible: boolean?,
	ExtraPadding: Vector2?,
	PreserveCanvasPosition: boolean?,
}

export type FocusOptions = {
	TweenInfo: TweenInfo?,
	HorizontalAlignment: Enum.HorizontalAlignment?,
	VerticalAlignment: Enum.VerticalAlignment?,
	Force: boolean?,
}

type State = {
	axis: Axis,
	includeInvisible: boolean,
	extraPadding: Vector2,
	preserveCanvasPosition: boolean,
	queued: boolean,
	cleaned: boolean,
	connections: { RBXScriptConnection },
	childConnections: { [Instance]: { RBXScriptConnection } },
	activeTween: Tween?,
	previousAutomaticCanvasSize: Enum.AutomaticSize,
}

local states: { [ScrollingFrame]: State } = setmetatable({}, { __mode = "k" }) :: any

local function validateAxis(axis: string?): Axis
	local normalized = string.upper(axis or "Y")

	if normalized == "X" or normalized == "Y" or normalized == "XY" or normalized == "YX" then
		if normalized == "YX" then
			return "XY"
		end
		return normalized :: Axis
	end

	error(string.format("ScrollFrameScaler: invalid axis %q; expected X, Y, or XY", tostring(axis)), 3)
end

local function resolveUDim(value: UDim, parentSize: number): number
	return value.Scale * parentSize + value.Offset
end

local function getPadding(scrollFrame: ScrollingFrame): Vector2
	local padding = scrollFrame:FindFirstChildOfClass("UIPadding")
	if not padding then
		return Vector2.zero
	end

	local size = scrollFrame.AbsoluteSize
	local horizontal = resolveUDim(padding.PaddingLeft, size.X) + resolveUDim(padding.PaddingRight, size.X)
	local vertical = resolveUDim(padding.PaddingTop, size.Y) + resolveUDim(padding.PaddingBottom, size.Y)

	return Vector2.new(horizontal, vertical)
end

local function getSupportedLayout(scrollFrame: ScrollingFrame): UIListLayout | UIGridLayout | nil
	return scrollFrame:FindFirstChildOfClass("UIListLayout") or scrollFrame:FindFirstChildOfClass("UIGridLayout")
end

local function measureAbsoluteContent(scrollFrame: ScrollingFrame, includeInvisible: boolean): Vector2
	local canvasPosition = scrollFrame.CanvasPosition
	local origin = scrollFrame.AbsolutePosition
	local maxX = 0
	local maxY = 0

	for _, child in scrollFrame:GetChildren() do
		if child:IsA("GuiObject") and (includeInvisible or child.Visible) then
			local relativePosition = child.AbsolutePosition - origin + canvasPosition
			local bottomRight = relativePosition + child.AbsoluteSize

			maxX = math.max(maxX, bottomRight.X)
			maxY = math.max(maxY, bottomRight.Y)
		end
	end

	return Vector2.new(maxX, maxY)
end

local function measureContent(scrollFrame: ScrollingFrame, state: State): Vector2
	local layout = getSupportedLayout(scrollFrame)
	local contentSize = if layout
		then layout.AbsoluteContentSize
		else measureAbsoluteContent(scrollFrame, state.includeInvisible)
	return contentSize + getPadding(scrollFrame) + state.extraPadding
end

local function applyCanvasSize(scrollFrame: ScrollingFrame, state: State, contentSize: Vector2)
	local oldCanvasSize = scrollFrame.CanvasSize
	local oldCanvasPosition = scrollFrame.CanvasPosition
	local updateX = string.find(state.axis, "X", 1, true) ~= nil
	local updateY = string.find(state.axis, "Y", 1, true) ~= nil

	scrollFrame.CanvasSize = UDim2.new(
		if updateX then 0 else oldCanvasSize.X.Scale,
		if updateX then math.max(0, math.ceil(contentSize.X)) else oldCanvasSize.X.Offset,
		if updateY then 0 else oldCanvasSize.Y.Scale,
		if updateY then math.max(0, math.ceil(contentSize.Y)) else oldCanvasSize.Y.Offset
	)

	if state.preserveCanvasPosition then
		local maxPosition = Vector2.new(
			math.max(0, scrollFrame.AbsoluteCanvasSize.X - scrollFrame.AbsoluteWindowSize.X),
			math.max(0, scrollFrame.AbsoluteCanvasSize.Y - scrollFrame.AbsoluteWindowSize.Y)
		)

		scrollFrame.CanvasPosition = Vector2.new(
			math.clamp(oldCanvasPosition.X, 0, maxPosition.X),
			math.clamp(oldCanvasPosition.Y, 0, maxPosition.Y)
		)
	end
end

local function updateNow(scrollFrame: ScrollingFrame, state: State)
	if state.cleaned or scrollFrame.Parent == nil then
		return
	end

	applyCanvasSize(scrollFrame, state, measureContent(scrollFrame, state))
end

local function queueUpdate(scrollFrame: ScrollingFrame, state: State)
	if state.cleaned or state.queued then
		return
	end

	state.queued = true
	task.defer(function()
		state.queued = false
		updateNow(scrollFrame, state)
	end)
end

local function disconnectConnections(connections: { RBXScriptConnection })
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function unwatchChild(state: State, child: Instance)
	local connections = state.childConnections[child]
	if not connections then
		return
	end

	disconnectConnections(connections)
	state.childConnections[child] = nil
end

local function watchChild(scrollFrame: ScrollingFrame, state: State, child: Instance)
	unwatchChild(state, child)

	local connections = {}
	state.childConnections[child] = connections

	if child:IsA("GuiObject") then
		table.insert(
			connections,
			child:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				queueUpdate(scrollFrame, state)
			end)
		)
		table.insert(
			connections,
			child:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
				if getSupportedLayout(scrollFrame) == nil then
					queueUpdate(scrollFrame, state)
				end
			end)
		)
		table.insert(
			connections,
			child:GetPropertyChangedSignal("Visible"):Connect(function()
				queueUpdate(scrollFrame, state)
			end)
		)
		table.insert(
			connections,
			child:GetPropertyChangedSignal("LayoutOrder"):Connect(function()
				queueUpdate(scrollFrame, state)
			end)
		)
	elseif child:IsA("UIListLayout") or child:IsA("UIGridLayout") then
		table.insert(
			connections,
			child:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				queueUpdate(scrollFrame, state)
			end)
		)
		table.insert(
			connections,
			child.Changed:Connect(function()
				queueUpdate(scrollFrame, state)
			end)
		)
	elseif child:IsA("UIPadding") then
		table.insert(
			connections,
			child.Changed:Connect(function()
				queueUpdate(scrollFrame, state)
			end)
		)
	end
end

function ScrollFrameScaler.Setup(scrollFrame: ScrollingFrame, options: SetupOptions?)
	assert(scrollFrame and scrollFrame:IsA("ScrollingFrame"), "ScrollFrameScaler.Setup expects a ScrollingFrame")

	ScrollFrameScaler.Cleanup(scrollFrame)

	local config: SetupOptions = options or {}
	local state: State = {
		axis = validateAxis(config.Axis),
		includeInvisible = config.IncludeInvisible == true,
		extraPadding = config.ExtraPadding or Vector2.zero,
		preserveCanvasPosition = config.PreserveCanvasPosition ~= false,
		queued = false,
		cleaned = false,
		connections = {},
		childConnections = {},
		activeTween = nil,
		previousAutomaticCanvasSize = scrollFrame.AutomaticCanvasSize,
	}

	states[scrollFrame] = state
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.None

	for _, child in scrollFrame:GetChildren() do
		watchChild(scrollFrame, state, child)
	end

	table.insert(
		state.connections,
		scrollFrame.ChildAdded:Connect(function(child)
			watchChild(scrollFrame, state, child)
			queueUpdate(scrollFrame, state)
		end)
	)

	table.insert(
		state.connections,
		scrollFrame.ChildRemoved:Connect(function(child)
			unwatchChild(state, child)
			queueUpdate(scrollFrame, state)
		end)
	)

	table.insert(
		state.connections,
		scrollFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			queueUpdate(scrollFrame, state)
		end)
	)

	table.insert(
		state.connections,
		scrollFrame.Destroying:Connect(function()
			ScrollFrameScaler.Cleanup(scrollFrame)
		end)
	)

	updateNow(scrollFrame, state)
end

function ScrollFrameScaler.Update(scrollFrame: ScrollingFrame)
	local state = states[scrollFrame]
	if not state then
		error("ScrollFrameScaler.Update called before ScrollFrameScaler.Setup", 2)
	end

	updateNow(scrollFrame, state)
end

function ScrollFrameScaler.Cleanup(scrollFrame: ScrollingFrame)
	local state = states[scrollFrame]
	if not state then
		return
	end

	state.cleaned = true

	if state.activeTween then
		state.activeTween:Cancel()
		state.activeTween = nil
	end

	disconnectConnections(state.connections)

	for child in state.childConnections do
		unwatchChild(state, child)
	end

	if scrollFrame.Parent ~= nil then
		scrollFrame.AutomaticCanvasSize = state.previousAutomaticCanvasSize
	end

	states[scrollFrame] = nil
end

function ScrollFrameScaler.Focus(scrollFrame: ScrollingFrame, object: GuiObject, options: FocusOptions?): Tween?
	assert(scrollFrame and scrollFrame:IsA("ScrollingFrame"), "ScrollFrameScaler.Focus expects a ScrollingFrame")
	assert(object and object:IsA("GuiObject"), "ScrollFrameScaler.Focus expects a GuiObject")
	assert(object:IsDescendantOf(scrollFrame), "The focus target must be a descendant of the ScrollingFrame")

	local config: FocusOptions = options or {}
	local horizontalAlignment = config.HorizontalAlignment or Enum.HorizontalAlignment.Center
	local verticalAlignment = config.VerticalAlignment or Enum.VerticalAlignment.Center
	local currentPosition = scrollFrame.CanvasPosition
	local viewportSize = scrollFrame.AbsoluteWindowSize
	local objectPosition = object.AbsolutePosition - scrollFrame.AbsolutePosition + currentPosition
	local objectSize = object.AbsoluteSize

	local fullyVisible = objectPosition.X >= currentPosition.X
		and objectPosition.Y >= currentPosition.Y
		and objectPosition.X + objectSize.X <= currentPosition.X + viewportSize.X
		and objectPosition.Y + objectSize.Y <= currentPosition.Y + viewportSize.Y

	if fullyVisible and config.Force ~= true then
		return nil
	end

	local targetX = objectPosition.X
	local targetY = objectPosition.Y

	if horizontalAlignment == Enum.HorizontalAlignment.Center then
		targetX -= (viewportSize.X - objectSize.X) / 2
	elseif horizontalAlignment == Enum.HorizontalAlignment.Right then
		targetX -= viewportSize.X - objectSize.X
	end

	if verticalAlignment == Enum.VerticalAlignment.Center then
		targetY -= (viewportSize.Y - objectSize.Y) / 2
	elseif verticalAlignment == Enum.VerticalAlignment.Bottom then
		targetY -= viewportSize.Y - objectSize.Y
	end

	local maxPosition = Vector2.new(
		math.max(0, scrollFrame.AbsoluteCanvasSize.X - viewportSize.X),
		math.max(0, scrollFrame.AbsoluteCanvasSize.Y - viewportSize.Y)
	)
	local targetPosition = Vector2.new(math.clamp(targetX, 0, maxPosition.X), math.clamp(targetY, 0, maxPosition.Y))

	local state = states[scrollFrame]
	if state and state.activeTween then
		state.activeTween:Cancel()
	end

	local tween = TweenService:Create(
		scrollFrame,
		config.TweenInfo or TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ CanvasPosition = targetPosition }
	)

	if state then
		state.activeTween = tween
		tween.Completed:Once(function()
			if state.activeTween == tween then
				state.activeTween = nil
			end
		end)
	end

	tween:Play()
	return tween
end

return ScrollFrameScaler
