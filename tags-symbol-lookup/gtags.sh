#!/usr/bin/env bash
set -euo pipefail

# debian install:
#   apt install global universal-ctags python3-pygments
#
# Parser strategy: native-pygments
#   Built-in parser first (fast, covers C/C++/Java/PHP/Yacc/asm).
#   Falls back to pygments for everything else (JS/TS/JSX/Vue/Kotlin/Rust/...).
#   Plain new-ctags misses many JS class/function definitions; pygments fills the gap.

# Safety: refuse to run unless cwd is a git repo root. Prevents the rm -rf below
# from clobbering same-named dirs in an unrelated cwd.
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$repo_root" ] || [ "$PWD" != "$repo_root" ]; then
  echo "gtags.sh: must run from a git repository root (cwd=$PWD)" >&2
  exit 1
fi

rm -rf gtags_tmp tags gtags.files
mkdir -p gtags_tmp tags
export TMPDIR=./gtags_tmp

# pygments_parser.py shebang is `#!/usr/bin/env python`, but Debian 13 only ships
# python3. Prepend a shim dir so the parser can resolve `python` without sudo.
if ! command -v python >/dev/null 2>&1; then
  PYSHIM="$(mktemp -d)"
  ln -sf "$(command -v python3)" "$PYSHIM/python"
  export PATH="$PYSHIM:$PATH"
  trap 'rm -rf "$PYSHIM"' EXIT
fi

# User's ~/.globalrc usually lacks the pygments/native-pygments labels; point at
# the system config that defines them.
export GTAGSCONF=/etc/gtags/gtags.conf
export GTAGSLABEL=native-pygments
gtags --version

# Only feed gtags real source files. Add/remove extensions to taste.
fdfind --type f --hidden \
  --exclude .git --exclude node_modules --exclude build --exclude dist \
  --exclude target --exclude vendor --exclude .venv --exclude __pycache__ \
  --exclude gtags_tmp --exclude tags \
  -e java -e kt -e scala -e groovy \
  -e js -e jsx -e ts -e tsx -e mjs -e cjs -e vue \
  -e py -e go -e rs -e rb -e php \
  -e c -e h -e cc -e cpp -e cxx -e hpp -e hh \
  -e cs -e swift -e m -e mm \
  -e sh -e bash -e zsh -e lua -e pl \
  -e sql \
  -e gradle -e gradle.kts \
  -e proto -e tf -e toml \
  -e yaml -e yml -e xml \
  > gtags.files

# -f reads file list explicitly; ./tags is the dbpath
gtags -f gtags.files ./tags

rm -rf "$TMPDIR"
echo "Done. Query with: GTAGSDBPATH=$PWD/tags GTAGSROOT=$PWD global -d <symbol>"
