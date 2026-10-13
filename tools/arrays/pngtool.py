import zlib, struct, collections, sys
def load(path):
    d = open(path,'rb').read(); pos = 8; idat=b''; plte=None; trns=None
    while pos < len(d):
        ln, = struct.unpack('>I', d[pos:pos+4]); t = d[pos+4:pos+8]; body = d[pos+8:pos+8+ln]; pos += 12+ln
        if t == b'IHDR': w,h,bd,ct,_,_,il = struct.unpack('>IIBBBBB', body)
        if t == b'IDAT': idat += body
        if t == b'PLTE': plte = body
        if t == b'tRNS': trns = body
    raw = zlib.decompress(idat); bpp = {6:4,2:3,3:1,4:2,0:1}[ct]
    stride = w*bpp; rows=[]; prev=bytearray(stride); i=0
    for y in range(h):
        f = raw[i]; i+=1; line = bytearray(raw[i:i+stride]); i+=stride
        for x in range(stride):
            a = line[x-bpp] if x>=bpp else 0; b = prev[x]; c = prev[x-bpp] if x>=bpp else 0
            if f==1: line[x]=(line[x]+a)&255
            elif f==2: line[x]=(line[x]+b)&255
            elif f==3: line[x]=(line[x]+(a+b)//2)&255
            elif f==4:
                p=a+b-c; pa=abs(p-a); pb=abs(p-b); pc=abs(p-c)
                line[x]=(line[x]+(a if pa<=pb and pa<=pc else (b if pb<=pc else c)))&255
        rows.append(line); prev=line
    px = []
    for r in rows:
        row=[]
        for x in range(w):
            if ct==6: row.append(tuple(r[x*4:x*4+4]))
            elif ct==2: row.append(tuple(r[x*3:x*3+3])+(255,))
            elif ct==3:
                k=r[x]; rgb=tuple(plte[k*3:k*3+3]); a = trns[k] if trns and k < len(trns) else 255; row.append(rgb+(a,))
        px.append(row)
    return w,h,px
def save(path, w, h, px):
    raw = b''
    for row in px:
        raw += b'\x00' + b''.join(bytes(p) for p in row)
    def chunk(t, body): return struct.pack('>I', len(body)) + t + body + struct.pack('>I', zlib.crc32(t+body) & 0xffffffff)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    open(path,'wb').write(data)
if __name__ == "__main__":
    for f in sys.argv[1:]:
        w,h,px = load(f)
        c = collections.Counter(p for row in px for p in row if p[3] > 0)
        print(f, w, h, [('#%02x%02x%02x' % p[:3], p[3], n) for p, n in c.most_common(14)])
