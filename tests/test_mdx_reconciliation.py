"""Regression checks for the revised analytical scopes, independent of an SSAS server."""
import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('mdx_reconcile', Path(__file__).resolve().parents[1] / 'scripts/reconcile-mdx.py')
mdx = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mdx)


class RevisedQueryScopes(unittest.TestCase):
    def test_q4_pools_both_decades_and_all_latitudes_without_double_counting_species(self):
        def observation(**changes):
            return dict(kingdom='Animalia', **{'class': 'Fish'}, decade='2000s',
                        depth_band=1, lat=2.0, species='Species A') | changes
        rows = [observation(), observation(decade='2010s', lat=18.0),
                observation(lat=22.0, species='Species B', depth_band=2),
                observation(depth_band=0, species='Missing depth'),
                observation(depth_band=3, species='At or below 200 m'),
                observation(decade='1990s', species='Outside period'),
                observation(decade='2020s', species='Outside period'),
                observation(kingdom='Plantae', species='Outside kingdom'),
                observation(**{'class': ''}, species='Unknown class')]
        pools = mdx.animalia_class_pools(rows)
        self.assertEqual(set(pools), {'Fish'})
        self.assertEqual(len(pools['Fish']), 3)
        self.assertEqual(mdx.species(pools['Fish']), {'Species A', 'Species B'})

    def test_q6_retains_inland_unknown_and_boundary_distance_groups(self):
        distances = [-1, None, 0, 9999, 10000, 49999, 50000]
        rows = [dict(decade='2010s', sst=None, sss=None, shoredistance=value)
                for value in distances]
        pools = mdx.environment_pools(rows)
        self.assertEqual(sum(map(len, pools.values())), 7)
        self.assertEqual({key[3] for key in pools}, {'-2', '-1', '0', '1', '2'})
        self.assertEqual(len(pools[('2010s', '', '-1', '0')]), 2)
        self.assertEqual(len(pools[('2010s', '', '-1', '1')]), 2)
        self.assertEqual(len(pools[('2010s', '', '-1', '2')]), 1)


if __name__ == '__main__':
    unittest.main()
