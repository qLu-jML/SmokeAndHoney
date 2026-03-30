@echo off
REM Push Smoke & Honey GDD wiki pages to GitHub
REM Run this script from the wiki_export folder

echo Cloning wiki repo...
git clone https://github.com/qLu-jML/SmokeAndHoney.wiki.git wiki_temp
if errorlevel 1 (
    echo.
    echo ERROR: Could not clone wiki repo.
    echo Make sure the wiki is enabled: Go to your repo Settings ^> Features ^> check "Wikis"
    echo You may also need to create the first wiki page manually on GitHub first.
    echo Visit: https://github.com/qLu-jML/SmokeAndHoney/wiki/_new
    pause
    exit /b 1
)

echo Copying wiki pages...
copy /Y *.md wiki_temp\
del wiki_temp\PUSH_WIKI.bat 2>nul

cd wiki_temp

echo Adding files...
git add -A

echo Committing...
git commit -m "Add complete GDD wiki - 19 interconnected pages with sidebar navigation"

echo Pushing to GitHub...
git push origin master

echo.
echo Done! Visit https://github.com/qLu-jML/SmokeAndHoney/wiki
echo.

cd ..
rmdir /s /q wiki_temp

pause
