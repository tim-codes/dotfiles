import os, sys, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from peimp import PE

GAME = r"D:\SteamLibrary\steamapps\common\Satisfactory"
dirs = [
    os.path.join(GAME, "FactoryGame", "Binaries", "Win64"),
    os.path.join(GAME, "Engine", "Binaries", "Win64"),
]
mod_dlls = glob.glob(os.path.join(GAME, "FactoryGame", "Mods", "**", "Binaries", "Win64", "*.dll"),
                     recursive=True)

# Only Steam-flavoured binaries are actually loaded; EGS ones are dead weight.
mod_dlls = [p for p in mod_dlls if "FactoryGameSteam-" in os.path.basename(p)]

providers = []
for d in dirs:
    providers += glob.glob(os.path.join(d, "*.dll"))
# Engine and game plugins ship provider DLLs too (AbstractInstance, EnhancedInput, AkAudio...)
for root in ("Engine", "FactoryGame"):
    providers += glob.glob(os.path.join(GAME, root, "Plugins", "**", "Binaries", "Win64", "*.dll"),
                           recursive=True)
providers += mod_dlls

exports = {}
for p in providers:
    try:
        exports[os.path.basename(p).lower()] = PE(p).exports()
    except Exception:
        pass

print(f"indexed {len(exports)} provider DLLs\n")

broken = []
for p in sorted(mod_dlls):
    name = os.path.basename(p)
    mod = p.split(os.sep + "Mods" + os.sep)[1].split(os.sep + "Binaries")[0]
    try:
        imps = PE(p).imports()
    except Exception as e:
        print(f"?? {mod}: cannot parse ({e})")
        continue
    miss = {}
    for dll, names in imps.items():
        key = dll.lower()
        if key not in exports:
            if dll.startswith("FactoryGameSteam-"):
                miss.setdefault("(dll absent) " + dll, [])
            continue
        m = [n for n in names if n not in exports[key]]
        if m:
            miss[dll] = m
    if miss:
        broken.append((mod, miss))

if not broken:
    print("ALL DEPLOYED MOD DLLs RESOLVE CLEANLY")
for mod, miss in broken:
    total = sum(len(v) for v in miss.values())
    print(f"BROKEN  {mod}  ({total} unresolved)")
    for dll, names in miss.items():
        print(f"          from {dll}:")
        for n in names[:6]:
            print(f"            {n}")
        if len(names) > 6:
            print(f"            ... +{len(names)-6} more")
print(f"\n{len(broken)} of {len(mod_dlls)} native mod DLLs broken")
