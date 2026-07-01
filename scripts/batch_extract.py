import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.services.mediapipe_service import MediaPipePoseExtractor
from app.services.landmark_exporter import export_json, export_csv, export_compact_json


def main():
    parser = argparse.ArgumentParser(description="Batch extract MediaPipe pose landmarks from videos")
    parser.add_argument("--input", type=str, default="data/raw", help="Input video directory")
    parser.add_argument("--output", type=str, default="data/processed", help="Output directory")
    parser.add_argument("--format", type=str, choices=["json", "csv", "compact"], default="json")
    parser.add_argument("--model-complexity", type=int, default=2, choices=[0, 1, 2])
    parser.add_argument("--resize-width", type=int, default=1280, help="Resize frame width (keep aspect ratio)")
    parser.add_argument("--video-ext", type=str, nargs="+", default=[".mp4", ".avi", ".mov", ".mkv"])
    args = parser.parse_args()

    input_dir = Path(args.input)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    video_files = [f for f in input_dir.iterdir() if f.suffix.lower() in args.video_ext]
    if not video_files:
        print(f"No video files found in {input_dir}")
        return

    print(f"Found {len(video_files)} videos. Starting extraction...")
    extractor = MediaPipePoseExtractor(model_complexity=args.model_complexity)

    for i, video_path in enumerate(video_files):
        print(f"[{i+1}/{len(video_files)}] Processing: {video_path.name} ...")
        try:
            result = extractor.extract_video(str(video_path), resize_width=args.resize_width)
            stem = video_path.stem

            if args.format == "json":
                out = output_dir / f"{stem}.json"
                export_json(result, out)
            elif args.format == "csv":
                out = output_dir / f"{stem}.csv"
                export_csv(result, out)
            elif args.format == "compact":
                out = output_dir / f"{stem}_compact.json"
                export_compact_json(result, out)

            stats = result.get("stats", {})
            print(f"  -> {out.name} | frames: {stats.get('frames_processed')}, "
                  f"detected: {stats.get('frames_detected')}, "
                  f"rate: {stats.get('detection_rate', 0)*100:.1f}%")
        except Exception as e:
            print(f"  -> FAILED: {e}")

    extractor.close()
    print("Done.")


if __name__ == "__main__":
    main()
