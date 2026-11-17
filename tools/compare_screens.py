#!/usr/bin/env python3
"""Optional image difference metrics with Pillow, NOT a deterministic pass gate."""
import argparse
from pathlib import Path

def main():
    p=argparse.ArgumentParser()
    p.add_argument("approved")
    p.add_argument("candidate")
    args=p.parse_args()
    try:
        from PIL import Image, ImageChops, ImageStat
    except ImportError:
        p.error("Install optional Pillow package to compare rendered images")
    a,b=Image.open(args.approved).convert("RGB"),Image.open(args.candidate).convert("RGB")
    if a.size!=b.size:
        p.error("Different image sizes")
    difference=ImageChops.difference(a,b)
    metric=sum(ImageStat.Stat(difference).mean)/3
    print("Mean absolute RGB difference:",round(metric,3))
    print("Manual review needed: GPU, renderer, lighting and anti-aliasing can change pixels.")

if __name__=="__main__":
    main()

