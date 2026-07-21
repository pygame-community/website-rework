#!/usr/bin/env bash

echo "Starting documentation generation..."

rm -rf pygame-ce public/docs

git clone --depth=1 https://github.com/pygame-community/pygame-ce.git

cd pygame-ce
uv run python -m ensurepip
uv run python dev.py docs
cd ..

mkdir -p public
mv pygame-ce/docs/generated public/docs

rm -rf pygame-ce

echo "Moved generated documentation files to public/docs"
echo "Done."
