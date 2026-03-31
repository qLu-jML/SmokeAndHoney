#!/bin/bash
# Push Smoke & Honey GDD wiki pages to GitHub
# Run this script from the wiki_export folder

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Cloning wiki repo..."
if ! git clone https://github.com/qLu-jML/SmokeAndHoney.wiki.git wiki_temp 2>/dev/null; then
    echo ""
    echo "ERROR: Could not clone wiki repo."
    echo "Make sure the wiki is enabled: Go to your repo Settings > Features > check 'Wikis'"
    echo "You may also need to create the first wiki page manually on GitHub first."
    echo "Visit: https://github.com/qLu-jML/SmokeAndHoney/wiki/_new"
    exit 1
fi

echo "Copying wiki pages..."
cp *.md wiki_temp/ 2>/dev/null || true
rm -f wiki_temp/PUSH_WIKI.bat wiki_temp/push_wiki.sh

cd wiki_temp

echo "Adding files..."
git add -A

echo "Committing..."
git commit -m "Add complete GDD wiki - 19 interconnected pages with sidebar navigation"

echo "Pushing to GitHub..."
git push origin master

echo ""
echo "Done! Visit https://github.com/qLu-jML/SmokeAndHoney/wiki"
echo ""

cd ..
rm -rf wiki_temp
