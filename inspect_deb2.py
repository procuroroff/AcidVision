import pathlib
import tarfile
import io
import lzma

p = next(pathlib.Path("out2").glob("*.deb"))
data = p.read_bytes()
pos = 8
members = {}
while pos < len(data):
    hdr = data[pos:pos + 60]
    if len(hdr) < 60:
        break
    name = hdr[:16].decode("ascii", "replace").strip().rstrip("/")
    size = int(hdr[48:58].decode("ascii").strip())
    members[name] = data[pos + 60:pos + 60 + size]
    pos += 60 + size + (size & 1)

blob = members["data.tar.lzma"]
try:
    raw = lzma.decompress(blob, format=lzma.FORMAT_ALONE)
except Exception:
    raw = lzma.decompress(blob)
tf = tarfile.open(fileobj=io.BytesIO(raw), mode="r:")
for m in tf.getmembers():
    print("data", m.name, m.size)
    if m.isfile() and m.name.endswith(".dylib"):
        dylib = tf.extractfile(m).read()
        pathlib.Path("out2/AcidVision.dylib").write_bytes(dylib)
        for needle in [b"acid_vertex", b"acid_fragment", b"AcidVision:processed", b"MTLCreateSystemDefaultDevice"]:
            print(needle.decode(), needle in dylib)
