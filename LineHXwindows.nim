

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
  when defined(windows): getEnv("APPDATA") / "helix"
  else: expandTilde("~/.config/helix")

echo "LineHX Installer - ", cfgDir
echo "Continue? y/n"
if readLine(stdin).strip().toLower()!= "y": quit("Aborted", 0)

echo "1. Clean 2. Addon 3. Cancel"
let isClean = readLine(stdin).strip() == "1"

when defined(windows):
  if findExe("hx") == "": discard run("cargo install --git https://github.com/mattwparas/helix --branch steel-event-system helix-term --bin hx")
else:
  if findExe("hx") == "": echo "Install helix-steel-git first"

if findExe("forge") == "": discard run("cargo install forge-hx --locked")

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
if isClean or not fileExists(cfgDir / "init.scm"):
  writeFile(cfgDir / "init.scm", initScm)

echo "Done. Run hx"
