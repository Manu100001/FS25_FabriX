#!/usr/bin/env bash
# Builds the ModHub release zip (FS25_FabriX.zip) next to this script.
# Only the files listed in INCLUDE end up in the zip.
set -euo pipefail

cd "$(dirname "$0")"

ZIP_NAME="FS25C_FabriX.zip"
INCLUDE=(
    modDesc.xml
    icon_FabriX.dds
    registerFabriX.lua
    l10n
    scripts
    xml
)

for path in "${INCLUDE[@]}"; do
    if [[ ! -e "$path" ]]; then
        echo "Missing: $path" >&2
        exit 1
    fi
done

if command -v xmllint >/dev/null; then
    xmllint --noout modDesc.xml l10n/*.xml xml/*.xml xml/gui/*.xml
fi

rm -f "$ZIP_NAME"
zip -r -X -q "$ZIP_NAME" "${INCLUDE[@]}" -x "*.DS_Store" -x "__MACOSX/*"

echo "Created $ZIP_NAME:"
unzip -l "$ZIP_NAME"
