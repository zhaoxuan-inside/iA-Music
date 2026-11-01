"""DEC-010: real JPEG and ffmpeg APIC-tagged MP3 for cover precedence tests."""
from pathlib import Path
import subprocess
import imageio_ffmpeg

app = Path(__file__).resolve().parents[1]
out = app / 'test/fixtures/cover'
out.mkdir(parents=True, exist_ok=True)
subprocess.run([
    imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-loglevel', 'error',
    '-f', 'lavfi', '-i', 'color=c=0x2a3138:s=64x64',
    '-vf', 'drawbox=x=12:y=12:w=40:h=40:color=0x4be0a3:t=fill',
    '-frames:v', '1', str(out / 'local.jpg'),
], check=True)
subprocess.run([
    imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-loglevel', 'error',
    '-i', str(app / 'test/fixtures/library_smoke/探曲03.mp3'),
    '-i', str(out / 'local.jpg'), '-map', '0:a', '-map', '1:v',
    '-c', 'copy', '-id3v2_version', '3', '-metadata:s:v', 'title=Cover',
    '-metadata:s:v', 'comment=Cover (front)', str(out / 'embedded.mp3'),
], check=True)
print('Generated real JPEG + MP3 with embedded cover')
