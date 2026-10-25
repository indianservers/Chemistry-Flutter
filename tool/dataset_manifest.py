import hashlib,json
from pathlib import Path
root=Path('assets/datasets')
manifest={'retrieved':'2026-10-25','files':{}}
for name in ['elements.json','molecules.json','supplement.json']:
 raw=(root/name).read_bytes()
 manifest['files'][name]={'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw)}
(root/'dataset-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
