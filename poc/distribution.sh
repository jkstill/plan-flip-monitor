#!/usr/bin/env bash

declare zipFile=poc-unstable-plans.zip

rm -f $zipFile

zip -ry $zipFile  poc-unstable-plans.pl poc-mail-simple.pl *.conf  lib

echo
echo "####### $zipFile contents ##############"

unzip -l $zipFile


