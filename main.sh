#!/usr/bin/env bash
# NOTE potential optimization: could be cut time waiting for gpg to decrypt by preloading passwords asynchronously

# comment/uncomment these to disable/enable logging

# echo >> /tmp/pw.log
function log() {
    # echo "$1 $(date +"%H:%M @ %S.%3N") $1 $2" >> /tmp/pw.log
    true
}

log F "beggining of main.sh"

#####################################
# FUNCTIONS TO DEAL WITH GPG UNLOCK #
#####################################

GPG_TEST_FILE="$PASSWORD_STORE_DIR/blank.gpg"
BLOCK_CHECK_GPG_FIFO=$(mktemp -u /tmp/pw_gpg_check_block_XXXXXX.fifo)
gpg_unlocked=-1

[ ! -f "$GPG_TEST_FILE" ] && log E "we expect an encrypted .gpg at '$GPG_TEST_FILE'" && exit

# check if gpg is unlocked, and print result to a blocking fifo
function check_gpg_unlocked() {
    mkfifo "$BLOCK_CHECK_GPG_FIFO"
    log I "made fifo '$BLOCK_CHECK_GPG_FIFO' to wait until gpg check is complete"

    if gpg --pinentry-mode cancel --quiet -d "$GPG_TEST_FILE" 2>&1 | grep -q "^gpg:.*failed: Operation cancelled"; then
        log I "gpg key is locked, will have to be unlocked later"
        echo 0 > "$BLOCK_CHECK_GPG_FIFO"
    else
        log I "gpg key is unlocked"
        echo 1 > "$BLOCK_CHECK_GPG_FIFO"
    fi
}

# run gpgpass popup on loop until gpg shows its unlocked
function unlock_gpg() {
    log I "beginning manual unlock of gpg"
    while true; do
        # check if its unlocked
        gpg --pinentry-mode cancel --quiet -d "$GPG_TEST_FILE" 2>&1 | grep -q "^gpg:.*failed: Operation cancelled" || break

        log I "gpg is locked, showing pypr dropdown"

        # run a shell to unlock gpg
        pypr show gpg # TODO THIS REQUIRES THE PYPR TO WORK AND EVERYTHING. EITHER WARN IN README OR FIX

        # wait for unlock to complete
        while [ -n "$(pgrep -f 'scratchpad .*pyprland/gpg.sh')" ]; do sleep 0.01; done
    done

    gpg_unlocked=1
    log I "unlocked gpg key manually"
}

log I "checking lock status of gpg key in background"
check_gpg_unlocked &

######################
# SETUP VARS & FLAGS #
######################
MAP_FILE_SEPARATOR=" /// "
MAP_FILE="$PASSWORD_STORE_DIR/.map"

flag="$1"
if [ "$flag" == "-h" ] || [ "$flag" == "--help" ]; then cat "$(dirname "$0")/README.md"; exit; fi
interactive=0
if [ "$flag" == "-i" ] || [ "$flag" == "--interactive" ]; then interactive=1; fi

#######################
# FETCH CLASS & TITLE #
#######################
log I "fetching window class & title"

hypr_class="$(hyprctl activewindow -j | jq -r .class)"
hypr_title="$(hyprctl activewindow -j | jq -r .title)"

log . "hypr_title='$hypr_title'"
log . "hypr_class='$hypr_class'"

echo -e "$BROWSER\n$BROWSERS"   | grep -qi "$hypr_class" && map_class="browser"
echo -e "$TERMINAL\n$TERMINALS" | grep -qi "$hypr_class" && map_class="terminal"
[ -z "$map_class" ] && map_class="other"

if [[ "$hypr_class" == *"qutebrowser"* ]]; then
    map_title="${hypr_title/ - [^ ]*/} $(browser get-url | sed -e 's|^[^/]*//\([^/]*\)/.*|[\1]|')" # the sed expression takes everything between the first // and the next / and puts it in brackets
else
    map_title="$hypr_title"
fi

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
if [ -z "$pass_entry_sequence" ] || (( interactive )); then pass_entry_sequence="."; fi

log . "pass_entry_folder_fragment='$pass_entry_folder_fragment'"
log . "pass_entry_sequence='$pass_entry_sequence'"

###################################
# CHOOSE PASS FOLDER FROM MATCHES #
###################################

pass_entry_folder_matches=( "$PASSWORD_STORE_DIR/$pass_entry_folder_fragment"* )

if (( interactive )); then
    all_pass_entry_folders=( "$PASSWORD_STORE_DIR/"* )

    if [ ${#pass_entry_folder_matches[@]} == 0 ]; then
        pass_entry_folder_matches=( "${all_pass_entry_folders[@]}" )
    else
        pass_entry_folder_matches=( "${pass_entry_folder_matches[@]}" "" "${all_pass_entry_folders[@]}" )
    fi
fi

if [ ${#pass_entry_folder_matches[@]} == 1 ]; then
    pass_entry_folder="${pass_entry_folder_matches[0]}"
else
    pass_entry_folder="$PASSWORD_STORE_DIR/$(printf '%s\n' "${pass_entry_folder_matches[@]##*/}" | $DMENU_PROGRAM)"
fi

log . "pass_entry_folder='$pass_entry_folder'"

[ -z "$pass_entry_folder" ] && log E "wasnt able to choose a pass folder, exiting" && exit
[ "$pass_entry_folder" == "$PASSWORD_STORE_DIR/" ] && log E "wasnt able to choose a pass folder, exiting" && exit

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

    [ ! -f "$folder/$entry.gpg" ] && log E "ERROR NOT A FILE: '$folder/$entry.gpg'" && exit
    log . "entry='$entry'"

    # wait for async gpg unlock check to complete
    if [ "$gpg_unlocked" = -1 ]; then
        log I "BLOCKED: waiting for check_gpg_unlocked() to exit"
        gpg_unlocked="$(cat "$BLOCK_CHECK_GPG_FIFO")" # wait for check_gpg_unlocked to finish
        log I "UNBLOCKED"
    fi

    # if locked, unlock
    if (( ! gpg_unlocked )); then
        log I "gpg is locked, unlocking manually"
        unlock_gpg;
    fi

    # copy and paste password
    log I "copying password into clipboard"
    wl-copy "$(gpg --pinentry-mode cancel --quiet -d "$folder/$entry.gpg")"
    # wl-copy "$(pass "${folder##*/}/$entry")"

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
        'R') type_key Return ;;
        ' ') type_key Space ;;
    esac
done

log I "cleaning up fifo '$BLOCK_CHECK_GPG_FIFO'"
rm "$BLOCK_CHECK_GPG_FIFO" > /dev/null

log I "clearing clipboard to help with security"
sleep 0.5 && wl-copy "cleared by pw.sh at $(date +"%H:%M @ %S.%3N")" &
