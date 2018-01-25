#!/bin/bash

#Testing filename
ls -ald $1 2> /dev/null 1> /dev/null

#Filename Exit Status for ls -ald
filenameExit=$?

#Error Messages
validInput=0
if [ $# -gt 1 ]; then
   echo "Usage: showpath [ filename ] "
   exit 1
elif [ $filenameExit != 0 ]; then
    echo "$1 is not a valid filename"
    exit 1
fi

#Determine number of arguments and setting default directory if empty
case $# in
   0) dir=. ;;
   1) dir=$1 ;;
   *) echo "cdir: only one argument is allowed" >&2
      exit 1 ;;
esac

#Setting absolute path name
if [ $validInput == 0 ]; then
#Check to see if argument was a relative path
ls -ald $(pwd)/$dir 2> /dev/null 1> /dev/null
#Checks to see if arugment is an absolute path name, if not, then add the pwd to make it an absolute directory
#Otherwise the arugment was already an absolute path name
if [ $? == 0 ]; then
    pathName=$(pwd)/$dir
else
    pathName=$dir
fi

#Breaking down Path Name into individual layers by new lines
pNameFile=$(mktemp)
pNameFile2=$(mktemp)

echo $pathName | sed 's/\//\n/g' > ${pNameFile2}

#Add root layer to the path name file first
echo "/" >> ${pNameFile}
#Remove first line which is a \n, end result is all the layers of the absolute path delimited by a new line
cat ${pNameFile2} | sed 1d >> ${pNameFile}

#Creating the Permission File
permissionFile=$(mktemp)

while read line
do
if [ $line == '/' ]	; then
    currentLevel='/'
else
    currentLevel=$currentLevel/$line
fi
ls -ald $currentLevel | cut -c1-10 >> ${permissionFile}
done < ${pNameFile}

#Creating Details File
#Links: 1  Owner: dps918  Group: users  Size: 445  Modified: Mar 20 2014
detailFile=$(mktemp)

while read line
do
if [ $line == '/' ]; then
    currentLevel='/'
else
    currentLevel=$currentLevel/$line
fi
newLine="Links: $(ls -ald $currentLevel | awk '{print $2}') "
newLine="$newLine  Owner: $(ls -ald $currentLevel | awk '{print $3}') "
newLine="$newLine  Group: $(ls -ald $currentLevel | awk '{print $3}') "
newLine="$newLine  Size: $(ls -ald $currentLevel | awk '{print $5}') "
newLine="$newLine  Modified: $(ls -ald $currentLevel | awk '{print $6,$7,$8}') "

echo $newLine >> ${detailFile}

done < ${pNameFile}

#Counting Number of Layers
#Declare that numberOfLayers is an integer not a string, also from here on currentLevel variable is used for display grid
declare -i maxLayers
declare -i currentLevel
#Number of Levels in the File Path
maxLayers=$(wc -l ${pNameFile} | awk '{print $1}')
#Sets the Current Level to be the selected file/directory
currentLevel=$maxLayers

#Creating the Display file for View
displayFile=$(mktemp)
mainPermissions=$(mktemp)
firstCharacterPermission=$(mktemp)
editedPermissions=$(mktemp)
while read line
do
echo -n $line | cut -c2-10 | sed 's/.../& /g' | sed 's/./& /g' >> ${mainPermissions}
done < ${permissionFile}

while read line
do
echo $line | cut -c1  >> ${firstCharacterPermission}
done < ${permissionFile}

truncPathNameFile=$(mktemp)
Cols=$(tput cols)
maxFileName=$((Cols - 26))

while read line
do
echo $line | cut -c1-${maxFileName} >> ${truncPathNameFile}
done < ${pNameFile}

#paste -d' ' ${firstCharacterPermission} ${mainPermissions} ${pNameFile} > ${editedPermissions}
paste -d' ' ${firstCharacterPermission} ${mainPermissions} ${truncPathNameFile} > ${editedPermissions}

while read line
do
echo $line | sed 's/\n/&\n/g' >> ${displayFile}
echo "" >> ${displayFile}
done < ${editedPermissions}


#Output Algorithm
clear
#echo $currentLevel
echo "  Owner   Group   Other   Filename"
echo "  -----   -----   -----   --------"
echo "                                  "
cat ${displayFile} | awk 'BEGIN{f="([^ ]+ )"} {print $1" " $2" " $3" " $4"   " $5" " $6" " $7"   " $8" " $9" " $10"   "  $11" ";}'

#Set cursor to the file/directory given
startCursor=$((((maxLayers * 2))+1))
column=26
row=$startCursor
lastRow=$(tput lines)
detailedLine=0
stty -icanon min 1 time 0 -echo

#Prints the Initial Details Line
tput cup $((row+1)) 0
cat ${detailFile} | awk 'NR == '$currentLevel''

#Print Instructions
tput cup $((lastRow - 5)) 0
printf "Valid commands: k (up), j (down): move between filenames \n"
printf "                h (left), l (right): move between permissions \n"
printf "                r, w, x, -: change permissions;   q: quit"

#Keeps track of which line to read in the Detail File
line=$currentLevel 
#Variable used to denote if cursor is in permissions columns to allow for r w x - to be used
permissionsColumn='f'
#Users, Group, Other
permissionAccess=''
#Read, Write, Execute
permissionType=''

#The following If Statement format is different in the case because I could not find out why ;then wasn't working for some of them
while true
do
  # Places the cursor at the correct coordinates and waits for input
  tput cup $row $column
  command=$(dd bs=3 count=1 2> /dev/null)
  case $command in
    k)	if [ "$row" -gt 3 ]; then
		# Clears the details line then prints details line for one directory level up
		tput cup $((row+1)) 0
		tput el
		row=$((row - 2))
		detailsLine=$((row + 1))
		tput cup $detailsLine 0
		line=$((line-1))
		cat ${detailFile} | awk 'NR == '$line''
		fi;;
    j)	if [ "$row" -lt $startCursor ]
		# Clears the details line then prints details line for one directory level down
		then
		tput cup $((row+1)) 0
		tput el
		row=$((row + 2))
		detailsLine=$((row + 1))
		tput cup $detailsLine 0
		line=$((line+1))
		cat ${detailFile} | awk 'NR == '$line''
		fi;;
	h)	if [ "$permissionsColumn" == "f" ] && [ "$column" -gt 23 ]
		then 
		#Moves the cursor into the Permission Columns if the cursor is currently pointing at the first character of the file name
			permissionsColumn=t
			permissionAccess=o
			permissionType=x	
			tput cup $row $((column-4))
			column=$((column -4))
		elif [ "$column" -gt 3 ] && [ "$permissionsColumn" == "t" ]
		then
			if [ "$permissionType" == "r" ]
			then
				if [ "$permissionAccess" == "o" ]
				then
					permissionAccess=g
					permissionType=x
					tput cup $row $((column - 4))
					column=$((column -4))
				elif [ "$permissionAccess" == "g" ]
				then
					permissionAccess=u
					permissionType=x
					tput cup $row $((column - 4))
					column=$((column -4))
				fi
			elif [ "$permissionType" == "w" ]
			then	
				permissionType=r
				tput cup $row $((column - 2))
				column=$((column - 2))
			elif [ "$permissionType" == "x" ]
			then
				permissionType=w
				tput cup $row $((column - 2))
				column=$((column - 2))
			fi
		fi;;
	l)	if [ "$column" -lt 24 ] && [ "$permissionsColumn" == "t" ]
		then
			if [ "$permissionType" == "x" ]
			then
				if [ "$permissionAccess" == "o" ]
				then
					permissionsColumn=f
					permissionAccess=''
					permissionType=''
					tput cup $row $((column + 4))
					column=$((column + 4))
				elif [ "$permissionAccess" == "g" ]
				then
					permissionAccess=o
					permissionType=r
					tput cup $row $((column + 4))
					column=$((column + 4))
				else
					permissionAccess=g
					permissionType=r
					tput cup $row $((column + 4))
					column=$((column + 4))				
				fi
			elif [ "$permissionType" == "w" ]
			then	
				permissionType=x
				tput cup $row $((column + 2))
				column=$((column + 2))
			else
				permissionType=w
				tput cup $row $((column + 2))
				column=$((column + 2))
			fi
		fi;;
	r)	if [ "$permissionType" == "r" ] && [ "$permissionsColumn" == "t" ]
		then
			testLine=$(cat ${pNameFile} | awk 'NR == '$line'')
			chmod "$permissionAccess"+r "$testLine" 2> /dev/null 1> /dev/null
			
			if [ $? == 0 ]
			then
				echo r
			fi
		fi;;
	w)	if [ "$permissionType" == "w" ] && [ "$permissionsColumn" == "t" ]
		then
			testLine=$(cat ${pNameFile} | awk 'NR == '$line'')
			
			chmod "$permissionAccess"+w "$testLine" 2> /dev/null 1> /dev/null
			
			if [ $? == 0 ]
			then
				echo w
			fi
		fi;;
		
	x)	if [ "$permissionType" == "x" ] && [ "$permissionsColumn" == "t" ]
		then
			testLine=$(cat ${pNameFile} | awk 'NR == '$line'')
			chmod "$permissionAccess"+x "$testLine"	2> /dev/null 1> /dev/null
			
			if [ $? == 0 ]
			then
				echo x
			fi
		fi;;
	-)	if [ "$permissionsColumn" == "t" ]
		then
			testLine=$(cat ${pNameFile} | awk 'NR == '$line'')
			if [ "$permissionType" == "r" ]
			then
				chmod "$permissionAccess"-r "$testLine" 2> /dev/null 1> /dev/null
				if [ $? == 0 ]
				then
					echo -
				fi
			elif [ "$permissionType" == "w" ]
			then
				chmod "$permissionAccess"-w "$testLine" 2> /dev/null 1> /dev/null
				if [ $? == 0 ]
				then
					echo -
				fi
			elif [ "$permissionType" == "x" ]
			then
				chmod "$permissionAccess"-x "$testLine" 2> /dev/null 1> /dev/null
				if [ $? == 0 ]
				then
					echo -
				fi
			fi
		fi;;
	q)	rm -f ${detailFile} 2> /dev/null
		rm -f ${displayFile} 2> /dev/null
		rm -f ${editedPermissions} 2> /dev/null
		rm -f ${firstCharacterPermission} 2> /dev/null
		rm -f ${pNameFile} 2> /dev/null
		rm -f ${mainPermissions} 2> /dev/null
		rm -f ${permissionFile} 2> /dev/null
		rm -f ${pNameFile2} 2> /dev/null
		stty icanon echo
		tput cup $lastRow 0
		exit 0;;
  esac
done

fi
