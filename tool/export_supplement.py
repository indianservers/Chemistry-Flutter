"""Extract offline isotope/ionic/oxidation records from mendeleev (MIT).

Download mendeleev/elements.db from lmmentel/mendeleev before running.
Units and primary references: https://mendeleev.readthedocs.io/en/stable/data.html
"""
import json
import sqlite3
from pathlib import Path

db=sqlite3.connect('tool/mendeleev.db')
db.row_factory=sqlite3.Row
result={}
for key,table,fields in [
 ('isotopes','isotopes','atomic_number,mass_number,mass,mass_uncertainty,abundance,abundance_uncertainty,is_radioactive,half_life,half_life_unit,half_life_uncertainty'),
 ('ionic_radii','ionicradii','atomic_number,charge,coordination,spin,ionic_radius,most_reliable'),
 ('oxidation_states','oxidationstates','atomic_number,oxidation_state,category')]:
 result[key]=[dict(row) for row in db.execute(f'SELECT {fields} FROM {table}')]
Path('assets/datasets/supplement.json').write_text(json.dumps(result,separators=(',',':')),encoding='utf-8')
print({key:len(value) for key,value in result.items()})
