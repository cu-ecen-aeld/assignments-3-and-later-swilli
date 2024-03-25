#!/bin/bash

if [[ $# < 2 ]]
then
    echo "Not enough parameters specified"
    exit 1
fi

writefile=$1
writestr=$2

mkdir -p $(dirname $writefile)
echo $writestr >> $writefile