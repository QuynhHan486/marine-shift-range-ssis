"""Check the imported laptop project and its deployable build without running ETL."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'ssis_demo'
DTS = '{www.microsoft.com/SqlServer/Dts}'
SSIS = '{www.microsoft.com/SqlServer/SSIS}'


def canonical_xml(data):
    root = ET.fromstring(data)
    for node in root.iter():
        if node.text is not None and not node.text.strip():
            node.text = None
        node.tail = None
    return ET.tostring(root)


class LaptopSSISProject(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.package = ET.parse(PROJECT / 'MarineOccurrenceETL.dtsx').getroot()
        cls.tasks = {task.get(DTS + 'ObjectName'): task for task in
                     cls.package.findall(DTS + 'Executables/' + DTS + 'Executable')}

    def test_project_references_and_supplied_build_match_sources(self):
        project = ET.parse(PROJECT / 'marineRangeShift_SSIS_demo.dtproj').getroot()
        self.assertEqual(project.findtext('DeploymentModel'), 'Project')
        self.assertEqual(project.findtext('.//TargetServerVersion'), 'SQLServer2025')
        package_files = [node.get(SSIS + 'Name') for node in project.iter(SSIS + 'Package')]
        connection_files = [node.get(SSIS + 'Name') for node in project.iter(SSIS + 'ConnectionManager')]
        self.assertEqual(package_files, ['MarineOccurrenceETL.dtsx'])
        self.assertEqual(connection_files, ['marineRangeShift_warehouse_demo.conmgr'])
        for name in package_files + connection_files + ['Project.params']:
            self.assertTrue((PROJECT / name).is_file())
        with zipfile.ZipFile(PROJECT / 'marineRangeShift_SSIS_demo.ispac') as build:
            for name in package_files + connection_files + ['Project.params']:
                self.assertEqual(canonical_xml(build.read(name)),
                                 canonical_xml((PROJECT / name).read_bytes()), name)
        for solution in [ROOT / 'MARINE_SHIFT_RANGE.slnx',
                         PROJECT / 'marineRangeShift_SSIS_demo.slnx']:
            for reference in ET.parse(solution).iter('Project'):
                self.assertTrue((solution.parent / reference.get('Path')).is_file())

    def test_five_flows_load_dimensions_before_fact_with_valid_connections(self):
        expected = ['Load Dim_Date', 'Load Dim_Taxon', 'Load Dim_Location',
                    'Load Dim_Quality', 'Load Fact_Occurrence']
        self.assertEqual(set(self.tasks), set(expected))
        constraints = self.package.findall(DTS + 'PrecedenceConstraints/' + DTS + 'PrecedenceConstraint')
        self.assertEqual(len(constraints), 4)
        edges = {(node.get(DTS + 'From'), node.get(DTS + 'To')) for node in constraints}
        self.assertEqual(edges, {('Package\\' + left, 'Package\\' + right)
                                 for left, right in zip(expected, expected[1:])})
        warehouse = ET.parse(PROJECT / 'marineRangeShift_warehouse_demo.conmgr').getroot()
        warehouse_reference = 'Project.ConnectionManagers[' + warehouse.get(DTS + 'ObjectName') + ']'
        for task in self.tasks.values():
            self.assertEqual(task.get(DTS + 'ExecutableType'), 'Microsoft.Pipeline')
            pipeline = task.find(DTS + 'ObjectData/pipeline')
            refs = {node.get('refId') for node in pipeline.iter() if node.get('refId')}
            for path in pipeline.findall('paths/path'):
                self.assertIn(path.get('startId'), refs)
                self.assertIn(path.get('endId'), refs)
            for connection in pipeline.findall('components/component/connections/connection'):
                self.assertIn(connection.get('connectionManagerRefId'),
                              {'Package.ConnectionManagers[OBIS]', warehouse_reference})
        source = self.package.find(DTS + 'ConnectionManagers/' + DTS + 'ConnectionManager')
        self.assertEqual(source.get(DTS + 'ObjectName'), 'OBIS')
        columns = source.findall('.//' + DTS + 'FlatFileColumn')
        self.assertEqual(len(columns), 23)

    def test_fact_lookups_return_integer_ids_and_map_all_nine_columns(self):
        pipeline = self.tasks['Load Fact_Occurrence'].find(DTS + 'ObjectData/pipeline')
        lookups = {node.get('name'): node for node in pipeline.findall('components/component')
                   if node.get('componentClassID') == 'Microsoft.Lookup'}
        for name, alias in [('Date', 'lk_date_id'), ('Taxon', 'lk_taxon_id'),
                            ('Location', 'lk_location_id'), ('Depth', 'lk_depth_band_id'),
                            ('Quality', 'lk_quality_id')]:
            output = lookups['Lookup ' + name].find(
                f"outputs/output/outputColumns/outputColumn[@name='{alias}']")
            self.assertIsNotNone(output)
            self.assertEqual(output.get('dataType'), 'i4')
            self.assertEqual(output.findtext("properties/property[@name='CopyFromReferenceColumn']"), 'id')
        destination = next(node for node in pipeline.findall('components/component')
                           if node.get('componentClassID') == 'Microsoft.OLEDBDestination')
        metadata = {node.get('refId'): node.get('name') for node in
                    destination.findall('inputs/input/externalMetadataColumns/externalMetadataColumn')}
        mappings = {node.get('cachedName'): metadata[node.get('externalMetadataColumnId')]
                    for node in destination.findall('inputs/input/inputColumns/inputColumn')}
        self.assertEqual(mappings, {
            'occurrence_id': 'id', 'lk_date_id': 'date_id', 'lk_taxon_id': 'taxon_id',
            'lk_location_id': 'location_id', 'lk_depth_band_id': 'depth_band_id',
            'lk_quality_id': 'quality_id', 'v_depth': 'depth', 'v_count': 'individualCount',
            'occurrence_count': 'occurrence_count'})


if __name__ == '__main__':
    unittest.main()
