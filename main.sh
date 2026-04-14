#!/usr/bin/env bash

MAP_FILE_SEPARATOR=" /// "
MAP_FILE="$PASSWORD_STORE_DIR/.map"

# TODO rename to pass-autotype
# TODO disable gpg precheck, its stupid & wasteful

################
# HANDLE FLAGS #
################
flag_interactive=0
flag_help=0
flag_readme=0
flag_log=0

while [ -n "$1" ]; do
    case "$1" in
        "-h"|"--help") flag_help=1 ;;
        "--readme") flag_readme=1 ;;
        "--log") flag_log=1 ;;
        "--interactive") flag_interactive=1 ;;
    esac

    shift
done

if (( flag_help )); then
    cat "$(dirname "$0")/quickhelp.txt"
    exit
fi

if (( flag_readme )); then
    if command -v bat > /dev/null
    then bat "$(dirname "$0")/README.md"
    else cat "$(dirname "$0")/README.md"
    fi
    exit
fi

(( flag_log )) && echo >> /tmp/pw.log
function log() {
    (( flag_log )) && echo "$1 $(date +"%H:%M @ %S.%3N") $1 $2" >> /tmp/pw.log
    [ "$1" == E ] && echo "pw error: $2"
}

log F "beggining of main.sh"

####################
# ASSERT ENV STATE #
####################
log . "asserting state of environment"
[ ! -d "$PASSWORD_STORE_DIR" ] && log E "please set \$PASSWORD_STORE_DIR to the .pass directory" && exit 1
[ ! -f "$PASSWORD_STORE_DIR/blank.gpg" ] && log E "please create a dummy gpg file at \$PASSWORD_STORE_DIR/blank.gpg" && exit 1
[ -z "$GET_WINDOW_CLASS" ] && log E "please set \$GET_WINDOW_CLASS to a script that prints window class" && exit 1
[ -z "$GET_WINDOW_TITLE" ] && log E "please set \$GET_WINDOW_TITLE to a script that prints window title" && exit 1
! command -v "$DMENU_PROGRAM" > /dev/null && log E "please set \$DMENU_PROGRAM to the name of a dmenu-like program" && exit 1
! command -v gpg > /dev/null && log E "gpg is a dependency, please install it" && exit 1
! command -v wl-copy > /dev/null && log E "wl-copy is a dependency, please install it" && exit 1
! command -v wtype > /dev/null && log E "wtype is a dependency, please install it" && exit 1

#######################
# FETCH CLASS & TITLE #
#######################
log I "fetching window class & title"

window_class="$(eval "$GET_WINDOW_CLASS")"
window_title="$(eval "$GET_WINDOW_TITLE")"

log . "window_title='$window_title'"
log . "window_class='$window_class'"

echo -e "$BROWSER\n$BROWSERS"   | grep -qi "$window_class" && map_class="browser"
echo -e "$TERMINAL\n$TERMINALS" | grep -qi "$window_class" && map_class="terminal"
[ -z "$map_class" ] && map_class="other"

map_title="$window_title"

log . "map_title='$map_title'"
log . "map_class='$map_class'"

#################################
# SEARCH & PARSE MAP FILE ENTRY #
#################################
awk_result="$(
awk -F "$MAP_FILE_SEPARATOR" -v c="$map_class" -v t="$map_title" '
/^[[:space:]]*$/ { next } # skip empty line
/^[[:space:]]*#/ { next } # skip comments
c == $1 && t ~ $2 { print $3" ||| "$4; exit } # exact class match & regex title match
' "$MAP_FILE"
)"

log . "awk_result='$awk_result'"

pass_entry_folder_fragment="${awk_result/ ||| */}"
pass_entry_sequence="${awk_result/* ||| /}"
if [ -z "$pass_entry_sequence" ] || (( flag_interactive )); then pass_entry_sequence="."; fi

log . "pass_entry_folder_fragment='$pass_entry_folder_fragment'"
log . "pass_entry_sequence='$pass_entry_sequence'"

###################################
# CHOOSE PASS FOLDER FROM MATCHES #
###################################

pass_entry_folder_matches=( "$PASSWORD_STORE_DIR/$pass_entry_folder_fragment"* )

if (( flag_interactive )); then
    all_pass_entry_folders=( "$PASSWORD_STORE_DIR/"* )

    # if the fragment has no matches, or matches everything, just use default entries
    # otherwise, add the matches as a separate section to choose from
    if [ ${#pass_entry_folder_matches[@]} == 0 ] || [ ${#pass_entry_folder_matches[@]} == ${#all_pass_entry_folders[@]} ]; then
        pass_entry_folder_matches=( "${all_pass_entry_folders[@]}" )
    else
        pass_entry_folder_matches=( "${pass_entry_folder_matches[@]}" "" "${all_pass_entry_folders[@]}" )
    fi
fi

# choose an entry from the list
if [ ${#pass_entry_folder_matches[@]} == 1 ]; then
    pass_entry_folder="${pass_entry_folder_matches[0]}"
else
    pass_entry_folder="$PASSWORD_STORE_DIR/$(printf '%s\n' "${pass_entry_folder_matches[@]##*/}" | $DMENU_PROGRAM)"
fi

log . "pass_entry_folder='$pass_entry_folder'"

if [ "$pass_entry_folder" == "$PASSWORD_STORE_DIR/" ]; then log I "user failed to choose a pass folder, exiting" ; clean_fifo_exit ; fi
if [ ! -d "$pass_entry_folder" ]; then log E "selected pass folder somehow isn't a valid directory: '$pass_entry_folder', exiting" ; clean_fifo_exit ; fi

######################################
# DEFINE FUNCTION TO TYPE PASS ENTRY #
######################################

# takes 1=<full path to pass subfolder (NO trailing /)>
# takes 2=<a pass entry name in the subfolder or a partial ^match of one>
# if there are multiple matches for any of these, allows user to select one
# then types the selected pass entry into current window
function select_and_type_pass_entry() {
    log F "select_and_type_pass_entry START"

    folder="$1"
    entry_fragment="$2"

    log . "folder='$folder'"
    log . "entry_fragment='$entry_fragment'"

    entry_matches=( "$folder/$entry_fragment"* )

    if [ ${#entry_matches[@]} == 1 ];
    then entry="$(echo "${entry_matches[0]##*/}" | sed 's|.gpg$||')"
    else entry="$(printf '%s\n' "${entry_matches[@]##*/}" | sed 's|.gpg$||' | $DMENU_PROGRAM)"
    fi

    if [ -z "$entry" ]; then log I "user failed to choose a pass entry, exiting" ; clean_fifo_exit ; fi
    if [ ! -f "$folder/$entry.gpg" ]; then log E "selected pass entry somehow isn't a valid file: '$folder/$entry.gpg', exiting" ; clean_fifo_exit ; fi
    log . "entry='$entry'"

    # copy and paste password
    log I "copying password into clipboard"
    wl-copy "$(gpg --pinentry-mode cancel --quiet -d "$folder/$entry.gpg")" 2>/dev/null

    log I "typing password"
    case "$map_class" in
        "terminal")        wtype -M ctrl -M shift -k v -m shift -m ctrl ;;
        "browser"|"other") wtype -M ctrl -k v -m ctrl ;;
    esac

    log F "select_and_type_pass_entry FINISH"
}

##########################
# PROCESS ENTRY SEQUENCE #
##########################

# takes 1=<key name>
# small helper to type keys like Tab & Return
function type_key() {
    wtype -P "$1" -p "$1"
}

for (( i=0; i<${#pass_entry_sequence}; i++ )); do
    char="${pass_entry_sequence:$i:1}"

    log I "processing char='$char'"

    if [[ $char == [a-z] ]]; then # lowercase letter
        select_and_type_pass_entry "$pass_entry_folder" "$char"
        continue
    fi

    # uppercase or special char
    case "$char" in
        '$') select_and_type_pass_entry "$pass_entry_folder" "$(hostname)" ;;
        '~') select_and_type_pass_entry "$pass_entry_folder" "$(whoami)" ;;
        '.') select_and_type_pass_entry "$pass_entry_folder" "";;

        'T') type_key Tab ;;
        'E') type_key Return ;;
        ' ') type_key Space ;;
    esac
done

function clear_clip() {
    log I "clearing clipboard to help with security"
    sleep 0.5
    wl-copy "cleared by pw.sh" 2>/dev/null
    return 0
}

clear_clip &
log F "end of main.sh"
exit 0
