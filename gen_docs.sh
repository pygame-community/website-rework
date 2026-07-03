echo "Starting..."
git clone --depth=1 https://github.com/pygame-community/pygame-ce
cd pygame-ce
uv run python -m ensurepip
uv run python dev.py docs
cd ..
rm -rf dist/docs
mkdir -p dist
mv pygame-ce/docs/generated dist/docs
rm -rf pygame-ce
echo "Moved generated documentation files over to dist/docs"
echo "Done."
