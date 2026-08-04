# ScrollFrameScaler — Automatic canvas sizing for ScrollingFrames

**ScrollFrameScaler**, a lightweight Roblox utility module that automatically keeps a `ScrollingFrame`'s `CanvasSize` fitted to its content.

Keeping a `ScrollingFrame`'s canvas in sync with dynamic content usually means manually recalculating sizes every time a child is added, removed, resized, repositioned, or hidden — or leaning on Roblox's built-in `AutomaticCanvasSize`, which doesn't account for wrapping layouts, responsive padding, or directly positioned content in a fully predictable way.

**ScrollFrameScaler** handles this for you. It observes the contents of a `ScrollingFrame` and recalculates its canvas whenever anything relevant changes, with support for Roblox layout objects, responsive padding, directly positioned UI elements, and both horizontal and vertical scrolling.

## Quick example

```lua
local ScrollFrameScaler = require(ReplicatedStorage.Modules.ScrollFrameScaler)

ScrollFrameScaler.Setup(scrollingFrame, {
	Axis = "Y",
})
```

Build your list, grid, or free-form UI normally inside the `ScrollingFrame`. ScrollFrameScaler watches it and keeps `CanvasSize` correct as things change.

## 🚀 Features

- Automatically updates a `ScrollingFrame`’s `CanvasSize`
- Supports X, Y, or both scrolling axes
- Supports `UIListLayout`
- Supports wrapping `UIListLayout` configurations
- Supports `UIGridLayout`
- Supports scale- and offset-based `UIPadding`
- Supports directly positioned `GuiObject` children without a layout
- Reacts to child addition, removal, resizing, movement, visibility, and layout changes
- Coalesces rapid changes into a single deferred update
- Preserves the current `CanvasPosition` when content changes
- Supports additional configurable canvas padding
- Automatically disables Roblox’s built-in `AutomaticCanvasSize`
- Restores the original `AutomaticCanvasSize` value during cleanup
- Includes optional animated scrolling to a specific descendant
- Cleans up connections automatically when the `ScrollingFrame` is destroyed
- Fully typed for Luau strict mode

## 🛠️ Installation

Place the `ScrollFrameScaler` ModuleScript somewhere accessible to your client code, such as `ReplicatedStorage`.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScrollFrameScaler = require(
	ReplicatedStorage:WaitForChild("ScrollFrameScaler")
)
```

`ScrollFrameScaler` is intended for client-side UI code.

## 📖 Basic Usage

Call `Setup` once for every `ScrollingFrame` that should be managed.

```lua
local ScrollFrameScaler = require(path.To.ScrollFrameScaler)

ScrollFrameScaler.Setup(scrollingFrame, {
	Axis = "Y",
})
```

The module immediately calculates the required canvas size and continues updating it as the interface changes.

When the `ScrollingFrame` is no longer being managed, call `Cleanup`:

```lua
ScrollFrameScaler.Cleanup(scrollingFrame)
```

Cleanup is also performed automatically when the `ScrollingFrame` is destroyed.

## Configuration

`Setup` accepts an optional configuration table.

```lua
ScrollFrameScaler.Setup(scrollingFrame, {
	Axis = "Y",
	IncludeInvisible = false,
	ExtraPadding = Vector2.new(0, 16),
	PreserveCanvasPosition = true,
})
```

### `Axis`

```lua
Axis: "X" | "Y" | "XY"?
```

Determines which parts of `CanvasSize` the module manages.

```lua
Axis = "X"
```

Manages horizontal canvas sizing.

```lua
Axis = "Y"
```

Manages vertical canvas sizing.

```lua
Axis = "XY"
```

Manages both axes.

The default value is `"Y"`.

An unmanaged axis retains its existing `CanvasSize` scale and offset values.

### `IncludeInvisible`

```lua
IncludeInvisible: boolean?
```

Determines whether invisible `GuiObject` children are included when measuring directly positioned content.

The default value is `false`.

```lua
IncludeInvisible = true
```

This option primarily affects `ScrollingFrame`s without a supported layout. Layout-based sizing uses the layout’s resolved `AbsoluteContentSize`.

### `ExtraPadding`

```lua
ExtraPadding: Vector2?
```

Adds additional pixel space to the final calculated canvas size.

```lua
ExtraPadding = Vector2.new(12, 24)
```

The X value adds horizontal space, while the Y value adds vertical space.

The default value is `Vector2.zero`.

This is applied in addition to any `UIPadding` inside the `ScrollingFrame`.

### `PreserveCanvasPosition`

```lua
PreserveCanvasPosition: boolean?
```

Determines whether the existing scroll position should be preserved when the canvas changes.

The default value is `true`.

The preserved position is clamped to the new canvas bounds, preventing the frame from remaining scrolled beyond its available content.

## Supported Layouts

### UIListLayout

`UIListLayout` content is measured using its resolved `AbsoluteContentSize`.

This supports:

- Vertical lists
- Horizontal lists
- Wrapping lists
- Different child sizes
- Layout padding
- Layout ordering
- Responsive UI sizes

```lua
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = scrollingFrame

ScrollFrameScaler.Setup(scrollingFrame, {
	Axis = "Y",
})
```

### UIGridLayout

`UIGridLayout` content is also measured using `AbsoluteContentSize`.

This allows the module to respect Roblox’s resolved grid behavior, including responsive cell sizes, padding, fill direction, and grid configuration.

```lua
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.fromOffset(120, 80)
layout.CellPadding = UDim2.fromOffset(8, 8)
layout.Parent = scrollingFrame

ScrollFrameScaler.Setup(scrollingFrame, {
	Axis = "Y",
})
```

### UIPadding

A direct child `UIPadding` is included in the final canvas calculation.

Both scale and offset values are supported.

```lua
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0.025, 0)
padding.PaddingRight = UDim.new(0.025, 0)
padding.Parent = scrollingFrame
```

### Directly Positioned Content

When no supported layout is present, the module measures the bounds of the direct `GuiObject` children inside the `ScrollingFrame`.

```lua
local item = Instance.new("Frame")
item.Position = UDim2.fromOffset(20, 300)
item.Size = UDim2.fromOffset(200, 80)
item.Parent = scrollingFrame

ScrollFrameScaler.Setup(scrollingFrame, {
	Axis = "Y",
})
```

The canvas will extend far enough to contain the child’s position and size.

Only direct `GuiObject` children are used for this calculation. Nested UI should generally be placed inside a direct content container or managed through a layout.

## Manual Updates

The module automatically responds to supported UI changes, but a recalculation can also be requested manually.

```lua
ScrollFrameScaler.Update(scrollingFrame)
```

The `ScrollingFrame` must already have been passed to `Setup`.

A manual update may be useful after a custom UI operation whose final visual state is not immediately represented by one of the watched properties.

## Cleanup

Call `Cleanup` to stop managing a `ScrollingFrame`.

```lua
ScrollFrameScaler.Cleanup(scrollingFrame)
```

This:

- Disconnects all event connections
- Cancels any active focus tween
- Removes the frame’s internal state
- Restores its previous `AutomaticCanvasSize` value

Calling `Cleanup` on an unmanaged frame safely does nothing.

Calling `Setup` again on the same frame automatically cleans up the previous configuration before applying the new one.

## Focusing an Object

`ScrollFrameScaler.Focus` scrolls the frame to reveal and align a descendant `GuiObject`.

```lua
ScrollFrameScaler.Focus(scrollingFrame, targetObject)
```

By default, the object is centered horizontally and vertically.

If the object is already fully visible, no scrolling occurs unless `Force` is enabled.

### Focus Options

```lua
ScrollFrameScaler.Focus(scrollingFrame, targetObject, {
	TweenInfo = TweenInfo.new(
		0.3,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	),

	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Force = false,
})
```

### `TweenInfo`

```lua
TweenInfo: TweenInfo?
```

Controls the focus animation.

The default is:

```lua
TweenInfo.new(
	0.3,
	Enum.EasingStyle.Quint,
	Enum.EasingDirection.Out
)
```

### `HorizontalAlignment`

```lua
HorizontalAlignment: Enum.HorizontalAlignment?
```

Determines the target’s horizontal alignment inside the visible area.

Supported values:

- `Enum.HorizontalAlignment.Left`
- `Enum.HorizontalAlignment.Center`
- `Enum.HorizontalAlignment.Right`

The default is `Center`.

### `VerticalAlignment`

```lua
VerticalAlignment: Enum.VerticalAlignment?
```

Determines the target’s vertical alignment inside the visible area.

Supported values:

- `Enum.VerticalAlignment.Top`
- `Enum.VerticalAlignment.Center`
- `Enum.VerticalAlignment.Bottom`

The default is `Center`.

### `Force`

```lua
Force: boolean?
```

When `false`, the function does nothing if the target is already fully visible.

When `true`, the target is aligned even when it is already within the viewport.

The default value is `false`.

### Returned Tween

`Focus` returns the created `Tween`.

```lua
local tween = ScrollFrameScaler.Focus(
	scrollingFrame,
	targetObject
)

if tween then
	tween.Completed:Wait()
end
```

It returns `nil` when the target is already visible and forced alignment is not enabled.

Starting another focus operation on a managed frame cancels its previous focus tween.

## ⚙️ API Reference

### `ScrollFrameScaler.Setup`

```lua
ScrollFrameScaler.Setup(
	scrollFrame: ScrollingFrame,
	options: SetupOptions?
)
```

Begins automatically managing the supplied `ScrollingFrame`.

### `ScrollFrameScaler.Update`

```lua
ScrollFrameScaler.Update(
	scrollFrame: ScrollingFrame
)
```

Immediately recalculates the canvas size of a managed frame.

Throws an error if `Setup` has not been called for that frame.

### `ScrollFrameScaler.Cleanup`

```lua
ScrollFrameScaler.Cleanup(
	scrollFrame: ScrollingFrame
)
```

Stops managing the frame and disconnects all associated listeners.

### `ScrollFrameScaler.Focus`

```lua
ScrollFrameScaler.Focus(
	scrollFrame: ScrollingFrame,
	object: GuiObject,
	options: FocusOptions?
): Tween?
```

Animates the frame’s `CanvasPosition` to reveal and align a descendant object.

## Complete Example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScrollFrameScaler = require(
	ReplicatedStorage:WaitForChild("ScrollFrameScaler")
)

local scrollingFrame = script.Parent:WaitForChild("ScrollingFrame")
local targetItem = scrollingFrame:WaitForChild("ImportantItem")

ScrollFrameScaler.Setup(scrollingFrame, {
	Axis = "Y",
	ExtraPadding = Vector2.new(0, 12),
	PreserveCanvasPosition = true,
})

task.delay(2, function()
	ScrollFrameScaler.Focus(scrollingFrame, targetItem, {
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Force = true,
	})
end)
```

## 📝 Notes

- The module sets `AutomaticCanvasSize` to `Enum.AutomaticSize.None` while managing a frame.
- The previous `AutomaticCanvasSize` value is restored during cleanup.
- A `ScrollingFrame` should generally contain only one supported layout object.
- Layout objects and `UIPadding` should be direct children of the managed frame.
- Direct content measurement includes direct `GuiObject` children rather than every nested descendant.
- Canvas dimensions are rounded up to whole pixels.
- The final canvas size is prevented from becoming negative.
- The module is intended to be required and used from client-side UI code.

## License

Use and modify the module according to the license included with the release.

---

made with ❤️ by biotoxin495
