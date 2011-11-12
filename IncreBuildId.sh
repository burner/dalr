#!/bin/bash

if ! test -f buildinfo.d; then 
	HASH=`git log -1 --pretty=format:%H`
	echo -e "module buildinfo;

public static immutable(uint) buildID = 0;
public static immutable(dstring) gitHash = \"$HASH\";" > buildinfo.d; 
else
	TMP=`grep "CompilerID" buildinfo.d | cut -b 44- | sed 's/\(.*\)./\1/'` 
	TMP=$(($TMP + 1))
	HASH=`git log -1 --pretty=format:%H`
	echo -e "module buildinfo;

public static immutable(uint) buildID = $TMP;
public static immutable(dstring) gitHash = \"$HASH\";" > buildinfo.d; 
fi
