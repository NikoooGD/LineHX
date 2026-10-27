import os, osproc, strutils, parseopt

var autoConfirm = false
var verbose = false
for kind, key, _ in getopt():
  if key in ["confirm","y"]: autoConfirm = true
  if key in ["verbose","v"]: verbose = true
  if key in ["help","h"]:
    echo "Usage: ./LineHX-macos-m5 [--confirm] [--verbose]"
    quit(0)

proc run(cmd: string): int =
  echo "→ ", cmd
  execCmd(cmd)

proc backup(p: string) =
  if fileExists(p) or dirExists(p):
    let b = p & ".bak-" & $getTime().toUnix()
    echo "Backup ", p, " -> ", b
    if fileExists(p): moveFile(p, b) else: moveDir(p, b)

let cfgDir = expandTilde("~/.config/helix")

echo "LineHX macOS Silicon Installer"
echo "Plugins: forest, streal, steel-pty, trail, showkeys"
echo "Target: ", cfgDir

if not autoConfirm:
  echo "Continue? y/n"
  if readLine(stdin).strip().toLower()!= "y": quit("Aborted", 0)

# 0. remove vanilla helix
if findExe("hx")!= "" and findExe("forge") == "":
  echo "Removing vanilla helix..."
  discard run("brew uninstall helix 2>/dev/null; brew unlink helix 2>/dev/null; rm -f /opt/homebrew/bin/hx /usr/local/bin/hx")

# 1. rust
if findExe("cargo") == "":
  echo "Installing rust..."
  discard run("brew install rustup && rustup default stable")

# 2. helix steel - YOUR WORKING COMMAND
if findExe("hx") == "" or findExe("forge") == "":
  echo "Installing helix steel (mattwparas steel-event-system)..."
  discard run("rm -rf /tmp/helix && git clone https://github.com/mattwparas/helix.git /tmp/helix && cd /tmp/helix && git switch steel-event-system && cargo xtask steel")
  if findExe("hx") == "":
    discard run("cd /tmp/helix && cargo install --path helix-term --bin hx --locked && cargo install --path forge --bin forge --locked")
else:
  echo "[✓] steel found: ", findExe("hx"), " + ", findExe("forge")

discard run("grep -q '.cargo/bin' ~/.zshrc 2>/dev/null || echo 'export PATH=\"$HOME/.cargo/bin:$PATH\"' >> ~/.zshrc")

# 3. install your 5 plugins - EXACT from your init.scm
let plugins = [
  "https://github.com/Ra77a3l3-jar/forest.hx.git",
  "https://github.com/mattwparas/streal.hx.git",
  "https://github.com/mattwparas/steel-pty.git",
  "https://github.com/Ra77a3l3-jar/trail.hx.git",
  "https://github.com/HeitorAugustoLN/showkeys.hx.git"
]

for url in plugins:
  discard run("forge pkg install --git " & url)

# 4. write your exact init.scm
createDir(cfgDir)
let initContent = """; Plugins
(require "forest/forest.scm")
(forest-configure! 'left)
(require "streal/streal.scm")
(require "steel-pty/term.scm")
(require "trail/trail.scm")
(require "showkeys/showkeys.scm")

; Run on startup
(showkeys-toggle)
"""

let configContent = """theme = "astrodark"
[editor]
line-number = "absolute"
cursorline = true
color-modes = true

[keys.normal.space]
e = ":forest-open"
h = ":streal-open"
r = ":trail-open"
"""

# backup if exists
backup(cfgDir / "init.scm")
backup(cfgDir / "config.toml")

writeFile(cfgDir / "init.scm", initContent)
writeFile(cfgDir / "config.toml", configContent)
echo "Wrote ", cfgDir / "init.scm"
echo "Wrote ", cfgDir / "config.toml"

echo "\nDone. Run: source ~/.zshrc && hx"
echo "Commands: Space+e forest, Space+h streal, Space+r trail, showkeys auto"
