import io, json, os, urllib.request

os.chdir(r'E:\HardStone.iCodeing\GitHub\iA-Music')
tree = json.load(io.open('gh_tree.json', encoding='utf-8'))

def walk(node, prefix=''):
    for f in node.get('files', []):
        name = prefix + '/' + f['name']
        if f['type'] == 'file':
            yield name
        elif f['type'] == 'directory':
            yield from walk(f, name)

src_files = [f for f in walk(tree) if f.startswith('/src/')]
print('src files on gh:', len(src_files))

# 需要的核心文件（指纹算法核心，无 ffmpeg 解码依赖）
KEEP_PREFIXES = (
    '/src/fingerprinter', '/src/fingerprint_calculator', '/src/fingerprint_configuration',
    '/src/chroma', '/src/classifier', '/src/image', '/src/image_builder',
    '/src/silence_remover', '/src/utils', '/src/fft_lib', '/src/base64',
    '/src/chromaprint.cpp', '/src/chromaprint.h',
)
skip = ('/src/audio_processor', '/src/main', '/src/fpcalc')

needed = []
for f in src_files:
    p = f
    if any(p.startswith(sk) for sk in skip):
        continue
    if any(p.startswith(kp) for kp in KEEP_PREFIXES):
        needed.append(f)
print('needed:', len(needed))
for f in needed:
    print(' ', f)

# 下载
base = 'https://cdn.jsdelivr.net/gh/acoustid/chromaprint@v1.5.1'
out_dir = 'third_party/chromaprint/src'
os.makedirs(out_dir, exist_ok=True)
import urllib.request
for f in needed:
    rel = f[len('/src/'):]
    dest = os.path.join(out_dir, rel.replace('/', os.sep))
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    url = base + f
    urllib.request.urlretrieve(url, dest)
print('downloaded', len(needed))

# kissfft
kiss_dir = 'third_party/kissfft'
os.makedirs(kiss_dir, exist_ok=True)
for name in ['kiss_fft.h', 'kiss_fft.c', '_kiss_fft_guts.h']:
    urllib.request.urlretrieve(
        f'https://cdn.jsdelivr.net/gh/mborgerding/kissfft@master/{name}',
        os.path.join(kiss_dir, name))
print('kissfft ok')
