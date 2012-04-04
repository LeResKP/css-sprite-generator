#!/bin/bash

#
# Css Sprite Generator
# Copyright (C) 2012 - Author: Aurélien Matouillot
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#


usage(){
  echo "Usage: $0 [h] filename"
  echo "Generate a sprite image and the css corresponding. You just need to create a file with a specific syntax (see README) and call this script with the file as parameter."
  exit 0
}

error(){
    echo "$1"
    echo " "
    usage
}

get_css_format(){
    local __default_css_format="$1"
    for opt in $(echo "$__default_css_format" | sed 's/,/ /g')
    do
        case $opt in
             "r") local __css_repeat='repeat';;
           "nor") local __css_repeat='no-repeat';;
            "rx") local __css_repeat='repeat-x';;
            "ry") local __css_repeat='repeat-y';;
             "w") local __add_width=1;;
             "h") local __add_height=1;;
           "now") local __add_width=0;;
           "noh") local __add_height=0;;
               *) error "Not supported css format: $opt";;
        esac
    done
    
    eval $2="'$__css_repeat'"
    eval $3="'$__add_width'"
    eval $4="'$__add_height'"
}

verbose=0

while getopts 'hv' param;
do
    case $param in
        h) usage;;
        v) verbose=$(($verbose+1));;
        *) echo " ";usage;;
    esac
done

shift "$((OPTIND-1))"; OPTIND=1
filename=$1

if [ -z $filename ]
then
    error 'No filename given'
fi

cd $(dirname $filename)
filename=$(basename $filename)

output_image_filename=''
output_css_filename=''
web_image_path=''

# Read the conf from the first line of filename
confline=$(head -n 1 $filename | sed 's|\/\* *\(.*\) *\*\/|\1|g')

for conf in $confline
do
    name=$(echo $conf | awk -F '=' '{print $1}')
    value=$(echo $conf | awk -F '=' '{print $2}')
    case $name in
        "image_target_name") output_image_filename=$value;;
        "css_target_name") output_css_filename=$value;;
        "css_format") default_css_format=$value;;
        "web_image_path") web_image_path=$value;;
        *) error "$value not supported in the head of $filename";;
    esac
done


if [ $verbose -gt 0 ]
then
    echo "Output image filename: $output_image_filename"
    echo "Output css filename: $output_css_filename"
    echo "Default css format: $default_css_format"
    echo "Default web image path: $web_image_path"
fi


if [ -z $output_image_filename ]
then
    error "No image filename in the head of $filename"
fi

if [ -z $output_css_filename ]
then
    error "No css filename in the head of $filename"
fi



get_css_format "$default_css_format" default_css_repeat default_add_width default_add_height

# Make sure variable are defined
default_css_repeat=${default_css_repeat:-"no-repeat"}
default_add_width=${default_add_width:-0}
default_add_height=${default_add_height:-0}


if [ $verbose -gt 0 ]
then
    echo "Default css repeat : $default_css_repeat"
    echo "Default add width  : $default_add_width"
    echo "Default add height : $default_add_height"
fi

# Empty the css file
echo '' > $output_css_filename

content=$(sed '1d' "$filename")

IFS=$'\n'

commandLine='convert '

offsetY=0

for line in $content
do
    IFS=$'|'
    imgs=$(echo $line | sed 's/:[^ ]*//g;s/(\(.*\))//g') 
    
    imgs=''
    offsetX=0
    maxHeight=0
    for col in $line
    do
        img=$(echo $col | sed 's/:.*//g;s/(\(.*\))//g')
        imgSize=$(echo $col | sed 's/:.*//g' | grep '(.*)' | sed 's/.*(\(.*\))/\1/g')
        imageWidth=''
        imageHeight=''
        if [ $imgSize ]
        then
            imageWidth=$(echo $imgSize | awk -F 'x' '{print $1}')
            imageHeight=$(echo $imgSize | awk -F 'x' '{print $2}')
            imgs=" '(' -background none -extent $imgSize -gravity center $img ')'"
        else
            imgs="$imgs $img"
        fi
        imageWidth=${imageWidth:-$(identify -format "%[fx:w]" $img)}
        imageHeight=${imageHeight:-$(identify -format "%[fx:h]" $img)}

        if [ $imageHeight -gt $maxHeight ]
        then
            maxHeight=$imageHeight
        fi

        cssname=$(echo $col | sed 's/^[^ ]*://g' | sed 's/(.*)//g')
        cssformat=$(echo $col | sed 's/[^ ]*://g' | grep '(.*)' | sed 's/[^()]*(\(.*\))[^()]*/\1/g' | sed 's/,/\|/g')

        get_css_format "$cssformat" css_repeat add_width add_height

        css_repeat=${css_repeat:-$default_css_repeat}
        add_width=${add_width:-$default_add_width}
        add_height=${add_height:-$default_add_height}

        if [ $verbose -gt 0 ]
        then
            echo " "
            echo $col
            echo "css name $cssname"
            echo "css_repeat $css_repeat"
            echo "add_width $add_width"
            echo "add_height $add_height"
            echo "Image width $imageWidth"
            echo "Image height $imageHeight"
        fi

        echo "$cssname{" >> $output_css_filename
        echo -n "  background: url($web_image_path$(basename $output_image_filename)) $offsetX"px" $offsetY"px >> $output_css_filename
        echo " $css_repeat;" >> $output_css_filename
        if [ $add_width -eq 1 ]
        then
            width=$imageWidth
            echo "  width: $width""px;" >> $output_css_filename
        fi
        if [ $add_height -eq 1 ]
        then
            height=$imageHeight
            echo "  height: $height""px;" >> $output_css_filename
        fi
        echo -e "}\n" >> $output_css_filename
        offsetX=$(($offsetX - $imageWidth))
    done
    commandLine=$commandLine" '(' $imgs +append ')' -gravity NorthWest -append"
    offsetY=$(($offsetY - $maxHeight))
done

unset IFS

commandLine=$commandLine" $output_image_filename"
if [ $verbose -gt 0 ]
then
    echo $commandLine
fi
echo $commandLine | sh 
