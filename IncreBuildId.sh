#!/bin/bash

if ! test -f compilerinfo.d; then 
	HASH=`git log -1 --pretty=format:%H`
	echo -e "module compilerinfo;

public static immutable(uint) CompilerID = 0;
public static immutable(dstring) GitHash = \"$HASH\";" > compilerinfo.d; 
else
	TMP=`grep "CompilerID" compilerinfo.d | cut -b 44- | sed 's/\(.*\)./\1/'` 
	TMP=$(($TMP + 1))
	HASH=`git log -1 --pretty=format:%H`
	echo -e "module compilerinfo;

public static immutable(uint) CompilerID = $TMP;
public static immutable(dstring) GitHash = \"$HASH\";" > compilerinfo.d; 
fi
