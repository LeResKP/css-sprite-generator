#!/bin/bash

for l in A B C D E
do
    convert -size 100x100 xc:lightblue -pointsize 72  -fill black -draw "text 28,68 '$l'"  -fill white -draw "text 25,65 '$l'"  $l.png
done
