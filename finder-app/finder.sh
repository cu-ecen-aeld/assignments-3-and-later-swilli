#!/bin/bash

if [[ $# < 2 ]]
then
    echo "Not enough parameters specified"
    exit 1
fi

filesdir=$1
searchstr=$2

if ! [ -d $filesdir ]
then
    echo "$filesdir is not a directory."
    exit 1
fi

files=$(find "$filesdir/" -type f)
X=0
Y=0
for file in $files
do
    X=$((X+1))
    y=$(grep -I $searchstr $file | wc -l)
    Y=$((Y+y))
done

echo "The number of files are $X and the number of matching lines are $Y"
