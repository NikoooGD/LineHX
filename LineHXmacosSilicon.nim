import os, osproc, strutils, times

proc run(cmd: string): int =
  echo "→ ", cmd
  execCmd(cmd)

proc backup(p: string) =
  if fileExists(p) or dirExists(p):
    let b = p & ".bak-" & $getTime().toUnix()
    echo "Backup ", p, " -> ", b
    if fileExists(p): moveFile(p, b) else: moveDir(p, b)

let cfgDir = expandTilde("~/.config/helix")

echo "LineHX macOS Installer"
echo "Target: ", cfgDir
echo "Continue? y/n"
if readLine(stdin).strip().toLower()!= "y": quit("Aborted", 0)

echo "\n1. Clean 2. Addon 3. Cancel"
let isClean = readLine(stdin).strip() == "1"

# ── Check hx is steel ──
if findExe("hx")!= "":
  let isSteel = execCmdEx("hx --version 2>&1").output.toLower().contains("steel") or execCmdEx("hx --health 2>&1").output.contains("steel")
  echo "[✓] hx found: ", findExe("hx")
  if not isSteel:
    echo "[!] Warning: you have vanilla helix from brew, not helix-steel"
    echo " Plugins need steel. Installing steel hx..."
    discard run("cargo install --git https://github.com/mattwparas/helix --branch steel-event-system helix-term --bin hx --locked")
else:
  echo "[!] hx not found"
  discard run("cargo install --git https://github.com/mattwparas/helix --branch steel-event-system helix-term --bin hx --locked")

# ── FIXED: forge install ──
if findExe("forge") == "":
  echo "Installing forge..."
  if run("cargo install --git https://github.com/nik-rev/forge --locked")!= 0:
    # fallback old name
    discard run("cargo install forge --locked")

for url in [
  "https://github.com/Ra77a3l3-jar/forest.hx.git",
  "https://github.com/gllms/streal.hx.git",
  "https://github.com/Ra77a3l3-jar/trail.hx.git"
]:
  discard run("forge pkg install --git " & url)

createDir(cfgDir)
if isClean:
  backup(cfgDir / "config.toml")
  backup(cfgDir / "init.scm")

const configToml = """theme = "astrodark"
[editor]
line-number = "absolute"
cursorline = true
"""

const initScm = """(require "forest/forest.scm")
(forest-configure! 'left)
(require "streal/streal.scm")
(require "trail/trail.scm")
"""

if isClean or not fileExists(cfgDir / "config.toml"):
  writeFile(cfgDir / "config.toml", configToml)
if isClean or not fileExists(cfgDir / "init.scm"):
  writeFile(cfgDir / "init.scm", initScm)

echo "\nDone. Run hx"
