"""Geometry helpers for the data-pack tools: reducing spawn points to a few representative positions."""

from __future__ import annotations

import math
from collections.abc import Iterable, Sequence

__all__ = ["cluster"]


def cluster(points: Iterable[Sequence[float]], radius: float = 3.0, limit: int = 3) -> list[list[float]]:
    """Group points of one map (x, y in percent of the map) and return up to `limit` of them, biggest group first.

    Each point joins the group whose centre is nearest, if that centre is within `radius` (percent of the map), and
    otherwise starts a group. A group is represented by its member nearest the group's centre, so a position always
    lies on a real spawn point (never between two camps). Ties keep input order, so equal input gives equal output.
    Coordinates are rounded to 2 decimals.
    """
    if radius < 0:
        raise ValueError("radius must not be negative")
    groups: list[tuple[list[float], list[tuple[float, float]]]] = []  # ([sum_x, sum_y], members)
    for point in points:
        x, y = float(point[0]), float(point[1])
        best = None
        best_distance = 0.0
        for sums, members in groups:
            distance = math.hypot(sums[0] / len(members) - x, sums[1] / len(members) - y)
            if distance <= radius and (best is None or distance < best_distance):
                best, best_distance = (sums, members), distance
        if best is None:
            groups.append(([x, y], [(x, y)]))
        else:
            best[0][0] += x
            best[0][1] += y
            best[1].append((x, y))
    groups.sort(key=lambda group: -len(group[1]))  # stable: equal sizes keep the order they were found in
    result = []
    for sums, members in groups[: max(limit, 0)]:
        cx, cy = sums[0] / len(members), sums[1] / len(members)
        x, y = min(members, key=lambda member: math.hypot(member[0] - cx, member[1] - cy))
        result.append([round(x, 2), round(y, 2)])
    return result
