import cv2
import json
from pathlib import Path

_config = json.loads((Path(__file__).parents[2] / "config/camera.json").read_text())


def open_camera():
    cap = cv2.VideoCapture(_config["source"])
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, _config["width"])
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, _config["height"])
    return cap


def read_frame(cap):
    ok, frame = cap.read()
    return frame if ok else None
