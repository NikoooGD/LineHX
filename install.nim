# LineHX - unified installer for Arch / macOS / Windows
# Build:
#   Arch:   nim c -d:release -o:LineHX-arch-linux install.nim
#   macOS:  nim c -d:release --cpu:arm64 -o:LineHX-macos-m5 install.nim
#   Win:    nim c -d:mingw --os:windows --cpu:amd64 --gcc.exe:x86_64-w64-mingw32-gcc --gcc.linkerexe:x86_64-w64-mingw32-gcc -o:LineHX-windows.exe install.nim
# Run:
#   ./LineHX-arch-linux --obelisk --clean --confirm

import os, osproc, strutils, parseopt, times

const ConfigToml = staticRead("assets/config.toml")
const InitScm = staticRead("assets/init.scm")
const Plugins = staticRead("assets/plugins.txt")

var withObelisk = false
var cleanMode = false
var addonMode = false
var confirm = false
var verbose = false
var skipBuild = false

proc showHelp() =
  echo """
LineHX installer
  --obelisk    Install Obelisk.hx (Obsidian for Helix)
  --clean      Wipe ~/.config/helix and reinstall (backup first)
  --addon      Keep existing config, only add LineHX files
  --confirm    Skip prompts (assume yes)
  --verbose    Show full command output
  --skip-build Skip helix-steel build, only install config + plugins
  --help       Show this
"""
  quit(0)

for kind, key, val in getopt():
  case kind
  of cmdLongOption, cmdShortOption:
    case key
    of "obelisk": withObelisk = true
    of "clean": cleanMode = true
    of "addon": addonMode = true
    of "confirm", "y": confirm = true
    of "verbose", "v": verbose = true
    of "skip-build": skipBuild = true
    of "help", "h": showHelp()
    else: discard
  else: discard

if not cleanMode and not addonMode:
  cleanMode = true # default = clean

proc run(cmd: string): int =
  if verbose: echo ">> ", cmd
  else: echo ">> ", cmd.split(" ")[0..min(2, cmd.split(" ").high)].join(" "), "..."
  let code = execCmd(cmd)
  if code != 0:
    echo "WARN: command failed (", code, "): ", cmd
  return code

proc ask(msg: string): bool =
  if confirm: return true
  stdout.write(msg & " [y/N] ")
  let ans = readLine(stdin).strip().toLowerAscii()
  return ans == "y" or ans == "yes"

proc helixDir(): string =
  when defined(windows):
    return getEnv("APPDATA") / "helix"
  else:
    return getHomeDir() / ".config" / "helix"

proc cogsDir(): string =
  when defined(windows):
    return getEnv("APPDATA") / "steel" / "cogs"
  else:
    return getHomeDir() / ".local" / "share" / "steel" / "cogs"

proc backupConfig(dir: string) =
  if dirExists(dir):
    let ts = $now().toTime().toUnix()
    let bak = dir & ".bak-" & ts
    echo "Backing up ", dir, " -> ", bak
    moveDir(dir, bak)

# --- main ---
echo "=== LineHX installer ==="
when defined(windows): echo "OS: Windows"
elif defined(macosx): echo "OS: macOS"
else: echo "OS: Linux / Arch"

let hdir = helixDir()
let cdir = cogsDir()
echo "Helix config: ", hdir
echo "Cogs: ", cdir
echo "Mode: ", if cleanMode: "clean" else: "addon", " | Obelisk: ", withObelisk

if not ask("Install LineHX?"): quit(0)

# 1. Helix-steel
if not skipBuild:
  when defined(windows):
    echo "[1/4] Installing helix-steel via cargo..."
    discard run("cargo install --git https://github.com/mattwparas/helix --branch steel-event-system helix-term --bin hx")
  elif defined(macosx):
    echo "[1/4] Installing helix-steel via cargo xtask..."
    if not dirExists("/tmp/helix-steel"):
      discard run("git clone https://github.com/mattwparas/helix.git /tmp/helix-steel")
    discard run("cd /tmp/helix-steel && git switch steel-event-system && cargo xtask steel")
  else:
    echo "[1/4] Arch: checking helix-steel-git..."
    let qo = execProcess("pacman -Qo /usr/bin/hx 2>&1")
    if "helix-steel-git" notin qo:
      echo "Installing helix-steel-git via yay/paru..."
      if findExe("yay") != "":
        discard run("yay -S helix-steel-git --noconfirm")
      elif findExe("paru") != "":
        discard run("paru -S helix-steel-git --noconfirm")
      else:
        echo "No yay/paru found. Install manually: yay -S helix-steel-git"
        quit(1)
    else:
      echo "helix-steel-git already installed."

# 2. Forge
echo "[2/4] Installing forge..."
when defined(windows):
  discard run("cargo install --git https://github.com/nik-rev/forge forge")
else:
  if findExe("forge") == "":
    discard run("cargo install --git https://github.com/nik-rev/forge forge")
  else:
    echo "forge already installed."

# 3. Config
echo "[3/4] Installing config..."
if cleanMode:
  backupConfig(hdir)
createDir(hdir)
writeFile(hdir / "config.toml", ConfigToml)
writeFile(hdir / "init.scm", InitScm)
# remove old duplicate
if fileExists(hdir / "helix.scm"):
  removeFile(hdir / "helix.scm")
echo "Wrote config.toml + init.scm"

# 4. Plugins - direct git clone to avoid forge auth prompt
echo "[4/4] Installing plugins..."
createDir(cdir)
for line in Plugins.splitLines():
  let url = line.strip()
  if url.len == 0 or url.startsWith("#"): continue
  # obelisk is optional
  if "obelisk" in url and not withObelisk:
    echo "Skipping obelisk (use --obelisk)"
    continue
  # name = repo name without .git, e.g. forest.hx -> forest
  var name = url.split("/")[^1].replace(".git", "").replace(".hx", "")
  if name == "obelisk": name = "obelisk"
  let dest = cdir / name
  if dirExists(dest):
    echo "Updating ", name, "..."
    discard run("git -C " & dest.quoteShell & " pull --ff-only")
  else:
    echo "Cloning ", name, " from ", url
    discard run("git clone " & url.quoteShell & " " & dest.quoteShell)

echo ""
echo "Done! Run: hx"
echo "  Space e = forest  |  Space r = trail  |  Space m = showkeys"
if withObelisk:
  echo "  Space o o = obelisk open  |  Space o f = follow [[link]]"
