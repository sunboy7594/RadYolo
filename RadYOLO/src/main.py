import cv2
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from camera.capture import open_camera, read_frame
from camera.yolo import predict

cap = open_camera()

while True:
    frame = read_frame(cap)
    if frame is None:
        break

    result = predict(frame)
    annotated = result.plot()

    cv2.imshow("RadYOLO", annotated)
    if cv2.waitKey(1) == ord("q"):
        break

cap.release()
cv2.destroyAllWindows()
