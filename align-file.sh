#!/bin/bash

if [[ $1 == '--help' ]]
then
    echo 'align-file [PARAMS] FILE
    -bs SIZE    block size'
    exit
fi

if [[ $1 == '-bs' ]]
then
    block_size=$2
else
    block_size=512
fi

file=${!#}

current_size=$(stat -c %s "$file")
new_size=$(( ( (current_size + block_size - 1) / block_size ) * block_size ))

truncate -s "$new_size" "$file"