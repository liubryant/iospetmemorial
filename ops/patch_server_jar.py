import zipfile, shutil, os, hashlib
from pathlib import Path
base=Path('/home/repo/bootdo/target')
live=base/'bootdo-1.7.0.jar'
candidate=base/'bootdo-1.7.0.jar.petmemorial-candidate'
with zipfile.ZipFile(live) as old, zipfile.ZipFile(base/'petmemorial-patch.zip') as patch:
    names=set(patch.namelist())
    assert names and all(n.startswith('BOOT-INF/classes/com/bootdo/petmemorial/') or n=='BOOT-INF/classes/com/bootdo/system/config/ShiroConfig.class' for n in names)
    prefix_len=min(i.header_offset for i in old.infolist())
    with live.open('rb') as src,candidate.open('wb') as dst: dst.write(src.read(prefix_len))
    with zipfile.ZipFile(candidate,'a') as out:
        for info in old.infolist():
            source=patch if info.filename in names else old
            with source.open(info.filename) as src,out.open(info,'w') as dst: shutil.copyfileobj(src,dst,1024*1024)
        for name in names-set(old.namelist()): out.writestr(name,patch.read(name),compress_type=zipfile.ZIP_DEFLATED)
with zipfile.ZipFile(live) as old,zipfile.ZipFile(candidate) as new:
    assert not new.testzip()
    for info in old.infolist():
        if info.filename not in names:
            assert info.CRC==new.getinfo(info.filename).CRC and info.file_size==new.getinfo(info.filename).file_size, info.filename
os.chmod(candidate,0o755)
print('Candidate verified; only these classes changed:')
for name in sorted(names): print(name)
