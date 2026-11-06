#!/usr/bin/env python3
"""Packs the mod into dist/<Name>-<version>.pk3.

Usage: python build.py
The .pk3 is a zip of everything inside src/, with the version from VERSION.
"""
import os
import zipfile

NAME = "VisualKeybinds"

root = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(root, "src")
with open(os.path.join(root, "VERSION"), encoding="utf-8") as f:
    version = f.read().strip()

os.makedirs(os.path.join(root, "dist"), exist_ok=True)
out = os.path.join(root, "dist", f"{NAME}-{version}.pk3")

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for folder, _, files in os.walk(src):
        for name in sorted(files):
            path = os.path.join(folder, name)
            z.write(path, os.path.relpath(path, src).replace(os.sep, "/"))

print(out)
