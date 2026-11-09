"""
Make Steam believe Satisfactory is already on the latest build, so it stops
queueing an update that would break mod compatibility.

Steam MUST be fully closed before this runs -- it holds app state in memory and
rewrites appmanifest_*.acf on exit, which would silently undo the edit.
"""
import io, os, re, sys, glob, time, shutil

APPID    = "526870"
DEPOT    = "526871"
MANIFEST = r"D:\SteamLibrary\steamapps\appmanifest_526870.acf"
DEPOTCACHE = r"C:\Program Files (x86)\Steam\depotcache"

def fail(m):
    print("ABORT: " + m); sys.exit(1)

# --- Steam must not be running -----------------------------------------------
import subprocess
try:
    _tl = subprocess.run(["tasklist", "/FI", "IMAGENAME eq steam.exe", "/NH"],
                         capture_output=True, text=True, timeout=30).stdout.lower()
except Exception as e:
    fail("Could not check whether Steam is running (%s). Refusing to edit blind." % e)
if "steam.exe" in _tl:
    fail("Steam is still running. Close it fully (tray -> Exit), then re-run. "
         "Steam rewrites this file on exit and would undo the edit.")

if not os.path.exists(MANIFEST):
    fail("appmanifest not found: " + MANIFEST)

text = io.open(MANIFEST, encoding="utf-8").read()

def get(key):
    m = re.search(r'"%s"\s+"([^"]*)"' % re.escape(key), text)
    return m.group(1) if m else None

cur_build = get("buildid")
tgt_build = get("TargetBuildID")
cur_manifest = get("manifest")

print("current buildid      : %s" % cur_build)
print("target  buildid      : %s" % tgt_build)
print("current depot manifest: %s" % cur_manifest)

if not tgt_build or tgt_build == cur_build:
    fail("No pending update (TargetBuildID == buildid). Nothing to freeze.")

# --- find the manifest Steam prefetched for the pending update ---------------
cands = glob.glob(os.path.join(DEPOTCACHE, "%s_*.manifest" % DEPOT))
if not cands:
    fail("No depot manifests found in depotcache.")
cands.sort(key=os.path.getmtime, reverse=True)
newest = os.path.basename(cands[0]).split("_", 1)[1].rsplit(".", 1)[0]
print("newest cached manifest: %s  (%s)" % (newest, time.strftime("%Y-%m-%d %H:%M", time.localtime(os.path.getmtime(cands[0])))))

if newest == cur_manifest:
    fail("Newest cached manifest equals the installed one -- Steam has not prefetched the new\n"
         "       manifest yet. Let Steam sit at the update prompt for a minute, then re-run.")

# --- back up ------------------------------------------------------------------
backup = MANIFEST + ".bak-" + time.strftime("%Y%m%d-%H%M%S")
shutil.copy2(MANIFEST, backup)
print("\nbackup written: %s" % backup)

# --- patch --------------------------------------------------------------------
# StateFlags 4 = Fully Installed. Clearing bit 2 removes "Update Required".
edits = {
    "StateFlags":          "4",
    "buildid":             tgt_build,
    "BytesToDownload":     "0",
    "BytesDownloaded":     "0",
    "BytesToStage":        "0",
    "BytesStaged":         "0",
    "ScheduledAutoUpdate": "0",
    "lastupdated":         str(int(time.time())),
}

out = text
for k, v in edits.items():
    new, n = re.subn(r'("%s"\s+")[^"]*(")' % re.escape(k), lambda m: m.group(1) + v + m.group(2), out, count=1)
    if n == 0:
        print("  WARN: key not found, skipped: %s" % k)
    else:
        out = new
        print("  %-20s -> %s" % (k, v))

# depot manifest id lives inside InstalledDepots -> <depot> -> manifest
out, n = re.subn(r'("manifest"\s+")%s(")' % re.escape(cur_manifest), lambda m: m.group(1) + newest + m.group(2), out, count=1)
if n == 0:
    fail("Could not rewrite the depot manifest id -- nothing written, backup intact.")
print("  %-20s -> %s" % ("depot manifest", newest))

io.open(MANIFEST, "w", encoding="utf-8", newline="\n").write(out)

# --- verify -------------------------------------------------------------------
check = io.open(MANIFEST, encoding="utf-8").read()
def g2(key):
    m = re.search(r'"%s"\s+"([^"]*)"' % re.escape(key), check)
    return m.group(1) if m else None
print("\nverify: buildid=%s StateFlags=%s manifest=%s BytesToDownload=%s"
      % (g2("buildid"), g2("StateFlags"), g2("manifest"), g2("BytesToDownload")))
if g2("buildid") == tgt_build and g2("StateFlags") == "4" and g2("manifest") == newest:
    print("\nOK -- Steam should now consider Satisfactory up to date.")
    print("Start Steam and confirm no update is queued for Satisfactory.")
else:
    fail("Verification failed. Restore with: copy \"%s\" \"%s\"" % (backup, MANIFEST))
