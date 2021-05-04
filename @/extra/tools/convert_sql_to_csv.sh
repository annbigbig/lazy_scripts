#!/bin/bash
# this script is used to convert SQL (mysqldump output data) to CSV files
# 
# data come from this command :
# ls -al | grep small | tr -s ' '  |  cut -d ' ' -f 9
# and file lists below will be converted : 1.replace ),( with \n  2.remove first and last line in each file
read -r -d '' FILENAMES_LIST << EOV
small_pieces_fae
small_pieces_faf
small_pieces_fag
small_pieces_fah
small_pieces_fai
small_pieces_faj
small_pieces_fak
small_pieces_fal
small_pieces_fam
small_pieces_fan
small_pieces_fao
small_pieces_fap
small_pieces_faq
small_pieces_far
small_pieces_fas
small_pieces_fat
small_pieces_fau
small_pieces_fav
small_pieces_faw
small_pieces_fax
small_pieces_fay
small_pieces_faz
small_pieces_fba
small_pieces_fbb
small_pieces_fbc
small_pieces_fbd
small_pieces_fbe
small_pieces_fbf
small_pieces_fbg
small_pieces_fbh
small_pieces_fbi
small_pieces_fbj
small_pieces_fbk
small_pieces_fbl
small_pieces_fbm
small_pieces_fbn
small_pieces_fbo
small_pieces_fbp
small_pieces_fbq
small_pieces_fbr
EOV

# ###
        while read -r LINE; do
           FILENAME="$(/bin/echo $LINE | cut -d ' ' -f 1)"
           echo -e "Beginning processing ... $FILENAME \n"
           sed -i -- 's|),(|\n|g' $FILENAME
           sed -i '$d' $FILENAME 
           sed -i '1d' $FILENAME
	   # sed -i "s/'//g" $FILENAME
           echo -e "End processing ... $FILENAME \n"
        done <<< "$FILENAMES_LIST"

   echo "all SQL files converted done."


