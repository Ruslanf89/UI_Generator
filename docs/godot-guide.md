# Godot user guide

Use this guide to **run UI Forge from its source project**, or to **add an
exported HUD to your own game**. Run the designer in the UI Forge project,
and add its exported HUD files to your game project.

- [Run UI Forge from source](#run-ui-forge-from-source)
- [Add an exported HUD to your game](#add-an-exported-hud-to-your-game)
- [Connect a health bar and test it](#connect-a-health-bar-and-test-it)
- [Customize the scene in Godot](#customize-the-scene-in-godot)
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
export your design. Running the designer does not automatically add a HUD to
a different game project.

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

## Connect a health bar and test it

Your game must update both the ProgressBar and its number Label. This example
starts at 100 health, removes 10 when you press Space, and restores health with R.

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
| Replace a generated frame | Select the component's `Art` TextureRect and change **Texture**, or edit its PNG under the export's `art/` folder. |
| Change frame opacity | Select its `Art` TextureRect and change **Modulate** alpha under CanvasItem visibility. |

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
| Different placement at another aspect ratio | The design preserves 16:9. Adjust viewport settings or edit the layout for your target ratio. |

For designer code changes or building an executable, see
[Development and packaging](development.md).
