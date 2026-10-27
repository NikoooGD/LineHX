import os, osproc, strutils, parseopt

var autoConfirm = false
for kind, key, _ in getopt():
  if key in ["confirm","y"]: autoConfirm = true
  if key in ["help","h"]:
    echo "Usage: ./LineHX --confirm"
    quit(0)

proc run(cmd: string): int =
  echo "→ ", cmd
  execCmd(cmd)

proc backup(p: string) =
  if fileExists(p) or dirExists(p):
    let b = p & ".bak"
    echo "Backup ", p, " -> ", b
    if fileExists(p): moveFile(p, b) else: moveDir(p, b)

let cfgDir = expandTilde("~/.config/helix")
let cogsDir = expandTilde("~/.steel/cogs")

echo "LineHX Installer - 4 plugins (no steel-pty)"
echo "Target: ", cfgDir

if not autoConfirm:
  echo "Continue? y/n"
  if readLine(stdin).strip().toLower() != "y": quit("Aborted", 0)

# 0. remove vanilla helix if forge missing
if findExe("hx") != "" and findExe("forge") == "":
  echo "Removing vanilla helix..."
  discard run("brew uninstall helix 2>/dev/null; brew unlink helix 2>/dev/null; rm -f /opt/homebrew/bin/hx /usr/local/bin/hx 2>/dev/null; true")

# 1. install helix steel if missing
if findExe("hx") == "" or findExe("forge") == "":
  echo "Installing helix steel (mattwparas steel-event-system)..."
  discard run("rm -rf /tmp/helix && git clone https://github.com/mattwparas/helix.git /tmp/helix && cd /tmp/helix && git switch steel-event-system && cargo xtask steel")
  if findExe("hx") == "":
    discard run("cd /tmp/helix && cargo install --path helix-term --bin hx --locked --force && cargo install --path forge --bin forge --locked --force")
else:
  echo "[✓] hx + forge found"

createDir(cogsDir)

# 2. plugins - direct git clone (no forge auth issue)
let plugins = [
  ("forest.hx", "https://github.com/Ra77a3l3-jar/forest.hx.git"),
  ("streal.hx", "https://github.com/mattwparas/streal.hx.git"),
  ("trail.hx", "https://github.com/Ra77a3l3-jar/trail.hx.git"),
  ("showkeys.hx", "https://github.com/HeitorAugustoLN/showkeys.hx.git")
]

for (name, url) in plugins:
  let dest = cogsDir / name
  echo "\nInstalling ", name
  discard run("rm -rf " & dest & " && git clone " & url & " " & dest)

# 3. write your exact init.scm
createDir(cfgDir)
backup(cfgDir / "init.scm")
backup(cfgDir / "config.toml")

writeFile(cfgDir / "init.scm", """; Plugins
(require "forest/forest.scm")
(forest-configure! 'left)
(require "streal/streal.scm")
(require "trail/trail.scm")
(require "showkeys/showkeys.scm")

; Run on startup
(showkeys-toggle)
""")

writeFile(cfgDir / "config.toml", """theme = "astrodark"
[editor]
line-number = "absolute"
cursorline = true

[keys.normal.space]
e = ":forest-open"
h = ":streal-open"
r = ":trail-open"
""")

echo "\nDone. Run: hx"
echo "Test: :forest-open :streal-open :trail-open and type to see showkeys"
