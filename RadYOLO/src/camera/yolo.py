from ultralytics import YOLO

_model = YOLO("yolov8s-seg.pt")


def predict(frame):
    return _model(frame, verbose=False)[0]
