#!/bin/bash

if ! test -f buildinfotester.d; then 
	HASH=`git log -1 --pretty=format:%H`
	echo -e "module buildinfo;

public static immutable(uint) buildID = 0;
public static immutable(dstring) gitHash = \"$HASH\";" > buildinfotester.d; 
else
	TMP=`grep "buildID" buildinfotester.d | cut -b 31- | sed 's/\(.*\)./\1/'` 
	TMP=$(($TMP + 1))
	HASH=`git log -1 --pretty=format:%H`
	echo -e "module buildinfo;

public static immutable(uint) buildID = $TMP;
public static immutable(dstring) gitHash = \"$HASH\";" > buildinfotester.d; 
fi
