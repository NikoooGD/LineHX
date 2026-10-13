import os, osproc, strutils, times, sequtils

proc run(cmd: string): int =
  echo "→ ", cmd
  execCmd(cmd)

proc backup(p: string) =
  if fileExists(p) or dirExists(p):
    let b = p & ".bak-" & $getTime().toUnix()
    echo "Backup ", p, " -> ", b
    if fileExists(p): moveFile(p, b) else: moveDir(p, b)

# embed at compile time
const ConfigToml = staticRead("assets/config.toml")
const InitScm = staticRead("assets/init.scm")
const PluginsRaw = staticRead("assets/plugins.txt")

let cfgDir = expandTilde("~/.config/helix")
let plugins = PluginsRaw.splitLines().filterIt(it.strip().len > 0 and not it.strip().startsWith("#"))

echo "LineHX macOS Silicon (M1-M5) Installer"
echo "Target: ", cfgDir
echo "Continue? y/n"
if readLine(stdin).strip().toLower()!= "y": quit("Aborted", 0)

echo "\n1. Clean 2. Addon 3. Cancel"
let choice = readLine(stdin).strip()
if choice == "3": quit("Cancelled", 0)
let isClean = choice == "1"

# 1. rust
if findExe("cargo") == "":
  echo "Installing rust..."
  discard run("brew install rust")

# 2. helix-steel v1ctorio - FIXED TASK
let hasSteel = findExe("hx") != "" and findExe("forge") != ""
if not hasSteel:
  echo "Installing v1ctorio/helix-steel (~8 mins on M5)..."
  discard run("brew install git")
  # install is the new task, fallback to cargo install if it fails
  if run("rm -rf /tmp/helix-steel && git clone https://github.com/v1ctorio/helix-steel.git /tmp/helix-steel && cd /tmp/helix-steel && cargo xtask install") != 0:
    echo "xtask install failed, using direct cargo install..."
    discard run("cd /tmp/helix-steel && cargo install --path helix-term --bin hx --locked && cargo install --path forge --bin forge --locked")
else:
  echo "[✓] hx steel found: ", findExe("hx")

# 3. forge fallback
if findExe("forge") == "":
  discard run("cargo install --git https://github.com/nik-rev/forge --locked")

# 4. Install plugins - FIXED LOOP
for url in plugins:
  let u = url.strip()
  if u.len > 0:
    discard run("forge pkg install --git " & u)

# 5. Write configs
createDir(cfgDir)
if isClean:
  backup(cfgDir / "config.toml")
  backup(cfgDir / "init.scm")
  if fileExists(cfgDir / "helix.scm"): removeFile(cfgDir / "helix.scm")

writeFile(cfgDir / "config.toml", ConfigToml)
writeFile(cfgDir / "init.scm", InitScm)
echo "Wrote ", cfgDir / "config.toml"
echo "Wrote ", cfgDir / "init.scm"

echo "\nDone. Run: hx"
