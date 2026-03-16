"""Decoder for mksqlite typed BLOB format (24-byte header + raw data).

The mksqlite typed BLOB header is 24 bytes:
    Offset  Size  Field
    0       4     magic      (0x4D4B5351 = "MKSQ")
    4       4     version    (3)
    8       4     class_id   (mxDOUBLE_CLASS=6, or TAG_* codes)
    12      4     ndims      (number of dimensions)
    16      4     rows       (first dimension size)
    20      4     cols       (second dimension size)
    24+     ...   raw data   (rows * cols * sizeof(type))
"""

import struct

import numpy as np

MKSQ_MAGIC = 0x4D4B5351
HEADER_SIZE = 24
HEADER_FMT = "<6I"  # magic, version, class_id, ndims, rows, cols

# mxClassID -> numpy dtype mapping
_NUMERIC_DTYPES: dict[int, np.dtype] = {
    6: np.dtype("float64"),   # mxDOUBLE_CLASS
    7: np.dtype("float32"),   # mxSINGLE_CLASS
    8: np.dtype("int8"),      # mxINT8_CLASS
    9: np.dtype("uint8"),     # mxUINT8_CLASS
    10: np.dtype("int16"),    # mxINT16_CLASS
    11: np.dtype("uint16"),   # mxUINT16_CLASS
    12: np.dtype("int32"),    # mxINT32_CLASS
    13: np.dtype("uint32"),   # mxUINT32_CLASS
    14: np.dtype("int64"),    # mxINT64_CLASS
    15: np.dtype("uint64"),   # mxUINT64_CLASS
}

TAG_CHAR = 100
TAG_LOGICAL = 101
TAG_CELL = 102
TAG_CATEGORICAL = 103


def decode_typed_blob(data: bytes | memoryview) -> np.ndarray | str | list:
    """Decode a mksqlite typed BLOB into a numpy array, string, or list.

    Args:
        data: Raw bytes of the typed BLOB (header + payload).

    Returns:
        Decoded value: numpy array for numeric types, str for TAG_CHAR,
        bool array for TAG_LOGICAL.

    Raises:
        ValueError: If the magic number is invalid or the data is truncated.
    """
    if len(data) < HEADER_SIZE:
        raise ValueError(
            f"Blob too short ({len(data)} bytes), need at least {HEADER_SIZE}"
        )

    magic, version, class_id, ndims, rows, cols = struct.unpack_from(
        HEADER_FMT, data
    )

    if magic != MKSQ_MAGIC:
        raise ValueError(
            f"Invalid magic: 0x{magic:08X}, expected 0x{MKSQ_MAGIC:08X}"
        )

    numel = rows * cols
    payload = data[HEADER_SIZE:]

    # Numeric types
    if class_id in _NUMERIC_DTYPES:
        dtype = _NUMERIC_DTYPES[class_id]
        expected = numel * dtype.itemsize
        if len(payload) < expected:
            raise ValueError(
                f"Blob truncated: need {expected} bytes, got {len(payload)}"
            )
        return np.frombuffer(payload[:expected], dtype=dtype).copy()

    # Char (1 byte per character, decode to str)
    if class_id == TAG_CHAR:
        if len(payload) < numel:
            raise ValueError(
                f"Blob truncated: need {numel} bytes for char, "
                f"got {len(payload)}"
            )
        return bytes(payload[:numel]).decode("latin-1")

    # Logical (1 byte per element, decode to bool array)
    if class_id == TAG_LOGICAL:
        if len(payload) < numel:
            raise ValueError(
                f"Blob truncated: need {numel} bytes for logical, "
                f"got {len(payload)}"
            )
        return np.array([b != 0 for b in payload[:numel]], dtype=bool)

    raise ValueError(f"Unsupported class_id: {class_id}")
