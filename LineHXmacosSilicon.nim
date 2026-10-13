import os, osproc, strutils, parseopt, times

var autoConfirm = false
var verbose = false

for kind, key, _ in getopt():
  if key in ["confirm", "y"]: autoConfirm = true
  if key in ["verbose", "v"]: verbose = true
  if key in ["help", "h"]:
    echo "Usage:./LineHX-macos-m5 [--confirm] [--verbose]"
    quit(0)

proc run(cmd: string): int =
  echo "→ ", cmd
  if verbose: execCmd(cmd) else: execCmdEx(cmd)[1]

proc backup(p: string) =
  if fileExists(p) or dirExists(p):
    let b = p & ".bak-" & $getTime().toUnix()
    echo "Backup ", p, " -> ", b
    if fileExists(p): moveFile(p, b) else: moveDir(p, b)

let cfgDir = expandTilde("~/.config/helix")
let cloneDir = "/tmp/LineHX-Clone"

echo "LineHX macOS Silicon Installer"
echo "Target: ", cfgDir

if not autoConfirm:
  echo "Continue? y/n"
  if readLine(stdin).strip().toLower()!= "y": quit("Aborted", 0)

# 1. rust
if findExe("cargo") == "":
  echo "Installing rust..."
  discard run("brew install rust")

# 2. hx steel
if findExe("hx") == "" or findExe("forge") == "":
  echo "Installing helix-steel..."
  discard run("brew install git")
  discard run("rm -rf /tmp/helix-steel && git clone https://github.com/v1ctorio/helix-steel.git /tmp/helix-steel && cd /tmp/helix-steel && cargo xtask install")
  if findExe("hx") == "":
    discard run("cd /tmp/helix-steel && cargo install --path helix-term --bin hx --locked && cargo install --path forge --bin forge --locked")
else:
  echo "[✓] hx steel found"

# 3. clone your config holder
echo "Cloning config from NikoooGD/LineHX-Clone..."
discard run("rm -rf " & cloneDir & " && git clone https://github.com/NikoooGD/LineHX-Clone.git " & cloneDir)

# 4. move to ~/.config/helix
createDir(cfgDir)
echo "1. Clean 2. Addon 3. Cancel"
let choice = if autoConfirm: "1" else: readLine(stdin).strip()
if choice == "3": quit("Cancelled", 0)

if choice == "1":
  backup(cfgDir / "config.toml")
  backup(cfgDir / "init.scm")
  if fileExists(cfgDir / "helix.scm"): removeFile(cfgDir / "helix.scm")

# copy everything from clone to config
for file in walkFiles(cloneDir / "/*"):
  let name = extractFilename(file)
  if name == ".git": continue
  copyFile(file, cfgDir / name)
  echo "Wrote ", cfgDir / name

# also handle plugins.txt if you store plugins in repo -> auto install
let pluginsFile = cfgDir / "plugins.txt"
if fileExists(pluginsFile):
  for line in readFile(pluginsFile).splitLines():
    let u = line.strip()
    if u.len > 0 and not u.startsWith("#"):
      discard run("forge pkg install --git " & u)

echo "\nDone. Run: hx"
