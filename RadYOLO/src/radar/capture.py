import numpy as np

NUM_RX = 4
NUM_CHIRPS = 128  # chirp loops per frame
NUM_SAMPLES = 256
NUM_FRAMES = 8


def load_bin(path: str) -> np.ndarray:
    """
    .bin 파일을 읽어서 (frames, chirps, rx, samples) 형태의 복소수 배열 반환.
    DCA1000 raw ADC 포맷: int16 IQ interleaved, RX 순서대로.
    """
    raw = np.fromfile(path, dtype=np.int16)

    i = raw[0::2].astype(np.float32)
    q = raw[1::2].astype(np.float32)
    iq = i + 1j * q

    samples_per_frame = NUM_CHIRPS * NUM_RX * NUM_SAMPLES
    total = NUM_FRAMES * samples_per_frame
    assert iq.size == total, f"예상 {total}개, 실제 {iq.size}개"

    iq = iq.reshape(NUM_FRAMES, NUM_CHIRPS, NUM_RX, NUM_SAMPLES)

    return iq
