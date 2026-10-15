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

GUIDE = """UI Forge — Windows x64 portable development build

Extract the entire ZIP, open the UIForge folder, and double-click UIForge.exe.
Keep UIForge.pck beside UIForge.exe. No Godot installation, account, or API key
is needed. Requires Windows x64 and OpenGL 3.3-compatible graphics.

Choose a game type, visual style, and components. Click Generate 3 variations,
select a preview, then customize the accent, size, and health/mana values.
Export to Godot creates a new folder with an editable scene, shared theme,
preset settings, and instructions for connecting your game logic.
Copy the whole export folder into your Godot 4.6+ game project.

Generation uses local templates. Map contents, ammo, timers, and abilities
contain example data; your game supplies their behavior.
Designs are held in memory; export before closing the app.

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
        sums = "".join(f"{digest(path, 'sha256')}  {path.name}\n" for path in sorted(package.iterdir()))
        (package / "SHA256SUMS.txt").write_text(sums, encoding="utf-8")
        staged_zip = stage / target_zip.name
        with zipfile.ZipFile(staged_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for path in sorted(package.iterdir()):
                archive.write(path, "UIForge/" + path.name)
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
