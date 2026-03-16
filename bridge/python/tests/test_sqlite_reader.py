"""Tests for the SQLite reader with BLOB decoding and downsampling."""

import sqlite3
import struct
from pathlib import Path

import numpy as np
import pytest

from fastplot_bridge.blob_decoder import MKSQ_MAGIC
from fastplot_bridge.sqlite_reader import SqliteReader, _minmax_downsample


def _make_double_blob(values: list[float]) -> bytes:
    """Build a typed BLOB with double (float64) data."""
    arr = np.array(values, dtype=np.float64)
    header = struct.pack("<6I", MKSQ_MAGIC, 3, 6, 2, 1, len(values))
    return header + arr.tobytes()


@pytest.fixture
def sample_db(tmp_path: Path) -> Path:
    """Create a minimal .fpdb file matching FastPlotDataStore schema."""
    db_path = tmp_path / "test.fpdb"
    conn = sqlite3.connect(str(db_path))

    conn.execute("""CREATE TABLE chunks (
        chunk_id INTEGER PRIMARY KEY,
        x_min REAL NOT NULL, x_max REAL NOT NULL,
        y_min REAL NOT NULL, y_max REAL NOT NULL,
        pt_offset INTEGER NOT NULL, pt_count INTEGER NOT NULL,
        x_data BLOB NOT NULL, y_data BLOB NOT NULL
    )""")
    conn.execute("CREATE INDEX idx_xrange ON chunks (x_min, x_max)")

    # Insert 3 chunks: [0-10], [10-20], [20-30]
    for i in range(3):
        x_vals = list(np.linspace(i * 10, (i + 1) * 10, 100))
        y_vals = list(np.sin(x_vals))
        conn.execute(
            "INSERT INTO chunks VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                i,
                x_vals[0],
                x_vals[-1],
                min(y_vals),
                max(y_vals),
                i * 100,
                100,
                _make_double_blob(x_vals),
                _make_double_blob(y_vals),
            ),
        )

    # Add thresholds table
    conn.execute("""CREATE TABLE resolved_thresholds (
        idx INTEGER PRIMARY KEY, x_data BLOB, y_data BLOB,
        direction TEXT NOT NULL, label TEXT NOT NULL,
        color BLOB, line_style TEXT NOT NULL, value REAL NOT NULL
    )""")
    conn.execute(
        "INSERT INTO resolved_thresholds VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (
            0,
            _make_double_blob([0.0, 30.0]),
            _make_double_blob([0.5, 0.5]),
            "upper",
            "limit",
            None,
            "-",
            0.5,
        ),
    )

    # Add violations table
    conn.execute("""CREATE TABLE resolved_violations (
        idx INTEGER PRIMARY KEY, x_data BLOB, y_data BLOB,
        direction TEXT NOT NULL, label TEXT NOT NULL
    )""")
    conn.execute(
        "INSERT INTO resolved_violations VALUES (?, ?, ?, ?, ?)",
        (
            0,
            _make_double_blob([5.0, 15.0]),
            _make_double_blob([0.8, 0.9]),
            "upper",
            "limit",
        ),
    )

    conn.commit()
    conn.close()
    return db_path


class TestSqliteReader:
    """Tests for SqliteReader data access methods."""

    def test_get_range_full(self, sample_db: Path) -> None:
        reader = SqliteReader(str(sample_db))
        x, y = reader.get_range(0, 30)
        assert len(x) == 300
        assert len(y) == 300
        assert x[0] == pytest.approx(0.0)
        assert x[-1] == pytest.approx(30.0)
        reader.close()

    def test_get_range_subset(self, sample_db: Path) -> None:
        reader = SqliteReader(str(sample_db))
        x, y = reader.get_range(5, 15)
        # Should return chunks that overlap [5, 15], which are chunks 0 and 1
        assert len(x) > 0
        # All returned x values should be from chunks overlapping [5, 15]
        assert all(xi >= 0 and xi <= 20 for xi in x)
        reader.close()

    def test_get_range_no_overlap(self, sample_db: Path) -> None:
        reader = SqliteReader(str(sample_db))
        x, y = reader.get_range(100, 200)
        assert len(x) == 0
        assert len(y) == 0
        reader.close()

    def test_get_range_with_max_points(self, sample_db: Path) -> None:
        reader = SqliteReader(str(sample_db))
        x, y = reader.get_range(0, 30, max_points=20)
        assert len(x) <= 20
        assert len(y) <= 20
        reader.close()

    def test_get_range_max_points_no_downsample_needed(
        self, sample_db: Path
    ) -> None:
        reader = SqliteReader(str(sample_db))
        # max_points larger than data count -- no downsampling
        x, y = reader.get_range(0, 30, max_points=1000)
        assert len(x) == 300
        reader.close()

    def test_get_thresholds(self, sample_db: Path) -> None:
        reader = SqliteReader(str(sample_db))
        thresholds = reader.get_thresholds()
        assert len(thresholds) == 1
        assert thresholds[0]["label"] == "limit"
        assert thresholds[0]["direction"] == "upper"
        assert thresholds[0]["value"] == 0.5
        assert thresholds[0]["lineStyle"] == "-"
        assert len(thresholds[0]["x"]) == 2
        assert len(thresholds[0]["y"]) == 2
        reader.close()

    def test_get_thresholds_missing_table(self, tmp_path: Path) -> None:
        """When the thresholds table doesn't exist, return empty list."""
        db_path = tmp_path / "empty.fpdb"
        conn = sqlite3.connect(str(db_path))
        conn.execute("""CREATE TABLE chunks (
            chunk_id INTEGER PRIMARY KEY,
            x_min REAL, x_max REAL, y_min REAL, y_max REAL,
            pt_offset INTEGER, pt_count INTEGER,
            x_data BLOB, y_data BLOB
        )""")
        conn.commit()
        conn.close()
        reader = SqliteReader(str(db_path))
        assert reader.get_thresholds() == []
        reader.close()

    def test_get_violations(self, sample_db: Path) -> None:
        reader = SqliteReader(str(sample_db))
        violations = reader.get_violations()
        assert isinstance(violations, list)
        assert len(violations) == 1
        assert violations[0]["direction"] == "upper"
        assert violations[0]["label"] == "limit"
        assert len(violations[0]["x"]) == 2
        reader.close()

    def test_get_violations_missing_table(self, tmp_path: Path) -> None:
        """When the violations table doesn't exist, return empty list."""
        db_path = tmp_path / "empty.fpdb"
        conn = sqlite3.connect(str(db_path))
        conn.execute("""CREATE TABLE chunks (
            chunk_id INTEGER PRIMARY KEY,
            x_min REAL, x_max REAL, y_min REAL, y_max REAL,
            pt_offset INTEGER, pt_count INTEGER,
            x_data BLOB, y_data BLOB
        )""")
        conn.commit()
        conn.close()
        reader = SqliteReader(str(db_path))
        assert reader.get_violations() == []
        reader.close()


class TestMinmaxDownsample:
    """Tests for the minmax downsampling function."""

    def test_basic_downsampling(self) -> None:
        x = np.arange(100, dtype=np.float64)
        y = np.sin(x)
        x_ds, y_ds = _minmax_downsample(x, y, max_points=20)
        assert len(x_ds) <= 20
        assert len(y_ds) <= 20
        # Should preserve the overall min and max of y
        assert min(y_ds) <= min(y) + 1e-10
        assert max(y_ds) >= max(y) - 1e-10

    def test_preserves_extremes(self) -> None:
        """Min/max of each bucket should be preserved."""
        x = np.arange(10, dtype=np.float64)
        y = np.array([0, 5, 1, 8, 2, 7, 3, 6, 4, 9], dtype=np.float64)
        x_ds, y_ds = _minmax_downsample(x, y, max_points=4)
        # With 4 max_points, we get 2 buckets, each keeping min and max
        assert 9.0 in y_ds  # global max should be preserved
        assert 0.0 in y_ds  # global min should be preserved

    def test_single_bucket(self) -> None:
        x = np.array([1.0, 2.0, 3.0])
        y = np.array([10.0, 5.0, 15.0])
        x_ds, y_ds = _minmax_downsample(x, y, max_points=2)
        assert len(x_ds) == 2
        # Should keep min (5.0) and max (15.0)
        assert 5.0 in y_ds
        assert 15.0 in y_ds
