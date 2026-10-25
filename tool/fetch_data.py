"""Refresh public offline snapshots using Python's standard library.

Existing application JSON is replaced only after all required records are read.
Review upstream licenses, source changes and scientific data before releasing.
"""
import json
import time
import urllib.request
from pathlib import Path

PRESETS=[('Hydrogen',783),('Water',962),('Oxygen',977),('Nitrogen',947),
 ('Methane',297),('Ethane',6324),('Ethene',6325),('Ethyne',6326),
 ('Ethanol',702),('Methanol',887),('Benzene',241),('Carbon dioxide',280),
 ('Ammonia',222),('Acetic acid',176),('Acetone',180),('Glucose',5793),
 ('Glycerol',753),('Lactic acid',612),('Caffeine',2519),('Aspirin',2244)]
ROOT=Path('assets/datasets')
def get(url):
    with urllib.request.urlopen(url,timeout=45) as response:
        return response.read()

def main():
    molecules=[]
    for name,cid in PRESETS:
        if cid==783:
            atoms=[dict(id=1,number=1,x=-.3707,y=0,z=0,charge=0),dict(id=2,number=1,x=.3707,y=0,z=0,charge=0)]
            bonds=[dict(a=1,b=2,order=1)]
            source='Idealized diatomic H2; bond length 0.7414 Å (NIST CCCBDB)'
        else:
            raw=json.loads(get(f'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/{cid}/record/JSON?record_type=3d'))['PC_Compounds'][0]
            coords=raw['coords'][0]['conformers'][0]
            charges={a['aid']:a['value'] for a in raw['atoms'].get('charge',[])}
            atoms=[dict(id=aid,number=raw['atoms']['element'][i],x=coords['x'][i],y=coords['y'][i],z=coords['z'][i],charge=charges.get(aid,0)) for i,aid in enumerate(raw['atoms']['aid'])]
            bonds=[dict(a=a,b=b,order=order) for a,b,order in zip(raw['bonds']['aid1'],raw['bonds']['aid2'],raw['bonds']['order'])]
            source=f'https://pubchem.ncbi.nlm.nih.gov/compound/{cid}'
            time.sleep(.25)
        molecules.append(dict(id=f'pubchem-{cid}',cid=cid,name=name,atoms=atoms,bonds=bonds,source=source))
    cids=','.join(str(cid) for _,cid in PRESETS)
    props=json.loads(get(f'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/{cids}/property/HBondDonorCount,HBondAcceptorCount,IUPACName,IsomericSMILES/JSON'))['PropertyTable']['Properties']
    for molecule in molecules:
        row=next(p for p in props if p['CID']==molecule['cid'])
        molecule['properties']=dict(hbd=row['HBondDonorCount'],hba=row['HBondAcceptorCount'],iupac=row['IUPACName'],smiles=row.get('SMILES'))
    ROOT.joinpath('molecules.json').write_text(json.dumps(molecules,ensure_ascii=False,indent=2),encoding='utf-8')
    ROOT.joinpath('elements.json').write_bytes(get('https://raw.githubusercontent.com/Bowserinator/Periodic-Table-JSON/master/PeriodicTableJSON.json'))
    Path('tool/mendeleev.db').write_bytes(get('https://raw.githubusercontent.com/lmmentel/mendeleev/master/mendeleev/elements.db'))
    import export_supplement
    import dataset_manifest

if __name__=='__main__':
    main()
