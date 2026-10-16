#!/usr/bin/env python3
"""Build a portable Windows development app using a verified official runtime."""

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile


VERSION = "4.6.3"
ARCHIVE = f"Godot_v{VERSION}-stable_win64.exe.zip"
EXECUTABLE = f"Godot_v{VERSION}-stable_win64.exe"
URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/{ARCHIVE}"
# Official 4.6.3 SHA512-SUMS.txt from the same Godot release, checked during setup.
SHA512 = (
    "d44ea7ef5bab754cacd49d581b6062836b2eea12a82e1d183aebfad9cd8c7db2bd825"
    "13337bd657d6d2d5c04d46239c0570b029faf1343e81e8a2fa7b85dd83b"
)

GUIDE = """UI Forge — Windows x64 desktop app

OPEN THE APP
1. Right-click the downloaded ZIP in File Explorer and choose Extract All.
2. Open the extracted folder, then its UIForge folder.
3. Double-click UIForge.exe. Keep UIForge.pck beside it.
4. The UI FORGE window opens with an FPS/Military design and three variations.

Run from the extracted folder, rather than from inside the ZIP. This app includes
its runtime, so installing Godot, Python, or Git is unnecessary. It requires a
Windows x64 PC with OpenGL 3.3 graphics and space for a 1120 x 900 window.

CREATE YOUR FIRST HUD
1. Click New UI, select FPS under Game Type, and select Military under Style.
2. Tick the components you want. Scroll the component list to see all options.
3. Choose a target resolution and click Generate 3 variations.
4. Click a variation's thumbnail or name to select it in the large preview.
5. Change Accent Color and HUD Size on the right. Health/mana sliders are active
   when those components are included. These changes appear immediately.
6. Click and drag a component in the large preview to move it. Arrange Elements
   offers an 8 px grid and layout reset. Arrows nudge 1 px; Shift+arrow nudges 10.
   Ctrl+Z undoes movement; Ctrl+Shift+Z or Ctrl+Y redoes it. Each variation keeps
   its own positions.
7. Under Offline Frame Art, choose a detail and click Generate art for new
   procedural panel frames. Scroll the right panel to reach its tools. Clear
   removes artwork while preserving positions. No AI service or key is needed.

Changing genre, style, components, or resolution requires Generate to apply.
Generate resets color, size, sample values, moved positions, and artwork. Apply those
customizations after generating. Export always uses the visible design.

EXPORT AND USE IN GODOT
1. Create a folder in Documents, for example UIForgeExports.
2. Click Export to Godot and select that existing folder.
3. Read the success message for the new output subfolder's path.
4. Keep all four output files together: hud.tscn, hud_theme.tres, preset.json,
   and README.md. If an art folder is present, copy it too. Repeated exports
   create separate folders. The scene keeps the positions from your preview.
5. Open your game's Godot 4.6+ project. Copy the whole exported folder into it.
6. Add a CanvasLayer under the game scene's root. Drag hud.tscn onto it.
7. Save and run the game scene. Connect the controls to your gameplay values.

DETAILED GUIDES INCLUDED IN THIS DOWNLOAD
docs/windows-guide.md: download choices, launch steps, first HUD, and fixes.
docs/godot-guide.md: running the source project, importing a HUD, and a health demo.
docs/examples/health_demo.gd: a complete Space-to-damage, R-to-heal example.
Open .md files in a text editor, or read formatted versions online:
https://github.com/Ruslanf89/UI_Generator/blob/main/docs/windows-guide.md
https://github.com/Ruslanf89/UI_Generator/blob/main/docs/godot-guide.md

KEEP YOUR WORK
Designs are held in memory. Export before closing the app or clicking New UI.
Loading exported presets back into UI Forge is not implemented. Generated
controls can be edited directly in Godot. Maps, ammo, timers, and ability slots
use example data; your game supplies behavior. Generation uses local templates.

This development package uses the full official Godot 4.6.3 Windows engine.
The engine archive was verified against the published SHA-512 checksum.
A smaller production release can be made with Godot's official export templates.
Packaging and project checks were run on Linux. Windows execution has not
been validated in this environment.

Godot engine: https://godotengine.org/
License: see GODOT_LICENSE.txt and GODOT_COPYRIGHT.txt.
SHA256SUMS.txt records checksums for the packaged files.
"""


def digest(path: Path, algorithm: str) -> str:
    result = hashlib.new(algorithm)
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def verify_runtime(archive: Path) -> None:
    if digest(archive, "sha512") != SHA512:
        raise RuntimeError(
            f"Runtime checksum mismatch: {archive}. "
            "The archive was not used. Obtain the official Godot 4.6.3 Windows x64 ZIP."
        )


def download_runtime(cache: Path) -> Path:
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / ARCHIVE
    if not archive.exists():
        temporary = archive.with_suffix(".download")
        print(f"Downloading official Windows runtime: {URL}", flush=True)
        try:
            # urllib preserves normal HTTPS certificate validation and proxy routing.
            with urllib.request.urlopen(URL, timeout=120) as response:
                with temporary.open("wb") as target:
                    shutil.copyfileobj(response, target)
            verify_runtime(temporary)
            temporary.replace(archive)
        finally:
            temporary.unlink(missing_ok=True)
    verify_runtime(archive)
    return archive


def verify_pe(path: Path) -> None:
    with path.open("rb") as executable:
        if executable.read(2) != b"MZ":
            raise RuntimeError("The runtime is not a Windows executable.")
        executable.seek(0x3C)
        offset = struct.unpack("<I", executable.read(4))[0]
        executable.seek(offset)
        if executable.read(6) != b"PE\0\0\x64\x86":
            raise RuntimeError("The runtime is not a Windows x86_64 PE executable.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--runtime-zip", type=Path, help="Use an already downloaded official Windows runtime ZIP.")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    build = repo / "build"
    build.mkdir(exist_ok=True)

    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not version.startswith(VERSION + "."):
        raise RuntimeError(f"Packaging requires Godot {VERSION}, found {version}.")

    runtime = args.runtime_zip or download_runtime(build / "cache")
    verify_runtime(runtime)
    print("Official runtime SHA-512 verified.", flush=True)

    target_zip = build / "UIForge-windows-x86_64.zip"
    # Stage each run independently; failures cannot replace a previous good build.
    with tempfile.TemporaryDirectory(prefix=".windows-", dir=build) as staging:
        stage = Path(staging)
        package = stage / "UIForge"
        package.mkdir()
        pack = package / "UIForge.pck"
        subprocess.run(
            [args.godot, "--headless", "--path", str(repo), "--export-pack", "Windows", str(pack)],
            check=True,
        )
        if not pack.is_file() or pack.stat().st_size < 512:
            raise RuntimeError("Godot did not produce an application resource pack.")
        with zipfile.ZipFile(runtime) as archive:
            with archive.open(EXECUTABLE) as source:
                with (package / "UIForge.exe").open("wb") as destination:
                    shutil.copyfileobj(source, destination)
        verify_pe(package / "UIForge.exe")
        for name in ("LICENSE", "COPYRIGHT"):
            shutil.copyfile(repo / "licenses" / "godot" / f"{name}.txt", package / f"GODOT_{name}.txt")
        (package / "README.txt").write_text(GUIDE, encoding="utf-8")
        guides = (
            "README.md", "docs/windows-guide.md", "docs/godot-guide.md",
            "docs/development.md", "docs/examples/health_demo.gd", "docs/screenshot.png",
        )
        for relative in guides:
            destination = package / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(repo / relative, destination)
        files = sorted(path for path in package.rglob("*") if path.is_file())
        sums = "".join(
            f"{digest(path, 'sha256')}  {path.relative_to(package).as_posix()}\n"
            for path in files
        )
        (package / "SHA256SUMS.txt").write_text(sums, encoding="utf-8")
        staged_zip = stage / target_zip.name
        with zipfile.ZipFile(staged_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for path in sorted(package.rglob("*")):
                if path.is_file():
                    archive.write(path, "UIForge/" + path.relative_to(package).as_posix())
        with zipfile.ZipFile(staged_zip) as archive:
            if archive.testzip() is not None:
                raise RuntimeError("The generated Windows ZIP failed its integrity check.")
        staged_zip.replace(target_zip)
    print(f"Portable Windows build: {target_zip}")
    print("Windows execution must still be checked on a Windows desktop.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, KeyError, zipfile.BadZipFile, subprocess.CalledProcessError, urllib.error.URLError) as error:
        print(f"Packaging failed: {error}", file=sys.stderr)
        sys.exit(1)
