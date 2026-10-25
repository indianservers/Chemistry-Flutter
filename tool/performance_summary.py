import json
from pathlib import Path
j=json.loads(Path('build/integration_response_data.json').read_text())
print(list(j))
for k,v in j.items():
 print(k, type(v).__name__, list(v)[:15] if isinstance(v,dict) else '')
 if isinstance(v,dict) and k.startswith('rotation'):
  Path('docs/rotation-performance.json').write_text(json.dumps({a:b for a,b in v.items() if a!='traceEvents'},indent=2))
  print({a:b for a,b in v.items() if not isinstance(b,(list,dict))})
