# Querying `index.json`

Copy-paste recipes for the most common questions. Index lives at
`.flutter-pipeline/index.json` (schema: `index_schema.json`). All examples assume
you run from the app root.

Two flavours per query: **jq** (if installed) and **python3 -c** (always
available, stdlib only). The python form is the safe default in this pipeline.

> Tip for skills: read `.counts` first (one line) to decide whether you even need
> the full entity list. Each entity carries `file` + `line`, so once you have a
> hit you can `Read` the exact spot instead of scanning the tree.

---

## Setup (python helper)

```bash
IDX=.flutter-pipeline/index.json
q() { python3 -c "import json,sys; d=json.load(open('$IDX')); $1"; }
```

Then: `q "print(d['counts'])"`.

---

## Summary header

```bash
jq '.counts' "$IDX"
python3 -c "import json;print(json.load(open('$IDX'))['counts'])"
```

## List all routes (path + name + where defined)

```bash
jq -r '.entities[]|select(.kind=="route")|"\(.path)\t\(.name)\t\(.file):\(.line)"' "$IDX"
```
```bash
python3 -c "import json;[print(e['path'],e['name'],f\"{e['file']}:{e['line']}\") for e in json.load(open('$IDX'))['entities'] if e['kind']=='route']"
```

## "Where is auth state?" (find a provider by fuzzy name)

```bash
jq -r '.entities[]|select(.kind=="provider" and (.name|test("auth";"i")))|"\(.name)\t\(.style)\t\(.file):\(.line)"' "$IDX"
```
```bash
python3 -c "import json;[print(e['name'],e['style'],f\"{e['file']}:{e['line']}\") for e in json.load(open('$IDX'))['entities'] if e['kind']=='provider' and 'auth' in e['name'].lower()]"
```

## List every provider, grouped by style

```bash
jq -r '.entities[]|select(.kind=="provider")|"\(.style)\t\(.name)\t\(.file):\(.line)"' "$IDX" | sort
```

## All screens and their widget base

```bash
jq -r '.entities[]|select(.kind=="screen")|"\(.base)\t\(.name)\t\(.file)"' "$IDX" | sort
```

## Repository interfaces and their implementations

```bash
jq -r '.entities[]|select(.kind=="repository")|"\(.role)\t\(.name)\t\(.implements // "-")\t\(.file):\(.line)"' "$IDX"
```

## All freezed models

```bash
jq -r '.entities[]|select(.kind=="model")|"\(.name)\t\(.file):\(.line)"' "$IDX"
```

## Everything in one feature (e.g. `auth`)

```bash
jq -r '.entities[]|select(.feature=="auth")|"\(.kind)\t\(.name)\t\(.file):\(.line)"' "$IDX"
```
```bash
python3 -c "import json;[print(e['kind'],e['name'],f\"{e['file']}:{e['line']}\") for e in json.load(open('$IDX'))['entities'] if e.get('feature')=='auth']"
```

## "What does file X depend on?" (outgoing edges)

```bash
jq -r '.files[]|select(.file=="lib/features/auth/presentation/login_page.dart")|.dependsOn[]' "$IDX"
```

## "What depends on X?" (reverse edges — impact of a change)

```bash
jq -r --arg t "lib/core/error/result.dart" \
  '.files[]|select(.dependsOn|index($t))|.file' "$IDX"
```
```bash
python3 -c "import json,sys;t='lib/core/error/result.dart';[print(f['file']) for f in json.load(open('$IDX'))['files'] if t in f['dependsOn']]"
```

## Find an entity's exact location to Read it

```bash
jq -r '.entities[]|select(.name=="CatalogController")|"\(.file):\(.line)"' "$IDX"
```

## Sanity / drift check: entities whose file no longer exists

```bash
python3 -c "import json,os;d=json.load(open('$IDX'));[print('STALE',e['file']) for e in d['entities'] if e['kind']!='feature' and not os.path.exists(e['file'])]"
```
If anything prints, run `build_index.py` (or `--incremental`) to refresh.

## Export nodes+edges for graphify

```bash
# nodes = entity ids; edges = file-level dependsOn between entities' files
python3 - "$IDX" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
nodes=[{"id":e["id"],"kind":e["kind"],"label":e["name"]} for e in d["entities"]]
print(json.dumps({"nodes":nodes,"edges":[{"from":f["file"],"to":t} for f in d["files"] for t in f["dependsOn"]]},indent=2))
PY
```
