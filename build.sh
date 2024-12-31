#!/bin/zsh
if [ -f "GZLang" ] ;then
  rm GZLang
fi

helpFunction() {
   echo ""
   echo "Usage: $0 -f <.gz file>"
   exit 1 # Exit script after printing help
}

while getopts ":f:" opt
do
   case "$opt" in
      "f" ) file="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

if [ -z ${file+x} ]; then
  echo "Enter real time mode"
else 
  echo "Passed in file $file"
fi

odin build . -out=GZLang -o:none -vet -debug

if [ -f "GZLang" ]; then
  ./GZLang $file
fi
