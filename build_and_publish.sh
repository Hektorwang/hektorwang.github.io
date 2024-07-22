#!/bin/bash

BASE_DIR="$(readlink -f "$0")"
DOCS_DIR="${BASE_DIR}/docs"
# Iterating docs directory and modify mkdocs.yml
# Publish to github pages
echo To build and publish github pages:
echo "python3 generate_config.py | mkdocs gh-deploy -f -"
