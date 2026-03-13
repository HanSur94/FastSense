"""Read FastPlotDataStore SQLite files and decode typed BLOBs.

Opens .fpdb files in read-only mode and provides methods to query chunks
by x-range, decode mksqlite typed BLOBs, and optionally apply minmax
downsampling to limit the number of points returned.
"""

import sqlite3

import numpy as np

from .blob_decoder import decode_typed_blob


class SqliteReader:
    """Synchronous reader for .fpdb files created by FastPlotDataStore.

    Opens the database in read-only mode (URI mode) so it can safely
    read while MATLAB writes with WAL mode enabled.
    """

    def __init__(self, db_path: str) -> None:
        self._conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        self._conn.row_factory = sqlite3.Row

    def close(self) -> None:
        """Close the database connection."""
        self._conn.close()

    def get_range(
        self, x_min: float, x_max: float, max_points: int = 0
    ) -> tuple[list[float], list[float]]:
        """Fetch X/Y data for chunks overlapping [x_min, x_max].

        Args:
            x_min: Lower bound of the x range.
            x_max: Upper bound of the x range.
            max_points: If > 0, apply minmax downsampling to limit output.

        Returns:
            Tuple of (x_values, y_values) as Python lists.
        """
        rows = self._conn.execute(
            "SELECT x_data, y_data FROM chunks "
            "WHERE x_max >= ? AND x_min <= ? ORDER BY x_min",
            (x_min, x_max),
        ).fetchall()

        if not rows:
            return [], []

        x_parts: list[np.ndarray] = []
        y_parts: list[np.ndarray] = []
        for row in rows:
            x_parts.append(decode_typed_blob(row["x_data"]))
            y_parts.append(decode_typed_blob(row["y_data"]))

        x = np.concatenate(x_parts)
        y = np.concatenate(y_parts)

        if max_points > 0 and len(x) > max_points:
            x, y = _minmax_downsample(x, y, max_points)

        return x.tolist(), y.tolist()

    def get_thresholds(self) -> list[dict]:
        """Fetch resolved thresholds from the database.

        Returns:
            List of threshold dicts with keys: direction, label,
            lineStyle, value, x, y, and optionally color.
        """
        try:
            rows = self._conn.execute(
                "SELECT * FROM resolved_thresholds ORDER BY idx"
            ).fetchall()
        except sqlite3.OperationalError:
            return []

        result: list[dict] = []
        for row in rows:
            entry: dict = {
                "direction": row["direction"],
                "label": row["label"],
                "lineStyle": row["line_style"],
                "value": row["value"],
                "x": [],
                "y": [],
            }
            if row["x_data"]:
                entry["x"] = decode_typed_blob(row["x_data"]).tolist()
            if row["y_data"]:
                entry["y"] = decode_typed_blob(row["y_data"]).tolist()
            if row["color"]:
                entry["color"] = decode_typed_blob(row["color"]).tolist()
            result.append(entry)
        return result

    def get_violations(self) -> list[dict]:
        """Fetch resolved violations from the database.

        Returns:
            List of violation dicts with keys: direction, label, x, y.
        """
        try:
            rows = self._conn.execute(
                "SELECT * FROM resolved_violations ORDER BY idx"
            ).fetchall()
        except sqlite3.OperationalError:
            return []

        result: list[dict] = []
        for row in rows:
            entry: dict = {
                "direction": row["direction"],
                "label": row["label"],
                "x": [],
                "y": [],
            }
            if row["x_data"]:
                entry["x"] = decode_typed_blob(row["x_data"]).tolist()
            if row["y_data"]:
                entry["y"] = decode_typed_blob(row["y_data"]).tolist()
            result.append(entry)
        return result

    def get_column(
        self, col_name: str, x_min: float, x_max: float
    ) -> list:
        """Fetch an extra column's data for a given X range.

        Args:
            col_name: Name of the column to read.
            x_min: Lower bound of the x range.
            x_max: Upper bound of the x range.

        Returns:
            Decoded column data as a list.
        """
        # Map x range to pt_offset range via chunks table
        chunk_rows = self._conn.execute(
            "SELECT pt_offset, pt_count FROM chunks "
            "WHERE x_max >= ? AND x_min <= ? ORDER BY x_min",
            (x_min, x_max),
        ).fetchall()
        if not chunk_rows:
            return []

        offset_min = chunk_rows[0]["pt_offset"]
        last = chunk_rows[-1]
        offset_max = last["pt_offset"] + last["pt_count"]

        rows = self._conn.execute(
            "SELECT col_data FROM columns "
            "WHERE col_name = ? AND pt_offset >= ? AND pt_offset < ? "
            "ORDER BY pt_offset",
            (col_name, offset_min, offset_max),
        ).fetchall()

        parts: list = []
        for row in rows:
            decoded = decode_typed_blob(row["col_data"])
            if isinstance(decoded, np.ndarray):
                parts.extend(decoded.tolist())
            elif isinstance(decoded, str):
                parts.append(decoded)
            else:
                parts.extend(decoded)
        return parts


def _minmax_downsample(
    x: np.ndarray, y: np.ndarray, max_points: int
) -> tuple[np.ndarray, np.ndarray]:
    """Downsample by keeping min and max per bucket (preserves peaks).

    Divides the data into max_points/2 buckets and keeps the minimum
    and maximum y-value point from each bucket, maintaining chronological
    order within each bucket.

    Args:
        x: X values (assumed sorted).
        y: Corresponding Y values.
        max_points: Target number of output points.

    Returns:
        Downsampled (x, y) arrays.
    """
    n = len(x)
    n_buckets = max_points // 2
    if n_buckets < 1:
        n_buckets = 1
    bucket_size = n / n_buckets

    x_out: list[float] = []
    y_out: list[float] = []
    for i in range(n_buckets):
        start = int(i * bucket_size)
        end = int((i + 1) * bucket_size)
        if start >= n:
            break
        end = min(end, n)
        segment_y = y[start:end]
        idx_min = start + int(np.argmin(segment_y))
        idx_max = start + int(np.argmax(segment_y))
        # Keep min before max to preserve visual shape
        if idx_min <= idx_max:
            x_out.extend([float(x[idx_min]), float(x[idx_max])])
            y_out.extend([float(y[idx_min]), float(y[idx_max])])
        else:
            x_out.extend([float(x[idx_max]), float(x[idx_min])])
            y_out.extend([float(y[idx_max]), float(y[idx_min])])

    return np.array(x_out), np.array(y_out)
