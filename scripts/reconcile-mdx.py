"""Reconcile saved live MDX cellsets with an independent dbo warehouse snapshot."""
import argparse
import collections
import hashlib
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def group(rows, key):
    result = collections.defaultdict(list)
    for row in rows:
        result[key(row)].append(row)
    return result

def species(rows):
    return {r['species'] for r in rows if r['species'] and r['species'].strip()}

def sites(rows):
    return len({(r['lat'], r['lon']) for r in rows})

def ratio(numerator, denominator):
    return numerator / denominator if denominator else None

def basic(rows):
    return {'Record Count': len(rows), 'Recorded Species': len(species(rows)),
            'Sampled Sites': sites(rows)}

def member_key(member):
    name = member['unique_name']
    match = re.search(r'\.\&\[((?:[^\]]|\]\])*)\]$', name)
    if match is None:
        raise ValueError('Unexpected row member: ' + name)
    return match.group(1).replace(']]', ']')

def sst_group(r):
    value = r['sst']
    if value is None:
        return ''
    return '<25\u00b0C' if value < 25 else '25-27\u00b0C' if value < 27 else '27-29\u00b0C' if value < 29 else '>=29\u00b0C'

def sss_group(r):
    value = r['sss']
    return '-1' if value is None else '0' if value < 30 else '1' if value < 32 else '2'

def shore_group(r):
    value = r['shoredistance']
    return '-1' if value is None else '-2' if value < 0 else '0' if value < 10000 else '1' if value < 50000 else '2'

def reconcile(snapshot, result_dir, output):
    rows = json.loads(snapshot.read_text(encoding='utf-8-sig'))
    assert len(rows) == 108680
    assert sorted({r['year'] for r in rows}) == list(range(1980, 2027))
    reports = []
    total_cells = 0
    for number in range(1, 16):
        path = next(result_dir.glob(f'{number:02d}_*.json'))
        actual = json.loads(path.read_text(encoding='utf-8-sig'))
        assert actual['status'] == 'PASS', path.name
        columns = actual['columns']
        actual_rows = {}
        for row in actual['rows']:
            key = tuple(member_key(m) for m in row['members'])
            if key in actual_rows:
                raise AssertionError(('Duplicate output row', number, key))
            actual_rows[key] = dict(zip(columns, row['values']))
        errors = []
        rank_checks = []
        expected = {}
        if number == 1:
            baseline = json.loads((ROOT/'evidence/mdx-q01-validation.json').read_text(encoding='utf-8'))['sql_baseline']
            expected = {(r['Decade'],): {k:v for k,v in r.items() if k != 'Decade'} for r in baseline}
        elif number == 2:
            kingdoms = group([r for r in rows if r['kingdom']], lambda r:r['kingdom'])
            if len(actual_rows) != len(kingdoms):
                errors.append('Expected one winning season for each known canonical kingdom')
            seen = set()
            for key in actual_rows:
                kingdom, season = key
                if kingdom not in kingdoms or kingdom in seen:
                    errors.append('Unknown or duplicated kingdom '+kingdom)
                    continue
                seen.add(kingdom)
                seasons = group(kingdoms[kingdom], lambda r:r['season'])
                n = len(seasons.get(season, []))
                if n != max(map(len, seasons.values())):
                    errors.append('Winning season is not maximal for '+kingdom)
                expected[key] = {'Record Count':n, 'Season Record Share':ratio(n,len(kingdoms[kingdom]))}
            rank_checks.append('One maximal season per known kingdom; ties may select one winner')
        elif number == 3:
            expected = {key:basic(rs) for key,rs in group(rows,lambda r:(r['country'] or '',r['decade'])).items()}
        elif number == 4:
            subset = [r for r in rows if r['kingdom']=='Animalia' and r['class'] and r['decade'] in ('2000s','2010s') and (10<=r['lat']<15 or 20<=r['lat']<=23) and r['depth_band'] in (1,2)]
            classes = group(subset,lambda r:r['class'])
            scores = {c:len(species(rs)) for c,rs in classes.items()}
            chosen = {key[0] for key in actual_rows}
            if len(chosen) != min(3,len(classes)):
                errors.append('Expected exactly three pooled classes')
            if chosen and any(score>min(scores.get(c,-1) for c in chosen) for c,score in scores.items() if c not in chosen):
                errors.append('A higher-richness pooled class was omitted')
            expected = {key:basic(rs) for key,rs in group([r for r in subset if r['class'] in chosen],lambda r:(r['class'],r['decade'],r['latitude_band'])).items()}
            rank_checks.append({'pooled_top_classes':{c:scores.get(c) for c in sorted(chosen)}})
        elif number == 5:
            labels={0:'Unknown',1:'Coastal/surface (<50 m)',2:'Continental shelf (50-200 m)',3:'Continental slope (200-1000 m)',4:'Deep sea (>=1000 m)'}
            expected={key:basic(rs) for key,rs in group(rows,lambda r:(labels[r['depth_band']],r['latitude_band'])).items()}
        elif number == 6:
            subset=[r for r in rows if r['shoredistance'] is not None and r['shoredistance']>=0]
            expected={key:basic(rs) for key,rs in group(subset,lambda r:(r['decade'],sst_group(r),sss_group(r),shore_group(r))).items()}
        elif number == 7:
            pools=group(rows,lambda r:(r['decade'],r['grid_cell']))
            scores={key:len(species(rs)) for key,rs in pools.items() if species(rs)}
            for decade in sorted({r['decade'] for r in rows}):
                chosen={key for key in actual_rows if key[0]==decade}
                available={key:score for key,score in scores.items() if key[0]==decade}
                if len(chosen)!=min(5,len(available)):
                    errors.append('Expected five eligible grids for '+decade)
                if chosen and any(score>min(scores.get(key,-1) for key in chosen) for key,score in available.items() if key not in chosen):
                    errors.append('Higher-richness grid omitted in '+decade)
            expected={key:basic(pools[key]) for key in actual_rows if key in pools}
            rank_checks.append('Five highest-richness cells independently within each decade; remaining ties excluded')
        elif number == 8:
            pools=group([r for r in rows if r['kingdom']=='Animalia' and r['class']],lambda r:(r['class'],r['decade']))
            expected={key:{**basic(rs),'Latitude Centroid':sum(r['lat'] for r in rs)/len(rs)} for key,rs in pools.items()}
        elif number == 9:
            pools=group([r for r in rows if r['species']],lambda r:(r['species'],r['decade']))
            for key,rs in pools.items():
                low=min(r['lat'] for r in rs);high=max(r['lat'] for r in rs)
                expected[key]={**basic(rs),'Latitude Minimum':low,'Latitude Maximum':high,'Latitude Range':high-low}
        elif number == 10:
            pools=group([r for r in rows if r['lat']>=15],lambda r:r['decade'])
            decades=sorted({r['decade'] for r in rows})
            for i,decade in enumerate(decades):
                rs=pools.get(decade,[]);current=len(species(rs));previous=len(species(pools[decades[i-1]])) if i>0 and pools.get(decades[i-1]) else None
                delta=current-previous if rs and previous is not None else None
                expected[(decade,)]={'Recorded Species':current,'Previous Decade Species':previous,'Species Change':delta,'Species Change Pct':ratio(delta,previous) if delta is not None else None,'Record Count':len(rs) if rs else None}
        elif number == 11:
            pools=group([r for r in rows if r['lat']>=20],lambda r:r['year']);cumulative=set()
            for year in range(1980,2027):
                rs=pools.get(year,[]);before=len(cumulative);cumulative.update(species(rs))
                expected[(str(year),)]={'New Northern Species':len(cumulative)-before,'Cumulative Northern Species':len(cumulative),'Record Count':len(rs) if rs else None,'Sampled Sites':sites(rs)}
        elif number == 12:
            pools=group([r for r in rows if r['species']],lambda r:r['species']);eligible={}
            for name,rs in pools.items():
                values=[r['sst'] for r in rs if r['sst'] is not None]
                if values:eligible[(name,)]={**basic(rs),'SST Minimum':min(values),'SST Maximum':max(values),'SST Span':max(values)-min(values)}
            if len(actual_rows)!=min(15,len(eligible)):
                errors.append('Expected fifteen species with observed SST')
            chosen=set(actual_rows)
            if chosen:
                threshold=min(eligible.get(key,{'SST Span':-1})['SST Span'] for key in chosen)
                if any(value['SST Span']>threshold+1e-9 for key,value in eligible.items() if key not in chosen):
                    errors.append('A larger SST span species was omitted')
            expected={key:eligible[key] for key in actual_rows if key in eligible}
            rank_checks.append('Fifteen largest observed SST spans; record/site counts include all observations of each selected species')
        elif number == 13:
            pools=group([r for r in rows if r['kingdom']=='Animalia'],lambda r:(r['decade'],r['latitude_band']))
            for key,rs in pools.items():
                known=sum(r['depth_band'] in (1,2,3,4) for r in rs);deep=sum(r['depth_band'] in (3,4) for r in rs)
                expected[key]={'Record Count':len(rs),'Depth Known Records':known,'Deep Records':deep,'Deep Record Pct':ratio(deep,known),'Depth Known Pct':ratio(known,len(rs))}
        elif number == 14:
            for key,rs in group(rows,lambda r:(r['country'] or '',)).items():
                onland=sum(r['on_land'] for r in rs);present=sum(r['status']=='present' for r in rs)
                expected[key]={'Record Count':len(rs),'On Land Records':onland,'On Land Pct':ratio(onland,len(rs)),'Present Records':present,'Present Status Pct':ratio(present,len(rs))}
        elif number == 15:
            denominators=collections.Counter((r['latitude_band'],r['decade']) for r in rows)
            for key,rs in group(rows,lambda r:(r['country'] or '',r['latitude_band'],r['decade'])).items():
                values=[r['individuals'] for r in rs if r['individuals'] is not None]
                expected[key]={**basic(rs),'Country Record Share':ratio(len(rs),denominators[(key[1],key[2])]),'Reported Count Total':sum(values) if values else None,'Individual Count Records':len(values),'Individual Count Coverage':ratio(len(values),len(rs))}
        missing=set(expected)-set(actual_rows);extra=set(actual_rows)-set(expected)
        if missing:errors.append({'missing_rows':len(missing),'examples':sorted(missing)[:3]})
        if extra:errors.append({'extra_rows':len(extra),'examples':sorted(extra)[:3]})
        checked=0;max_diff=0.0
        for key in set(expected)&set(actual_rows):
            for column in columns:
                actual_value=actual_rows[key][column];expected_value=expected[key][column];checked+=1
                if actual_value is None or expected_value is None:
                    valid=actual_value is None and expected_value is None
                else:
                    delta=abs(float(actual_value)-float(expected_value));max_diff=max(max_diff,delta)
                    valid=math.isclose(float(actual_value),float(expected_value),rel_tol=1e-9,abs_tol=1e-8)
                if not valid and len(errors)<25:errors.append({'key':key,'metric':column,'mdx':actual_value,'dbo_baseline':expected_value})
        total_cells+=checked
        item={'number':number,'query':actual['query'],'execution_status':actual['status'],'reconciliation_status':'PASS' if not errors else 'FAIL','rows':actual['row_count'],'columns':len(columns),'checked_cells':checked,'max_absolute_difference':max_diff,'elapsed_ms':actual['elapsed_ms'],'rank_checks':rank_checks,'differences':errors}
        reports.append(item)
        print(f"Q{number:02d}: {item['reconciliation_status']} rows={item['rows']} cells={checked} differences={len(errors)}")
        if errors:print(json.dumps(errors[:5],ensure_ascii=True))
    summary={'server':'localhost','database':'MARINE_SHIFT_RANGE_SSAS','cube':'MARINE SHIFT RANGE DW','warehouse_snapshot_sha256':hashlib.sha256(snapshot.read_bytes()).hexdigest(),'warehouse_records':len(rows),'queries_executed':len(reports),'queries_reconciled':sum(r['reconciliation_status']=='PASS' for r in reports),'cells_checked':total_cells,'status':'PASS' if all(r['reconciliation_status']=='PASS' for r in reports) else 'FAIL','queries':reports,'basis':'Independent aggregation of a read-only snapshot joined from the six dbo tables; normalized Dim_Taxon taxonomy, not raw CSV taxonomy','tie_policy':'TOPCOUNT returns exactly N and excludes remaining tied members; correctness checks permit any member tied at the cutoff'}
    output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f"TOTAL {summary['status']} reconciled={summary['queries_reconciled']}/15 cells={total_cells}")
    return summary['status']=='PASS'

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--snapshot',type=Path,required=True);parser.add_argument('--results',type=Path,required=True);parser.add_argument('--output',type=Path,default=ROOT/'evidence/mdx-suite-validation.json');args=parser.parse_args()
    raise SystemExit(0 if reconcile(args.snapshot,args.results,args.output) else 1)
