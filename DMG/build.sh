cd "`dirname "$0"`"
echo removing old files
find . -name 500pxSreenSaver.dmg -delete
echo building dmg
appdmg dmg_config.json 500pxSreenSaver.dmg
echo dmg done