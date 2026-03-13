"""Tests for mksqlite typed BLOB decoder."""

import struct

import numpy as np
import pytest

from fastplot_bridge.blob_decoder import MKSQ_MAGIC, decode_typed_blob

MX_DOUBLE = 6
MX_SINGLE = 7
MX_INT8 = 8
MX_UINT8 = 9
MX_INT16 = 10
MX_UINT16 = 11
MX_INT32 = 12
MX_UINT32 = 13
MX_INT64 = 14
MX_UINT64 = 15
TAG_CHAR = 100
TAG_LOGICAL = 101


def _make_blob(class_id: int, rows: int, cols: int, data: bytes) -> bytes:
    """Build a typed BLOB with the 24-byte mksqlite header."""
    header = struct.pack("<6I", MKSQ_MAGIC, 3, class_id, 2, rows, cols)
    return header + data


class TestNumericTypes:
    """Test decoding of all numeric class_id values."""

    def test_decode_double_array(self) -> None:
        values = np.array([1.0, 2.0, 3.0], dtype=np.float64)
        blob = _make_blob(MX_DOUBLE, 1, 3, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)

    def test_decode_single_array(self) -> None:
        values = np.array([1.5, 2.5], dtype=np.float32)
        blob = _make_blob(MX_SINGLE, 1, 2, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)

    def test_decode_int8(self) -> None:
        values = np.array([-1, 0, 127], dtype=np.int8)
        blob = _make_blob(MX_INT8, 1, 3, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)

    def test_decode_uint8(self) -> None:
        values = np.array([0, 128, 255], dtype=np.uint8)
        blob = _make_blob(MX_UINT8, 1, 3, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)

    def test_decode_int16(self) -> None:
        values = np.array([-1000, 0, 1000], dtype=np.int16)
        blob = _make_blob(MX_INT16, 1, 3, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)

    def test_decode_uint16(self) -> None:
        values = np.array([0, 1000, 65535], dtype=np.uint16)
        blob = _make_blob(MX_UINT16, 1, 3, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)

    def test_decode_int32_array(self) -> None:
        values = np.array([10, 20, 30], dtype=np.int32)
        blob = _make_blob(MX_INT32, 1, 3, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)

    def test_decode_uint32(self) -> None:
        values = np.array([0, 100, 4294967295], dtype=np.uint32)
        blob = _make_blob(MX_UINT32, 1, 3, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)

    def test_decode_int64(self) -> None:
        values = np.array([-1, 0, 2**62], dtype=np.int64)
        blob = _make_blob(MX_INT64, 1, 3, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)

    def test_decode_uint64(self) -> None:
        values = np.array([0, 1, 2**63], dtype=np.uint64)
        blob = _make_blob(MX_UINT64, 1, 3, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)


class TestSpecialTypes:
    """Test char and logical decoding."""

    def test_decode_char(self) -> None:
        text = b"hello"
        blob = _make_blob(TAG_CHAR, 1, 5, text)
        result = decode_typed_blob(blob)
        assert result == "hello"

    def test_decode_char_empty(self) -> None:
        blob = _make_blob(TAG_CHAR, 1, 0, b"")
        result = decode_typed_blob(blob)
        assert result == ""

    def test_decode_logical(self) -> None:
        data = bytes([1, 0, 1])
        blob = _make_blob(TAG_LOGICAL, 1, 3, data)
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, np.array([True, False, True]))

    def test_decode_logical_single(self) -> None:
        blob = _make_blob(TAG_LOGICAL, 1, 1, bytes([0]))
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, np.array([False]))


class TestErrorHandling:
    """Test invalid/edge-case inputs."""

    def test_invalid_magic_raises(self) -> None:
        blob = struct.pack("<6I", 0xDEADBEEF, 3, MX_DOUBLE, 2, 1, 1)
        blob += b"\x00" * 8
        with pytest.raises(ValueError, match="magic"):
            decode_typed_blob(blob)

    def test_truncated_blob_raises(self) -> None:
        # Header says 1x3 doubles (24 bytes payload) but no payload provided
        blob = struct.pack("<6I", MKSQ_MAGIC, 3, MX_DOUBLE, 2, 1, 3)
        with pytest.raises(ValueError, match="truncated"):
            decode_typed_blob(blob)

    def test_too_short_for_header(self) -> None:
        with pytest.raises(ValueError, match="too short"):
            decode_typed_blob(b"\x00" * 10)

    def test_unsupported_class_id(self) -> None:
        blob = _make_blob(200, 1, 1, b"\x00")
        with pytest.raises(ValueError, match="Unsupported class_id"):
            decode_typed_blob(blob)


class TestMatrixShapes:
    """Test 2D matrix decoding."""

    def test_2d_matrix(self) -> None:
        # MATLAB stores column-major (Fortran order): columns are contiguous
        # For a 2x2 matrix [[1, 2], [3, 4]], MATLAB stores [1, 3, 2, 4]
        values = np.array([[1.0, 2.0], [3.0, 4.0]], dtype=np.float64)
        col_major_bytes = values.ravel(order="F").tobytes()
        blob = _make_blob(MX_DOUBLE, 2, 2, col_major_bytes)
        result = decode_typed_blob(blob)
        # Decoder returns flat array; reshape with Fortran order to recover 2D
        np.testing.assert_array_equal(
            result.reshape(2, 2, order="F"), values
        )

    def test_column_vector(self) -> None:
        values = np.array([1.0, 2.0, 3.0], dtype=np.float64)
        blob = _make_blob(MX_DOUBLE, 3, 1, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)

    def test_row_vector(self) -> None:
        values = np.array([10.0, 20.0, 30.0], dtype=np.float64)
        blob = _make_blob(MX_DOUBLE, 1, 3, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)
