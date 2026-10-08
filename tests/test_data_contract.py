"""Portable checks of the supplied source and SSIS artifact; SQL tests are separate."""
import csv
import datetime as dt
import hashlib
import json
import unittest
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

class DataContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest=json.loads((ROOT/'data/manifest.json').read_text(encoding='utf-8-sig'))
        with (ROOT/'data/occurrence_clean.csv').open(encoding='utf-8-sig',newline='') as f:
            reader=csv.DictReader(f);cls.columns=reader.fieldnames;cls.rows=list(reader)

    def test_source_identity(self):
        self.assertEqual(len(self.rows),108680)
        self.assertEqual(len(self.columns),24)
        self.assertEqual(len({r['id'] for r in self.rows}),len(self.rows))
        self.assertEqual(hashlib.sha256((ROOT/'data/occurrence_clean.csv').read_bytes()).hexdigest(),self.manifest['sha256'])

    def test_dates_and_study_area(self):
        dates=[dt.datetime.strptime(r['eventDate'],'%d/%m/%Y').date() for r in self.rows]
        self.assertEqual((min(dates),max(dates)),(dt.date(1980,1,1),dt.date(2026,7,13)))
        self.assertTrue(all(0<=float(r['decimalLatitude'])<=23 and 99<=float(r['decimalLongitude'])<=121 for r in self.rows))
        self.assertTrue(all(r['scientificName'] for r in self.rows))

    def test_dimension_cardinalities(self):
        self.assertEqual(len({r['eventDate'] for r in self.rows}),2314)
        self.assertEqual(len({r['scientificName'] for r in self.rows}),7737)
        loc=['decimalLatitude','decimalLongitude','country','shoredistance','sst','sss']
        self.assertEqual(len({tuple(r[c] for c in loc) for r in self.rows}),3067)
        q=['flag_on_land','flags','occurrenceStatus','flag_marine_unsure']
        self.assertEqual(len({tuple(r[c] for c in q) for r in self.rows}),26)

    def test_missing_measures_and_flags(self):
        self.assertEqual(sum(not r['depth'] for r in self.rows),46440)
        self.assertEqual(sum(not r['individualCount'] for r in self.rows),67044)
        self.assertEqual(sum(r['flag_on_land']=='TRUE' for r in self.rows),5090)
        self.assertTrue(all(r['occurrenceStatus'] in ('','present','absent') for r in self.rows))
        self.assertTrue(all(('ON_LAND' in r['flags'])==(r['flag_on_land']=='TRUE') for r in self.rows))

    def test_native_ssis_artifacts(self):
        ns={'d':'www.microsoft.com/SqlServer/Dts'}
        package=ET.parse(ROOT/'ssis/Package.dtsx').getroot()
        tasks=package.find('d:Executables',ns)
        self.assertEqual(len(tasks),11)
        flows=[t for t in tasks if 'Pipeline' in t.get('{'+ns['d']+'}ExecutableType','')]
        self.assertEqual(len(flows),7)
        self.assertEqual(len(package.find('d:PrecedenceConstraints',ns)),10)
        self.assertEqual(package.get('{'+ns['d']+'}ProtectionLevel'),'0')
        self.assertEqual(len(package.find('d:EventHandlers',ns)),1)
        with zipfile.ZipFile(ROOT/'MARINE_SHIFT_RANGE_SSIS.ispac') as z:
            self.assertIn('Package.dtsx',z.namelist())
            ET.fromstring(z.read('Package.dtsx'))

if __name__=='__main__': unittest.main()
