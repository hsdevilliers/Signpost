import unittest

from signpost_tools.geo import cluster


class ClusterTest(unittest.TestCase):
    def test_groups_nearby_points_biggest_group_first(self):
        points = [(60, 60), (44, 61), (44.5, 61.5), (60.5, 60.2), (45, 61)]
        self.assertEqual(cluster(points, radius=3, limit=3), [[44.5, 61.5], [60, 60]])

    def test_representative_is_a_real_point_nearest_the_centre(self):
        # a ring of camps around an empty middle: the centre (50, 50) is no spawn, so a member stands for the group
        ring = [(48, 50), (52, 50), (50, 48), (50, 52.5)]
        [(x, y)] = cluster(ring, radius=5, limit=1)
        self.assertIn((x, y), ring)

    def test_limit_and_empty_input(self):
        points = [(10, 10), (20, 20), (30, 30), (40, 40)]
        self.assertEqual(len(cluster(points, radius=1, limit=3)), 3)
        self.assertEqual(cluster(points, radius=1, limit=0), [])
        self.assertEqual(cluster([], radius=3, limit=3), [])

    def test_radius_zero_only_merges_identical_points(self):
        self.assertEqual(cluster([(1, 1), (1, 1), (1.01, 1)], radius=0, limit=5), [[1, 1], [1.01, 1]])

    def test_point_joins_the_nearest_group(self):
        # (14.2, 10) is within reach of both groups' centres; it joins the nearer one, which becomes the biggest
        points = [(10, 10), (17, 10), (14.2, 10)]
        self.assertEqual(cluster(points, radius=5, limit=2), [[17, 10], [10, 10]])

    def test_deterministic_and_rounded(self):
        points = [(12.3456, 45.6789), (12.3456, 45.6789), (70.111, 20.999)]
        self.assertEqual(cluster(points), cluster(list(points)))
        self.assertEqual(cluster(points), [[12.35, 45.68], [70.11, 21.0]])

    def test_negative_radius_is_rejected(self):
        with self.assertRaises(ValueError):
            cluster([(1, 1)], radius=-1)


if __name__ == "__main__":
    unittest.main()
