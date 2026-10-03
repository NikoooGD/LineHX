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

echo "LineHX Arch Installer"
echo "This will write ~/.config/helix/{config.toml,init.scm}"
echo "Continue? y/n"
if readLine(stdin).strip().toLower() != "y":
  quit("Aborted", 0)

echo ""
echo "How to install?"
echo "1. Clean - backup existing and overwrite (recommended)"
echo "2. Addon - keep existing config.toml, only add LineHX if missing"
echo "3. Cancel"
let installType = readLine(stdin).strip()

if installType == "3": quit("Cancelled", 0)
let isClean = installType == "1"

echo ""
echo "Choose AUR helper: 1=yay 2=paru 3=skip (already have helix-steel-git)"
let input = readLine(stdin).strip()

let installCmd =
  try:
    case parseInt(input)
    of 1: "yay -S helix-steel-git steel --noconfirm"
    of 2: "paru -S helix-steel-git steel --noconfirm"
    of 3: ""
    else: quit("Invalid choice", 1)
  except ValueError:
    quit("Enter a number", 1)

if installCmd != "":
  # ensure we don't have vanilla helix
  if execCmd("pacman -Qi helix >/dev/null 2>&1") == 0:
    echo "Removing vanilla extra/helix (conflicts with steel)"
    discard run("sudo pacman -R helix --noconfirm")
  if run(installCmd) != 0:
    quit("helix-steel install failed", 1)
else:
  # verify steel is actually installed
  if execCmd("pacman -Qo /usr/bin/hx 2>/dev/null | grep -q helix-steel-git") != 0:
    echo "[!] /usr/bin/hx is not owned by helix-steel-git"
    echo " Install it or LineHX plugins won't load"
    quit(1)

# plugins
for url in [
  "https://github.com/Ra77a3l3-jar/forest.hx.git",
  "https://github.com/gllms/streal.hx.git",
  "https://github.com/mattwparas/steel-pty.git",
  "https://github.com/Ra77a3l3-jar/trail.hx.git"
]:
  discard run("forge pkg install --git " & url)

# --- write files ---
createDir(cfgDir)

# only backup if clean
if isClean:
  backup(cfgDir / "config.toml")
  backup(cfgDir / "init.scm")
  if fileExists(cfgDir / "helix.scm"):
    removeFile(cfgDir / "helix.scm") # old name

const configToml = """theme = "astrodark"

[keys.insert]
up = "no_op"
down = "no_op"
left = "no_op"
right = "no_op"

[keys.normal]
up = "no_op"
down = "no_op"
left = "no_op"
right = "no_op"
[editor]
gutters = ["diagnostics", "diff", "line-numbers", "spacer"]
line-number = "absolute"
cursorline = true
color-modes = true
auto-info = true

[editor.cursor-shape]
normal = "block"
insert = "bar"
select = "underline"

[keys.normal.space]
e = ":forest-open"
o = ":forest-open"
h = ":streal-open"
r = ":trail-open"
q = ":q"
w = ":w"
n = "goto_next_change"
N = "goto_prev_change"

[keys.normal.space.g]
g = ":sh foot --app-id lazygit -e lazygit >/dev/null 2>&1"
b = ":sh git blame -L %{cursor_line},%{cursor_line} %{buffer_name}"
d = ":sh git diff %{buffer_name}"
s = ":sh git status -s"
l = ":sh git log --oneline -20"
[keys.normal.space.t]
t = ":sh kitty >/dev/null 2>&1"
k = ":sh pkill kitty >/dev/null 2>&1"
"""

const initScm = """(require "forest/forest.scm")
(forest-configure! 'left)
(require "streal/streal.scm")
(require "steel-pty/term.scm")
(require "trail/trail.scm")
"""

if isClean or not fileExists(cfgDir / "config.toml"):
  writeFile(cfgDir / "config.toml", configToml)
  echo "Wrote ~/.config/helix/config.toml"
else:
  echo "Kept existing config.toml (addon mode)"

if isClean or not fileExists(cfgDir / "init.scm"):
  writeFile(cfgDir / "init.scm", initScm)
  echo "Wrote ~/.config/helix/init.scm"
else:
  echo "Kept existing init.scm"

echo "\nDone. Run `hx`"
