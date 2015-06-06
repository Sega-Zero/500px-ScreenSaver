cd "`dirname "$0"`/ScreenSaver"
find . -name "*.m" -print0 | xargs -0 genstrings -o Base.lproj 
cd ./Base.lproj
iconv -f UTF-16 -t UTF-8 Localizable.strings > Localizable.strings1
rm -f Localizable.strings
mv Localizable.strings1 Localizable.strings
