#!/bin/bash 
DIR_FILE=()
INCORRECT=
PRINT_ALL=
CORRECT=
ADVANCE=
correct_arr=()
incorrect_arr=()
DICTPATH="/usr/share/dict/words"
declare -A DICTWORD

usage(){
    cat <<!EOF!
Usage: $0 [option] [files]...
A simple basic spell checker for text files
Option:
    -p print all words both correct and incorrect distinguished by color
    -a use advance correction which provides suggestion 
       if not set basic correction is used
    -i print incorrect word only
    -h print help
    -c print correct word only
!EOF!
}

#cache dictionary data
load_dict(){
    for word in $(<$DICTPATH); do
        DICTWORD[$word]=$word
    done
}

for arg; do
    case $arg in
        -p)
            PRINT_ALL=1
            ;;
        -i)
            INCORRECT=1
            ;;
        -c)
            CORRECT=1
            ;;
        -a)
            ADVANCE=1
            ;;
        -h)
            usage
            exit 0
            ;;
        -*)
           echo "Invalid option"
            usage
            exit 1
            ;;
       *)
           DIR_FILE+=("$arg")
            ;;
    esac
done

if [ "${#DIR_FILE[@]}"  -gt 1 ]; then
    echo "only one file can be specified at once"
    exit 1
fi


if [ ${#DIR_FILE[@]} -eq 0 ]; then
    TEXT=$(cat 2>/dev/null)
else
    TEXT="$(cat "${DIR_FILE[0]}" 2>/dev/null)";
fi

if [ $? -ne 0 ]; then
    echo "Invalid file name"
    exit 2
elif [ -z "$TEXT" ]; then
    echo "File is empty"
    exit 1
fi

function split(){
    check="$(tr -sc A-Za-z\' '\012' <<< $TEXT | tr A-Z a-z)" 
    if [ -z "$check" ]; then
        echo "Error occur when processing file";
        exit 1
    fi

    for word in $check; do
        if [ -z "${DICTWORD[$word]}" ]; then
            incorrect_arr+=($word)
        else
            correct_arr+=($word)
       fi
    done
}

function basic_correction(){
    if [ -z "$CORRECT"  ] && [ -z "$PRINT_ALL" ]; then 
        for word in ${incorrect_arr[@]}; do
            echo -e "\x1b[1m\x1b[31m$word\x1b[0m"
        done
    elif [ -n "$CORRECT" ] && [ -z  "$PRINT_ALL"]; then
        for word in ${correct_arr[@]}; do
            echo -e "\x1b[1m$word\x1b[0m"
        done
    else 
        processed=$TEXT
        for word in ${incorrect_arr[@]}; do
            processed=$(echo -e "$processed" | sed "s/\($word\)/\x1b[1m\x1b[31m\1\x1b[0m/g")
        done
        echo -e "$processed"
    fi
}

function advance_correction(){
    #uses more memory
   likely_sets=()
   declare -a suggestion;
    for word in ${incorrect_arr[@]}; do
        get_likely $word;
        temp="${likely_sets[@]}"

        for likely in $temp; do
            if [ -n "${DICTWORD[$likely]}" ]; then
                suggestion+=("$likely");
                continue;
                # two edits away from word
            fi
            likely_sets=()
            echo $likely_sets
            echo  likely - $likely
            get_likely $likely
            for sword in ${likely_sets[@]}; do
                echo sword - $sword
                if [ -n "${DICTWORD[$sword]}" ]; then
                    suggestion+=("$sword")
                fi
            done
        done
        echo 
        echo "$word - ${suggestion[@]}"
    done
}

function get_likely(){
    declare -A likely_set
    likely_sets=()
    local word=$1
    local delete=()
    local transpose=()
    local replace=()
    local insert=()
    local letters=(a b c d e f g h i j k l m n o p q r s t u v w x y z)
    for i in $(seq 0 ${#word}); do
        local first="${word:0:i}"
        local second="${word:i}"
        if [ ! -z "$second" ]; then
            delete+=("${first}${second:1}")
        fi
         if [ "${#second}" -gt 1 ]; then
             transpose+=("${first}${second:1:1}${second:0:1}${second:2}")
         fi
        for char in ${letters[@]}; do
            insert+=("${first}${char}$second")
            if [ ! -z "$second" ]; then
                replace+=("${first}${char}${second:1}")
            fi
        done
    done

    for word in ${replace[@]} ${transpose[@]} ${delete[@]} ${insert[@]}; do
        if [ -z "${likely_set["$word"]}" ]; then
            likely_set["$word"]=$word
        fi
    done
    likely_sets=(${likely_set[@]})
}

function main(){

if [ ! -f "$DICTPATH" ]; then
    echo "Dictionary not available."
    echo "Exiting..."
    exit 1
fi
load_dict
split

if [ -z "$ADVANCE" ]; then
    basic_correction

else
    advance_correction
fi
}

main
