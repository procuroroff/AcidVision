import pathlib
import tarfile
import io

p = next(pathlib.Path("out2").glob("*.deb"))
data = p.read_bytes()
print("deb size", len(data), "magic", data[:8])

pos = 8
members = {}
while pos < len(data):
    hdr = data[pos:pos + 60]
    if len(hdr) < 60:
        break
    name = hdr[:16].decode("ascii", "replace").strip().rstrip("/")
    size = int(hdr[48:58].decode("ascii").strip())
    body = data[pos + 60:pos + 60 + size]
    members[name] = body
    print("member", name, size)
    pos += 60 + size + (size & 1)

if "control.tar.gz" in members:
    tf = tarfile.open(fileobj=io.BytesIO(members["control.tar.gz"]), mode="r:gz")
    for m in tf.getmembers():
        print("control file", m.name, m.size)
        if m.isfile() and m.name.lstrip("./") == "control":
            print(tf.extractfile(m).read().decode("utf-8"))
if "data.tar.gz" in members:
    tf = tarfile.open(fileobj=io.BytesIO(members["data.tar.gz"]), mode="r:gz")
    for m in tf.getmembers():
        print("data", m.name, m.size)
