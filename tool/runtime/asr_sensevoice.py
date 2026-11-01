# SenseVoice ASR 推理脚本（桌面 Process 形态；与 yt-dlp/ffmpeg 同构的子进程面）。
# 用法：py asr_sensevoice.py --model-dir DIR --audio FILE [--ffmpeg FFDIR]
# 输出（stdout 末行）：JSON {"tokens":[{"t":ms,"w":str}], "error":null}
# 设计：25s 分段（ffmpeg segment）→ 逐段 SenseVoice（CTC 时间戳逐 token）→
# 合并 + 分段偏移。行分组/歌词成形在 Dart 侧（可单测）；本脚本只出原始时间轴。
import argparse
import glob
import json
import os
import subprocess
import sys
import tempfile

# 顺序纪律：必须先显式按全路径加载 capi/onnxruntime.dll（1.3x）——import
# onnxruntime 是惰性的（不触原生加载）；sherpa 首次原生调用按默认搜索序会
# 撞上 System32 残留的旧 onnxruntime.dll（本机实证 1.17.1 → ORT C API 28
# 不可用崩溃）。全路径 WinDLL 先注册进程内同名模块即可劫持复用。
import onnxruntime  # noqa: F401
import ctypes
ctypes.WinDLL(os.path.join(
    os.path.dirname(onnxruntime.__file__), "capi", "onnxruntime.dll"))
import sherpa_onnx


def load_wav_16k_mono(path):
    # sherpa 2.0 移除 read_wave；分段产物=pcm_s16le/16k/mono（ffmpeg 契约）
    import wave
    import numpy as np
    with wave.open(path, "rb") as w:
        assert w.getframerate() == 16000 and w.getnchannels() == 1
        raw = w.readframes(w.getnframes())
    return np.frombuffer(raw, dtype=np.int16).astype("float32") / 32768.0


def build_recognizer(model_dir):
    model = os.path.join(model_dir, "model.int8.onnx")
    tokens = os.path.join(model_dir, "tokens.txt")
    if not os.path.exists(model) or not os.path.exists(tokens):
        raise FileNotFoundError("model files missing in %s" % model_dir)
    try:
        return sherpa_onnx.OfflineRecognizer.from_sense_voice(
            model=model, tokens=tokens, num_threads=2, use_itn=True
        )
    except TypeError:
        return sherpa_onnx.OfflineRecognizer.from_sense_voice(
            model=model, tokens=tokens
        )


def probe_duration(ffmpeg, wav):
    # ffprobe 在 ffmpeg 目录同发（分发形态）；缺失时用 wave 模块兜底
    ffprobe = os.path.join(ffmpeg, "ffprobe.exe")
    if os.path.exists(ffprobe):
        try:
            out = subprocess.run(
                [ffprobe, "-v", "quiet", "-show_entries", "format=duration",
                 "-of", "csv=p=0", wav],
                capture_output=True, text=True, timeout=30,
            )
            return int(float(out.stdout.strip()) * 1000)
        except Exception:
            pass
    import wave
    with wave.open(wav, "rb") as w:
        return int(w.getnframes() / float(w.getframerate()) * 1000)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-dir", required=True)
    ap.add_argument("--audio", required=True)
    ap.add_argument("--ffmpeg", default="C:/Users/hardstone/tools/ffmpeg")
    ap.add_argument("--segment-sec", type=int, default=25)
    args = ap.parse_args()

    try:
        recognizer = build_recognizer(args.model_dir)
    except Exception as e:
        print(json.dumps({"tokens": [], "error": "init: %s" % e}))
        return

    ffmpeg = os.path.join(args.ffmpeg, "ffmpeg.exe")
    if not os.path.exists(ffmpeg):
        ffmpeg = "ffmpeg"  # PATH 兜底

    with tempfile.TemporaryDirectory(prefix="ia_asr_") as tmp:
        seg_prefix = os.path.join(tmp, "seg")
        r = subprocess.run(
            [ffmpeg, "-hide_banner", "-nostats", "-y", "-i", args.audio,
             "-ac", "1", "-ar", "16000", "-f", "segment",
             "-segment_time", str(args.segment_sec),
             "-c:a", "pcm_s16le", "%s_%%04d.wav" % seg_prefix],
            capture_output=True, text=True, timeout=600,
        )
        chunks = sorted(glob.glob(seg_prefix + "_*.wav"))
        if not chunks:
            print(json.dumps({"tokens": [], "error": "ffmpeg: %s" % r.stderr[-300:]}))
            return

        tokens = []
        for idx, chunk in enumerate(chunks):
            samples = load_wav_16k_mono(chunk)
            # sherpa 2.0 API：stream 面（accept_waveform → decode_stream）
            s = recognizer.create_stream()
            s.accept_waveform(16000, samples)
            recognizer.decode_stream(s)
            res = s.result
            offset = idx * args.segment_sec * 1000
            ts = list(getattr(res, "timestamps", []) or [])
            toks = list(getattr(res, "tokens", []) or [])
            if ts and len(ts) == len(toks):
                for t, w in zip(ts, toks):
                    tokens.append({"t": int(round(t * 1000)) + offset, "w": w})
            elif getattr(res, "text", "").strip():
                # 无时间轴形态：整段一行（chunk 起点）
                tokens.append({"t": offset, "w": res.text.strip()})

    print(json.dumps({"tokens": tokens, "error": None}, ensure_ascii=False))


if __name__ == "__main__":
    main()
