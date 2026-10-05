
import os, osproc, strutils, times

proc run(cmd: string): int =
  echo "→ ", cmd
  execCmd(cmd)

proc backup(p: string) =
  if fileExists(p) or dirExists(p):
    let b = p & ".bak-" & $getTime().toUnix()
    echo "Backup ", p, " -> ", b
    if fileExists(p): moveFile(p, b) else: moveDir(p, b)

let cfgDir =
  when defined(macosx):
    expandTilde("~/.config/helix")
  elif defined(windows):
    getEnv("APPDATA") / "helix"
  else:
    expandTilde("~/.config/helix")

echo "LineHX macOS Installer"
echo "Target: ", cfgDir
echo "Continue? y/n"
if readLine(stdin).strip().toLower()!= "y": quit("Aborted", 0)

echo ""
echo "How to install?"
echo "1. Clean - backup existing and overwrite (recommended)"
echo "2. Addon - keep existing, only add if missing"
echo "3. Cancel"
let choice = readLine(stdin).strip()
if choice == "3": quit("Cancelled", 0)
let isClean = choice == "1"

# ── macOS checks ──
when defined(macosx) or not defined(windows):
  if findExe("brew") == "":
    quit("brew not found. Install from https://brew.sh", 1)

  if findExe("hx") == "":
    echo "[!] hx not found, installing steel build via cargo..."
    if findExe("cargo") == "":
      echo "Installing rustup..."
      discard run("curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y")
    # brew deps for helix
    discard run("brew install git")
    if run("cargo install --git https://github.com/mattwparas/helix --branch steel-event-system helix-term --bin hx --locked")!= 0:
      quit("hx build failed", 1)
  else:
    echo "[✓] hx found: ", findExe("hx")

  if findExe("steel") == "":
    discard run("cargo install steel --locked")

if findExe("forge") == "":
  discard run("cargo install forge-hx --locked")

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
  if fileExists(cfgDir / "helix.scm"): removeFile(cfgDir / "helix.scm")

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
h = ":streal-open"
r = ":trail-open"
q = ":q"
w = ":w"
n = "goto_next_change"
N = "goto_prev_change"

[keys.normal.space.g]
g = ":sh lazygit"
b = ":sh git blame -L %{cursor_line},%{cursor_line} %{buffer_name}"
d = ":sh git diff %{buffer_name}"
s = ":sh git status -s"
l = ":sh git log --oneline -20"
"""

const initScm = """(require "forest/forest.scm")
(forest-configure! 'left)
(require "streal/streal.scm")
(require "trail/trail.scm")
"""

if isClean or not fileExists(cfgDir / "config.toml"):
  writeFile(cfgDir / "config.toml", configToml)
  echo "Wrote ~/.config/helix/config.toml"
if isClean or not fileExists(cfgDir / "init.scm"):
  writeFile(cfgDir / "init.scm", initScm)
  echo "Wrote ~/.config/helix/init.scm"

echo "\nDone. Run `hx`"
