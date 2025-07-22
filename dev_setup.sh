#!/usr/bin/env bash
set -euo pipefail

#Todo: functionalize this.
# howdy. this script is gonna initialize the dev environment so that everything works properly.

# next we should set up the env and install our linters and whatnot.
uv venv
source .venv/bin/activate
uv pip install -r dev_deps.txt

# now install the pre-commit hooks
pre-commit install

echo "Dev environment has been setup! execute the following command to begin:"
echo "source .venv/bin/activate"
#do NOT.
#echo "If you forgot to rename this directory, do so, delete .git && .venv then try running this script again!"
exit 0
