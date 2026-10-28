# -*- coding: utf-8 -*-
"""S2 fixture 生成器（DEC-010 全真：真 ffmpeg 编码管线，产物=真实音频文件）。

产物：app/test/fixtures/library_smoke/
  * 10 个有效音频（mp3×3 / m4a×2 / ogg×2 / flac×2 / wav×1）：
    中文 tag（题/唱者/专辑）→ 走 MetadataPort 真解析+拼音索引；
    wav 故意不打 tag（表注释口径：标签缺失→扫描以文件名兜底）。
  * 1 个损坏文件（10_broken_probe.mp3=真实损坏类事故：乱码字节，MetadataPort 必败）。
  * 1 个零字节文件（11_empty_probe.flac=真实事故类：写入中断残件）。
  合计 12 个音频扩展名文件 → DoD1 断言 total=10 / skipped=2 / track 行=10。

幂等：目录存在则先清空。重跑仅需 `py app/tool/gen_library_fixture.py`。
"""
import os
import random
import shutil
import subprocess
import sys

try:
    import imageio_ffmpeg
    FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
except Exception:
    sys.exit("need imageio-ffmpeg: py -m pip install imageio-ffmpeg")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "test", "fixtures", "library_smoke")
SINE = "sine=frequency=440:duration=2:sample_rate=8000"

# (文件名, 编码参数, title, artist, album)；wav 无 tag（兜底路径用例）
VALID = [
    ("探曲01.mp3",  ["-c:a", "libmp3lame", "-b:a", "64k"], "探曲01", "测试歌手A", "测试专辑壹"),
    ("探曲02.mp3",  ["-c:a", "libmp3lame", "-b:a", "64k"], "探曲02", "测试歌手A", "测试专辑壹"),
    ("探曲03.mp3",  ["-c:a", "libmp3lame", "-b:a", "64k"], "探曲03", "测试歌手B", "测试专辑贰"),
    ("探曲04.m4a",  ["-c:a", "aac", "-b:a", "64k"],        "探曲04", "测试歌手A", "测试专辑贰"),
    ("探曲05.m4a",  ["-c:a", "aac", "-b:a", "64k"],        "探曲05", "测试歌手B", "测试专辑壹"),
    ("探曲07.ogg",  ["-c:a", "libvorbis", "-q:a", "2"],    "探曲07", "测试歌手A", "测试专辑壹"),
    ("探曲08.ogg",  ["-c:a", "libvorbis", "-q:a", "2"],    "探曲08", "测试歌手B", "测试专辑贰"),
    ("探曲09.flac", ["-c:a", "flac"],                      "探曲09", "测试歌手A", "测试专辑贰"),
    ("探曲10.flac", ["-c:a", "flac"],                      "探曲10", "测试歌手B", "测试专辑贰"),
    ("探曲06.wav",  ["-c:a", "pcm_s16le"],                 None,     None,        None),
]


def main():
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT)

    oks = []
    for name, codec, title, artist, album in VALID:
        dst = os.path.join(OUT, name)
        cmd = [FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
               "-f", "lavfi", "-i", SINE, "-ac", "1"] + codec
        if title:
            cmd += ["-metadata", f"title={title}", "-metadata",
                    f"artist={artist}", "-metadata", f"album={album}"]
        cmd += [dst]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode == 0 and os.path.getsize(dst) > 0:
            oks.append(name)
        else:
            sys.exit(f"ENCODE_FAIL {name}: {r.stderr[-300:]}")

    # 损坏：真实事故类（下载半途写入损坏=不可解析乱码）
    broken = os.path.join(OUT, "10_broken_probe.mp3")
    with open(broken, "wb") as f:
        f.write(bytes(random.randbytes(2048)))

    # 零字节：真实事故类（写入中断残件）
    zero = os.path.join(OUT, "11_empty_probe.flac")
    open(zero, "wb").close()

    files = sorted(os.listdir(OUT))
    print(f"OK dir={len(files)} valid={len(oks)} corrupt=1 zero=1")
    for n in files:
        p = os.path.join(OUT, n)
        print(f"  {n}\t{os.path.getsize(p)} bytes")


if __name__ == "__main__":
    main()
