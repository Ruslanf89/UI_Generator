# Windows user guide

This guide takes you from downloading UI Forge to exporting your first HUD.
You do not need programming knowledge to design and export a HUD. Connecting
that HUD to a running game is covered in the [Godot guide](godot-guide.md).

[Back to the project home page](../README.md)

## 1. Choose the right download

| Download | What you receive | How you open it |
| --- | --- | --- |
| `UIForge-windows-x86_64.zip` in a release's **Assets** | The packaged desktop app | Extract it, then double-click `UIForge.exe` |
| **Code → Download ZIP** or **Source code (zip)** | The Godot source project | Import `project.godot` into Godot, then press F5 |

For the packaged app, open
[UI Forge Releases](https://github.com/Ruslanf89/UI_Generator/releases).
Choose a release that includes `UIForge-windows-x86_64.zip` under **Assets**.
Prereleases are development previews. If no Windows ZIP is listed, follow
[Run UI Forge from source](godot-guide.md#run-ui-forge-from-source).

The packaged app targets **Windows x64** and requires **OpenGL 3.3-compatible
graphics**. Its smallest window is **1120 × 900**. The runtime is included;
installing Godot, Python, Git, or export templates is unnecessary for this route.
Internet access is needed for downloading, but generation runs locally.

## 2. Extract the app

1. Wait for `UIForge-windows-x86_64.zip` to finish downloading.
2. Open **File Explorer → Downloads** and locate that ZIP.
3. Right-click it and choose **Extract All…**.
4. Choose a writable destination, for example
   `C:\Users\YourName\Documents\UIForgeApp`, and click **Extract**.
   Replace `YourName` with your Windows account name.
5. Open the extracted folder and then the **UIForge** folder inside it.

You should see these files, along with the documentation and license notices:

```text
UIForge/
  UIForge.exe
  UIForge.pck
  README.txt
  docs/
    windows-guide.md
    godot-guide.md
    examples/
      health_demo.gd
```

Run the app from the **extracted folder**. Opening the executable while browsing
inside the ZIP may leave its companion files unavailable.

## 3. Open the app

1. Double-click **UIForge.exe**.
2. Leave **UIForge.pck** in the same folder. It contains the app's scenes,
   scripts, and visual resources.
3. Wait for the **UI FORGE** window. It opens with an FPS/Military design and
   three variations already generated.

There is no installer or sign-in screen. To create a desktop shortcut,
right-click `UIForge.exe` and use **Show more options → Send to → Desktop
(create shortcut)**. The shortcut should point to the executable in its
extracted folder. Keep the whole app folder together when moving it.

## 4. Understand the window

![The UI Forge window](screenshot.png)

| Area | What it controls |
| --- | --- |
| **Design Brief**, on the left | Game type, visual style, components, target resolution, and Generate |
| Large central preview | The selected HUD variation over an illustrative background |
| Three thumbnails below the preview | Balanced, Compact, and Cinematic layout options |
| **The Finishing Touches**, on the right | Accent color, HUD size, and example health/mana values |
| **New UI**, at the top | Resets the brief and customizations to the initial FPS/Military design |
| **Export to Godot**, at the top | Saves the selected design into a new folder |
| Status line, at the bottom | Generation messages, export location, and errors |

## 5. Create a first FPS HUD

1. Click **New UI** to start with the default design. Export any design you
   want to keep before resetting it.
2. Under **01 Game Type**, select **FPS**.
3. Under **02 Visual Style**, click **Military**.
4. Under **03 Components**, keep Health bar, Armor bar, Minimap, Weapon & ammo,
   Crosshair, and Objective tracker selected. Scroll inside this list to find
   the lower options. Untick components you do not want.
5. Leave **Target Resolution** at **1920 × 1080 / Full HD**.
6. Click **Generate 3 variations**.
7. Click **01 Vanguard**, **02 Recon**, or **03 Sentinel** below the thumbnails
   to compare the layouts. Clicking a thumbnail also selects that variation.
8. Choose the variation you prefer. The large preview shows the design that
   will be exported.

Other genres select different starting components. For example, choose **RPG**
to start with health, mana, minimap, abilities, and objectives. Component choices
remain editable for every genre. At least one component must be selected.

## 6. Customize the selected design

1. Click the color swatch under **Accent Color** and choose a color.
2. Move **HUD Size** to change component sizes between 85% and 110%.
3. If Health bar is included, move the **Health** slider to see it change.
4. If Mana bar is included, move the **Mana** slider to see it change.
   A faded slider means that component is not in the generated HUD.

Accent, size, health, and mana changes appear immediately and carry into the
export. They apply to all three generated variations.

Changing game type, style, components, or resolution leaves a **Changes pending**
message. Click **Generate** to apply those changes. Generate resets accent,
size, and sample values to the chosen style's defaults, so refine those settings
after generation. Export always uses the design currently visible in the preview.

Keyboard shortcuts: **Ctrl+G** generates; **Ctrl+E** opens export.

## 7. Export your HUD

1. In File Explorer, create a folder such as
   `C:\Users\YourName\Documents\UIForgeExports`.
2. In UI Forge, select the variation you want to use.
3. Click **Export to Godot**.
4. In the folder chooser, navigate to `Documents\UIForgeExports` and select
   that folder as the destination. The destination must already exist.
5. Wait for the **Your HUD is ready** message. It shows the full output path.
6. Open that path in File Explorer.

For the FPS/Military/Balanced example, the app creates a folder like this:

```text
UIForgeExports/
  uiforge_fps_military_balanced/
    hud.tscn
    hud_theme.tres
    preset.json
    README.md
```

Repeated exports create new folders with suffixes such as `_2`; they do not
overwrite previous exports.

| Exported file | How you use it |
| --- | --- |
| `hud.tscn` | The HUD scene you add to your game in Godot |
| `hud_theme.tres` | Shared styling; keep it beside `hud.tscn` |
| `preset.json` | A record of your design choices and sample values |
| `README.md` | Instructions included with this particular HUD |

Continue with [Add an exported HUD to your game](godot-guide.md#add-an-exported-hud-to-your-game).

## 8. Keep your work

Export before closing the app or clicking **New UI**. Designs are currently
held in memory, and reopening exported presets in UI Forge is not implemented.
You can keep editing the exported scene and theme directly in Godot.

The minimap, weapon values, timers, and ability slots contain example data.
They become functional when connected to your game's code. The central preview
background is illustrative and is not exported. Generation uses local templates.

## Troubleshooting

| What you see | What to do |
| --- | --- |
| No `UIForge.exe` in the download | You may have downloaded the source ZIP. Follow the Godot source-project guide, or choose the Windows app ZIP under a release's Assets. |
| Godot Project Manager appears instead of UI Forge | Extract the complete app ZIP again and keep the matching `UIForge.exe` and `UIForge.pck` together. |
| A missing resource/pack error, or the app closes immediately | Run from the extracted folder, confirm the PCK exists, and extract a fresh complete copy if a file is missing. |
| A graphics/OpenGL error | Check that the PC supports OpenGL 3.3 and install the graphics driver supplied by the GPU or PC manufacturer. |
| Bottom controls are off screen | Maximize the app. Windows display resolution and scaling must leave enough room for the 1120 × 900 minimum window. Check **Settings → System → Display**. |
| Mana or health slider is faded | Select that component on the left and click Generate. |
| Changing style does not change the preview | Click Generate to apply the pending brief. |
| Export fails | Choose an existing writable folder, such as a folder in Documents. Read the status line for the specific error. |
| Map or ammo is not changing in a game | Those are sample controls; follow the Godot integration guide and connect gameplay data. |

To report a problem, open a
[GitHub issue](https://github.com/Ruslanf89/UI_Generator/issues) with your Windows
version, app version or download filename, exact error text, and steps that
caused it. Packaging was checked on Linux; native Windows launch has not yet
been validated in this project.
