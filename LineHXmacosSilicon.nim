import os, osproc, strutils, times

proc run(cmd: string): int =
  echo "→ ", cmd
  execCmd(cmd)

proc backup(p: string) =
  if fileExists(p) or dirExists(p):
    let b = p & ".bak-" & $getTime().toUnix()
    echo "Backup ", p, " -> ", b
    if fileExists(p): moveFile(p, b) else: moveDir(p, b)

# embed configs at compile time — no external files needed
const ConfigToml = staticRead("assets/config.toml")
const InitScm = staticRead("assets/init.scm")
const Plugins = [
  "https://github.com/Ra77a3l3-jar/forest.hx.git",
  "https://github.com/gllms/streal.hx.git",
  "https://github.com/helix-steel/steel-pty.git",
  "https://github.com/Ra77a3l3-jar/trail.hx.git",
  "https://github.com/HeitorAugustoLN/showkeys.hx.git"
]

let cfgDir = expandTilde("~/.config/helix")

echo "LineHX macOS Silicon (M1-M5) Installer"
echo "Target: ", cfgDir

echo "Continue? y/n"
if readLine(stdin).strip().toLower()!= "y": quit("Aborted", 0)

echo "\n1. Clean 2. Addon 3. Cancel"
let choice = readLine(stdin).strip()
if choice == "3": quit("Cancelled", 0)
let isClean = choice == "1"

# 1. Ensure rust
if findExe("cargo") == "":
  echo "Installing rust..."
  discard run("brew install rust")

# 2. Ensure helix-steel (v1ctorio) not vanilla brew
let hasSteel = findExe("hx")!= "" and execCmdEx("hx --health 2>&1").output.toLower().contains("steel")
if not hasSteel:
  echo "Installing v1ctorio/helix-steel (this takes ~8 mins on M5)..."
  discard run("brew install git")
  discard run("rm -rf /tmp/helix-steel && git clone https://github.com/v1ctorio/helix-steel.git /tmp/helix-steel && cd /tmp/helix-steel && cargo xtask steel")
  echo "export PATH=\"$HOME/.cargo/bin:$PATH\""
else:
  echo "[✓] hx steel found: ", findExe("hx")

# 3. forge comes from xtask, but fallback
if findExe("forge") == "":
  discard run("cargo install --git https://github.com/nik-rev/forge --locked")

# 4. Install plugins
for url in Plugins:
  discard run("forge pkg install --git " & url)

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
