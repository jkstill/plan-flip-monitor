#!/usr/bin/env bash

declare zipFile=poc-unstable-plans.zip
declare tarFile=poc-unstable-plans.tgz

rm -f $zipFile $tarFile

zip -ry  $zipFile  poc-unstable-plans.pl poc-mail-simple.pl *.conf  lib
tar cvfz $tarFile  poc-unstable-plans.pl poc-mail-simple.pl *.conf  lib

echo
echo "####### $zipFile contents ##############"

unzip -l $zipFile

echo
echo
echo "####### $tarFile contents ##############"

tar tvfz $tarFile

echo


