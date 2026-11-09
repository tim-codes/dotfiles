import struct, sys, os

def rd(f, off, n):
    f.seek(off); return f.read(n)

class PE:
    def __init__(self, path):
        self.path = path
        self.f = open(path, 'rb')
        f = self.f
        e_lfanew = struct.unpack('<I', rd(f, 0x3C, 4))[0]
        assert rd(f, e_lfanew, 4) == b'PE\0\0', 'not PE'
        coff = e_lfanew + 4
        machine, nsec, _, _, _, optsz, _ = struct.unpack('<HHIIIHH', rd(f, coff, 20))
        opt = coff + 20
        magic = struct.unpack('<H', rd(f, opt, 2))[0]
        self.pe32p = (magic == 0x20b)
        ddoff = opt + (112 if self.pe32p else 96)
        self.dd = []
        for i in range(16):
            va, sz = struct.unpack('<II', rd(f, ddoff + i * 8, 8))
            self.dd.append((va, sz))
        self.sections = []
        so = opt + optsz
        for i in range(nsec):
            raw = rd(f, so + i * 40, 40)
            name = raw[:8].rstrip(b'\0').decode('latin1')
            vsz, va, rsz, ra = struct.unpack('<IIII', raw[8:24])
            self.sections.append((name, va, max(vsz, rsz), ra))

    def off(self, va):
        for name, sva, sz, ra in self.sections:
            if sva <= va < sva + sz:
                return ra + (va - sva)
        return None

    def cstr(self, va):
        o = self.off(va)
        if o is None: return None
        self.f.seek(o)
        b = b''
        while True:
            c = self.f.read(1)
            if not c or c == b'\0': break
            b += c
        return b.decode('latin1')

    def imports(self):
        va, sz = self.dd[1]
        if not va: return {}
        out = {}
        o = self.off(va)
        i = 0
        while True:
            ent = rd(self.f, o + i * 20, 20)
            oft, tstamp, fchain, nameva, iat = struct.unpack('<IIIII', ent)
            if nameva == 0 and iat == 0: break
            dll = self.cstr(nameva)
            names = []
            tbl = oft or iat
            to = self.off(tbl)
            j = 0
            while to is not None:
                v = struct.unpack('<Q', rd(self.f, to + j * 8, 8))[0]
                if v == 0: break
                if not (v >> 63):
                    if self.off(v) is not None:
                        names.append(self.cstr(v + 2))
                j += 1
            out[dll] = names
            i += 1
        return out

    def exports(self):
        va, sz = self.dd[0]
        if not va: return set()
        o = self.off(va)
        hdr = rd(self.f, o, 40)
        (_, _, _, nameva, base, naddr, nnames, addrva, nameptrva, ordva) = struct.unpack('<IIIIIIIIII', hdr)
        res = set()
        po = self.off(nameptrva)
        if po is None: return res
        blob = rd(self.f, po, 4 * nnames)
        for k in range(nnames):
            nv = struct.unpack('<I', blob[k*4:k*4+4])[0]
            s = self.cstr(nv)
            if s: res.add(s)
        return res


def _main():
    target = sys.argv[1]
    providers = sys.argv[2:]
    pe = PE(target)
    imps = pe.imports()
    exp_map = {}
    for p in providers:
        try:
            exp_map[os.path.basename(p).lower()] = PE(p).exports()
        except Exception as e:
            print('WARN cannot parse', p, e)

    print('=== IMPORTS of', os.path.basename(target), '===')
    for dll, names in imps.items():
        print(f'{dll}: {len(names)} named imports')
    print()
    for dll, names in imps.items():
        key = dll.lower()
        if key not in exp_map:
            continue
        missing = [n for n in names if n not in exp_map[key]]
        print(f'--- {dll}: {len(missing)} MISSING of {len(names)} ---')
        for n in missing[:40]:
            print('   MISSING:', n)


if __name__ == '__main__':
    _main()
