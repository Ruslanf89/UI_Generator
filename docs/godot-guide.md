# Godot user guide

Use this guide to **run UI Forge from its source project**, or to **add an
exported HUD or fantasy kit to your own game**. Run the designer in the UI Forge
project, and add its exported files to your game project.

- [Run UI Forge from source](#run-ui-forge-from-source)
- [Add an exported HUD to your game](#add-an-exported-hud-to-your-game)
- [Add an exported fantasy kit to your game](#add-an-exported-fantasy-kit-to-your-game)
- [Connect a health bar and test it](#connect-a-health-bar-and-test-it)
- [Customize the scene in Godot](#customize-the-scene-in-godot)
- [Edit the UI Forge designer itself](#edit-the-ui-forge-designer-itself)
- [Troubleshooting](#troubleshooting)

[Back to the project home page](../README.md)

## Run UI Forge from source

This route works when a packaged Windows download is unavailable and lets you
edit the designer itself. A packaged UI Forge app includes its runtime; the
Godot editor is needed for this source route or for developing your game.

### 1. Get the Godot editor

1. Open the [official Godot Windows download page](https://godotengine.org/download/windows/).
2. Get the **Standard Windows x64** edition of **Godot 4.6.3**, the tested
   version. The [Godot archive](https://godotengine.org/download/archive/)
   provides previous versions if the main page shows a newer release.
3. Right-click the downloaded Godot ZIP in File Explorer and choose **Extract All…**.
4. Open the extracted folder. Double-click the editor executable, such as
   `Godot_v4.6.3-stable_win64.exe`.
5. The **Godot Project Manager** opens. Keep it open for the import step below.

This project uses GDScript. Python, Git, the .NET SDK, and Godot export templates
are not required to open and run it in the editor. Its Compatibility renderer
requires OpenGL 3.3-compatible graphics.

### 2. Download the UI Forge project

1. Open [Ruslanf89/UI_Generator](https://github.com/Ruslanf89/UI_Generator).
2. Make sure the selected branch is **main**.
3. Click the green **Code** button and choose **Download ZIP**.
4. Right-click the ZIP in File Explorer and choose **Extract All…**.
5. Open the extracted folder, usually named **UI_Generator-main**.
6. Find **project.godot** directly inside it, alongside `scenes`, `scripts`,
   and `assets`. If another folder is inside the first one, open it until
   you find `project.godot`.

### 3. Import and run the designer

1. In **Godot Project Manager**, click **Import**.
2. Browse to the extracted `UI_Generator-main` folder.
3. Select **project.godot**, then choose **Import & Edit**.
4. Wait for the import. Godot creates a `.godot` cache folder automatically.
5. Press **F5**, or click **Run Project** at the top right.
6. UI Forge opens with three FPS/Military variations. The designer can appear
   in Godot's embedded game view or in a separate window, depending on editor
   settings. Use the embedded view's detach control for a separate window.
7. Press **F8** or the editor's **Stop** button to stop the app.

The project's main scene is already configured as `scenes/main.tscn`. If asked
to choose a main scene, select that file. You can also open it in the FileSystem
dock and press **F6** to run only that scene.

Follow [Create a first FPS HUD](windows-guide.md#5-create-a-first-fps-hud), then
export your design, or choose [Create a fantasy UI kit](windows-guide.md#create-a-fantasy-ui-kit).
Running the designer does not automatically add controls to a different game
project.

## Add an exported HUD to your game

Use **Godot 4.6+**, tested with 4.6.3. These steps work with 2D and 3D games;
the generated interface uses 2D Control nodes over your game view.

### 1. Export a design with a health bar

In UI Forge, include **Health bar**, click **Generate 3 variations**, select a
variation, and click **Export to Godot**. Choose an existing destination folder.
The app creates a folder such as `uiforge_fps_military_balanced`:

```text
uiforge_fps_military_balanced/
  hud.tscn
  hud_theme.tres
  preset.json
  README.md
  art/                          # optional generated panel PNGs
```

### 2. Copy the whole folder into your game

1. Open **your game's project** in Godot.
2. In its FileSystem dock, right-click **res://** and choose **Open in File Manager**.
   This opens the game folder containing its own `project.godot`.
3. In File Explorer, create a folder named **ui** inside that game folder.
4. Copy the complete exported folder into **ui**. Keep `hud.tscn` and
   `hud_theme.tres` together.
   If the export has an **art** folder, copy it too and wait for Godot to import
   its PNG files.
5. Return to Godot and wait for the files to appear in the FileSystem dock.

For example:

```text
MyGame/                          <- your game's folder
  project.godot
  ui/
    uiforge_fps_military_balanced/
      hud.tscn
      hud_theme.tres
      preset.json
      README.md
      art/                      # included when frame art is enabled
```

The scene's Godot path is now
`res://ui/uiforge_fps_military_balanced/hud.tscn`. The `res://` prefix means
"inside this Godot project"; it is not a Windows folder name to create.

### 3. Add the HUD to a game scene

1. Open the scene containing your gameplay, for example `game.tscn`.
2. Select its root node in the Scene dock.
3. Click **Add Child Node** (the **+** button), search for **CanvasLayer**,
   and create it. Keep its name **CanvasLayer** for the example below.
4. If your game already has a dedicated HUD CanvasLayer, you can use it;
   adjust the example's paths to match its name.
5. Drag `hud.tscn` from the FileSystem dock onto **CanvasLayer** in the Scene dock.
6. The new instance should be named **HUD**. Keep that name for the example.
7. Save the game scene with **Ctrl+S**.
8. Press **F6** to run this scene. The HUD should appear over the game view.

Your Scene dock should have this structure:

```text
Game                            <- your scene root; Node2D or Node3D is fine
  ...your existing game nodes...
  CanvasLayer
    HUD                         <- instance of exported hud.tscn
```

CanvasLayer keeps the HUD in screen space while the camera moves. The export
is transparent, so UI Forge's illustrative background will not appear in your
game. The minimap shows example geometry until you replace it with your map.
Custom component positions and individual scales from the designer are already
applied. No dragging or resizing script is needed in your game to keep the layout.

**For a new test project:** in Godot Project Manager, click **Create**, choose
an empty folder and the Compatibility renderer, then open the project. Choose
**2D Scene**, rename its root **Game**, and save it as `game.tscn`. Copy your
export into this project and follow the CanvasLayer steps above. Press F6 for
the test scene; F5 may ask you to select it as the main scene.

## Add an exported fantasy kit to your game

### 1. Generate and export the kit

In UI Forge, select **Fantasy UI kit** at the top of **Design Brief**. Choose
**Illustrated fantasy** or **Medieval pixel**, a material and decoration level,
then click **Generate complete kit**. Arrange components on the **Menu**,
**HUD**, and **Components** pages. Select a piece and use **Regenerate selected**
to change only its artwork; **Ctrl+Z** restores the previous version.

Click **Export to Godot** and choose an existing writable folder. Every export
contains all three pages, regardless of the page visible in the designer:

```text
uiforge_kit_illustrated_fantasy/
  menu.tscn
  hud.tscn
  components.tscn
  kit_theme.tres
  art/
    ...generated PNGs...
  preset.json
  README.md
```

### 2. Copy and use the scenes

1. Open your game's Godot project and use **FileSystem → right-click res:// →
   Open in File Manager** to find its folder.
2. Create a `ui` folder in your game and copy the **entire exported kit folder**
   into it. Keep the three scenes, shared theme, and complete `art/` folder
   together. Wait for Godot to finish importing the PNGs.
3. For a gameplay overlay, open your game scene, add a **CanvasLayer**, and
   drag the kit's **hud.tscn** onto it. The instance is named **HUD**, and the
   health example below uses the same paths for both HUD and kit exports.
4. For the menu, double-click **menu.tscn** in the FileSystem dock to inspect
   it. Press **F6** to run the menu by itself, or instance it under a CanvasLayer
   in your own menu scene.
5. Open **components.tscn** to inspect the matching buttons, inventory sample,
   panels, bars, and icons. Duplicate the controls you need into your own scenes;
   keep their theme and image resources accessible.

These are native Godot Control scenes. They need no UI Forge scripts, plugin,
or connection to the generator. The preview scenery is not exported. Each
page retains the positions and sizes you set in the designer.

### 3. Edit labels and connect menu buttons

Open `menu.tscn` directly to edit the exported scene, or right-click its instance
in another scene and enable **Editable Children**. Expand:

```text
Menu
  Canvas
    Viewport
      Design
        Elements
          TitleBanner
            Title
            Subtitle
          MenuPanel
          ContinueButton
          NewJourneyButton
          SettingsButton
          ExitButton
          CharacterPanel
```

Select a Button and edit its **Text** in the Inspector, or select a Label such
as `TitleBanner/Title`. Buttons already have normal, hover, pressed, disabled,
and focus artwork. The designer uses clicks to select and arrange controls;
run the exported menu to try its interactive states.

Menu actions are left to your game. For a simple exit-button test:

1. Open the exported **menu.tscn** and attach a GDScript to its **Menu** root.
2. Select **ExitButton** under `Canvas/Viewport/Design/Elements`.
3. In the **Node → Signals** dock, double-click **pressed()**.
4. Choose **Menu** as the receiver and click **Connect**.
5. Replace the generated function's `pass` with `get_tree().quit()`.
6. Save the script/scene, press **F6**, and click **Exit game**. This stops the
   test menu.

Use the same signal workflow to connect Continue, New journey, Settings, and
ability buttons to your game code. Inventory items, currency, quests, and
minimap landmarks are samples; the kit does not provide save data, inventory
behavior, or a quest system.

### 4. Change the kit artwork

`kit_theme.tres` supplies shared fonts and colors. Individual controls have
**Theme Overrides** containing their generated artwork:

| Control | Where its artwork lives |
| --- | --- |
| Panel or banner | **Theme Overrides → Styles → Panel**, a StyleBoxTexture |
| Button | **Theme Overrides → Styles**, with normal/hover/pressed/disabled/focus StyleBoxTexture resources |
| Health or mana ProgressBar | **Theme Overrides → Styles → Background / Fill** |
| Icon | A TextureRect's **Texture** property |

Expand a StyleBoxTexture to inspect or replace its texture. Keep every PNG in
`art/`: some are only shown during button interaction. Changing a PNG outside
Godot updates the controls that reference it after reimport. Labels, button
text, and ProgressBar values stay editable independently of the artwork.

All pages use a transparent **1280 × 720** design canvas with uniform scaling.
**Medieval pixel** preserves nearest filtering for images. Fractional scaling
can make pixels uneven; use whole-number viewport scaling when a strict pixel
grid is important for your game. The selected target resolution is recorded in
the export; it does not change your game's Project Settings.

`preset.json` records the kit seed, material, decoration, individual component
seeds, positions, and scales. It is a record of the design; importing it back
into UI Forge is not implemented. Export before generating a new kit or closing
the designer. Subsequent exports create separate folders and do not merge
your Godot scene edits.

## Connect a health bar and test it

Your game must update both the ProgressBar and its number Label. This example
starts at 100 health, removes 10 when you press Space, and restores health with R.
It works with `hud.tscn` from either a HUD layout export or a fantasy kit export.

### 1. Attach a script

1. Use the new **Node2D Game** test scene above, with Health bar included in
   the exported HUD.
2. Select **Game** and click **Attach Script**.
3. Choose **GDScript**, save it as `health_demo.gd`, and create it.
4. Replace its contents with the code below. The complete
   [example file](examples/health_demo.gd) is also available.
5. Save the script and scene.

```gdscript
extends Node2D

@onready var health_bar: ProgressBar = $CanvasLayer/HUD/Canvas/Viewport/Design/Elements/Health/Value
@onready var health_text: Label = $CanvasLayer/HUD/Canvas/Viewport/Design/Elements/Health/Amount

var maximum_health: float = 100.0
var current_health: float = 100.0

func _ready() -> void:
    update_health_display()

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    if not event.pressed or event.echo:
        return
    if event.keycode == KEY_SPACE:
        current_health = maxf(0.0, current_health - 10.0)
    elif event.keycode == KEY_R:
        current_health = maximum_health
    else:
        return
    update_health_display()
    get_viewport().set_input_as_handled()

func update_health_display() -> void:
    health_bar.max_value = maximum_health
    health_bar.value = current_health
    health_text.text = "%d / %d" % [current_health, maximum_health]
```

The script belongs on **Game**, with a child **CanvasLayer** containing **HUD**.
For a Node3D root, use `extends Node3D` instead. If your game root already has
gameplay code, integrate the relevant variables and update calls into that
script rather than replacing it with this demo.

### 2. Run the test

1. Press **F6** to run `game.tscn`, then click the game view for keyboard focus.
2. The bar and label should start at **100 / 100**.
3. Press **Space** once. They should change to **90 / 100**.
4. Keep pressing Space. Health should reach zero and stay there.
5. Press **R** to restore **100 / 100**.

In a real game, call the display-update function after damage, healing, or
loading a saved health value. Use your player or health system as the source
of truth.

## Customize the scene in Godot

Right-click **HUD** in the Scene dock and enable **Editable Children** to inspect
and override its controls in your game scene. Expand:

```text
HUD
  Canvas
    Viewport
      Design
        Elements
          Health
            Title
            Amount
            Value
          ...other selected components...
```

| Task | What to edit |
| --- | --- |
| Change a text label | Select a Label such as `Health/Title`, then edit **Text** in the Inspector. |
| Change shared styling | Select `Elements`, find **Theme**, and edit `hud_theme.tres`. Changes affect controls using the resource. |
| Style one control | Use its **Theme Overrides**. Some labels and mana/armor fills already have overrides. |
| Move a component | Edit its Control position in the exported `hud.tscn`, or override the child in your game scene. |
| Update health or mana | Set its ProgressBar's `value`/`max_value` and update its `Amount` Label. |
| Make a real minimap | Replace sample nodes in `Minimap/MapContent` with your map or camera-driven UI. |
| Replace a generated material/frame | Select the component's `Art` TextureRect and change **Texture**, or edit its PNG under the export's `art/` folder. The surface and frame are composited in one PNG; labels and bars stay separate. |
| Change material opacity | Select its `Art` TextureRect and change **Modulate** alpha under CanvasItem visibility. |

These paths are relative to **Elements**. Only selected components exist:

| Component | Useful node paths |
| --- | --- |
| Health | `Health/Value`, `Health/Amount` |
| Mana | `Mana/Value`, `Mana/Amount` |
| Armor | `Armor/Value`, `Armor/Amount` |
| Weapon | `Weapon/Ammo`, `Weapon/Reserve`, `Weapon/Mode` |
| Map | `Minimap/MapContent` |
| Objective | `Objective/Description` |
| Racing | `Speed/Value`, `Speed/Unit`, `Lap/Time` |
| Resources | `Resources/Values` |
| Abilities | `Abilities/Slot1` through `Abilities/Slot4` |
| Squad | `Squad` |

The HUD uses a **1280 × 720** design canvas. Its transparent SubViewport scales
uniformly to fit the game viewport, preserving 16:9 proportions. Other aspect
ratios leave unused space around the HUD. The target resolution chosen in UI
Forge is recorded in the export; it does not change your game's Project Settings.
Set your game window size under **Project → Project Settings → Display → Window**.
Re-exporting creates a separate folder and does not merge edits into a HUD you
already customized in Godot.

## Troubleshooting

| What you see | What to check |
| --- | --- |
| `project.godot` is missing | Extract the source ZIP and open its inner `UI_Generator-main` folder. A packaged app ZIP contains EXE/PCK files instead of the source project. |
| A main-scene prompt in UI Forge | Choose `res://scenes/main.tscn`, then press F5. |
| Missing theme or unstyled HUD | Copy the entire exported folder; keep the scene and theme together. |
| Missing frame texture | Copy the export's `art/` folder too and let Godot finish importing its PNGs. |
| `Node not found: CanvasLayer/HUD/...` | Check the exact node names, attach the example script to the parent Game node, and confirm Health bar was selected before export. |
| Health stays at the sample value | Attach the script to the active test scene, run it with F6, and click the game view before pressing Space. |
| The bar moves but the number does not | Update both `Health/Value` and `Health/Amount`. |
| Node2D script incompatibility | Use the Node2D test scene, or change `extends` to match your actual root type. |
| No background in the exported HUD | The HUD is transparent. Add it to your game scene to see the game behind it. |
| A theme edit has no effect on an element | Inspect that control's Theme Overrides. |
| A kit button has no game action | Connect its native `pressed` signal to a script in your game. The exported scenes include styling and sample text, not menu/gameplay logic. |
| Kit button hover/pressed art is missing | Copy the entire `art/` folder, including PNGs that are not visible in the normal state. |
| Medieval pixel artwork looks uneven at some window sizes | Keep nearest filtering and use whole-number game viewport scaling for a consistent pixel grid. |
| Different placement at another aspect ratio | The design preserves 16:9. Adjust viewport settings or edit the layout for your target ratio. |

## Edit the UI Forge designer itself

Use the **UI Forge source project**, rather than an exported kit or the packaged
EXE. Stop the running app with **F8** before editing its code.

The window is built in GDScript when the app runs. `scenes/main.tscn` contains
the root Control; most of the visible window will not appear as editable nodes
in Godot's 2D editor before running it.

1. In Godot's FileSystem dock, open **scripts/app.gd**.
2. Find `_sidebar()` to edit the left design controls, `_inspector()` for the
   right panel, `_center()` for previews, or `_header()` for the top bar.
3. Change a label, control, or layout value, then save with **Ctrl+S**.
4. Press **F5** to rebuild the window and test your change. Stop with **F8**
   before editing again. Export a design you want to keep before stopping.

| What you want to change | Source file |
| --- | --- |
| Designer window, controls, and actions | `scripts/app.gd` |
| Preview rendering, mouse selection, dragging, and resizing | `scripts/hud_preview.gd` |
| Fantasy kit scenes and native control layout | `scripts/kit_generator.gd` |
| Fantasy kit procedural shapes, surfaces, ornaments, and icons | `scripts/kit_art.gd` |
| Fantasy kit scene/theme/PNG export | `scripts/kit_exporter.gd` |
| Original HUD component layouts and themes | `scripts/hud_generator.gd` |
| Original HUD material textures and frames | `scripts/hud_art.gd` |
| Original HUD export | `scripts/hud_exporter.gd` |

Source changes affect the designer the next time it runs. They do not update
previous exports or an already packaged executable. Re-export a design to get
new generated controls, or rebuild the standalone app after source changes.
For checks and executable builds, see [Development and packaging](development.md).
