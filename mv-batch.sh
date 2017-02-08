#!/usr/bin/env bash

for file in `ls`
do
	fileName=`echo $file | awk -F"[_]" '{printf("%s.%s", $1, $4)}'`
	echo $fileName
	mv $file $fileName
done
