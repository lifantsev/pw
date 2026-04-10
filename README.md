# Environment
- `$PASSWORD_STORE_DIR` Should be set to a directory containing folders that contain login credentials.
    - For example `$PASSWORD_STORE_DIR/google/pass.gpg` would be your google password.

- `$PASSWORD_STORE_DIR/blank.gpg` Should exist and be encrypted with the same gpg key as everything else.
    - You can create it like so: `echo blank | gpg -e -r my-gpg-id > $PASSWORD_STORE_DIR/blank.gpg`

- `$DMENU_PROGRAM` Should be set to the name of a program like `dmenu`, `rofi`, or `bemenu`.

# Configuration
`pw` attempts to automatically enter the correct credentials based on window class & title. This behaviour is defined in the mapfile (`$PASSWORD_STORE_DIR/.map`). Each line in the mapfile defines one association between class/title and pass entries, as shown below (note that `pw` stops at the first line that matches the class & title, so put more specific regexes at the top of the mapfile)
```
<class> /// <title regex> /// <pass subfolder fragment> /// <entry sequence> # optional comment
```

## Matching Class & Title
Class: One of 'browser', 'terminal' or 'other'. Windows are classified using the environment variables `$BROWSER`, `$TERMINAL`, `$BROWSERS`, and `$TERMINALS`.

Title Regex: matched against window title using `awk` regex.

## Credential Entry:
Pass Subfolder Fragment: The beginning of the name of a subfolder of `$PASSWORD_STORE_DIR`. If multiple subfolders share the given beginning, user will be prompted to choose one.

Entry Sequence: a string of characters that tells `pw` how to enter your credentials, read character by character:
- lowercase character -> selects an entry in the subfolder starting with that char (uses user input if there are multiple matches) & types its contents.
- '.' -> allows the user to choose any entry & types its contents
- '$' -> types contents of entry matching system hostname
- '~' -> types contents of entry matching current user's username
- 'T' -> presses the tab key
- 'E' -> presses the enter key
- ' ' -> presses the space key

## Examples
Here is an example line I have in my personal mapfile:
```
browser /// LinkedIn Login .* LinkedIn /// linkedin /// uTpE
```
It will match when the current window is a browser whose title matches that regex (ie the current tab is the linkedin login page). Let's suppose that in `$PASSWORD_STORE_DIR` I have 2 subfolders: `linkedin-alice` and `linkedin-bob`, each containing `user.gpg` & `pass.gpg`. Then, when I run `pw` with the browser window open, I will first be prompted to choose between the alice and bob accounts. Let's say I choose `linkedin-alice`. Then, `pw` will type the decrypted contents of `linkedin-alice/user.gpg` (the username) press `Tab`, type the contents of `linkedin-alice/pass.gpg` (password) and finally press `Return`, logging me in.

Or an example with the terminal:
```
terminal /// ssh /// ssh /// .E
```
Matches when the current window is a terminal, and the currently running command contains ssh. Let's say the `ssh` subfolder contains multiple entries (maybe passwords for different machines I frequently ssh into). Then when I run `pw`, I will be prompted to choose one of these passwords, it will be typed and the enter key will be hit, logging me into the remote connection.

# Installation
Simply clone this repo somewhere on your machine, `chmod +x` the `main.sh` file, and run `main.sh` anytime you want to run the program. You can also use an alias or add to the $PATH if it's convenient.

Personally, I use NixOS and have installed this script by adding `pkgs.writeShellScriptBin "pw" "/path/to/pw/main.sh $@"` to my `environment.systemPackages`. I've bound SUPER+P to `pw` and SUPER+SHIFT+P to `pw --interactive`.

I also use qutebrowser, and have created a userscript that runs `echo "hint inputs -f" >> "$QUTE_FIFO"` followed by `pw "$@"`. I've then bound a key to run this userscript. That way, when I press the keybind, I'm put into insert mode at the first input field and `pw` is run, I find this quicker & more convenient than clicking the input field myself and then pressing SUPER+P.

# Usage

# Troubleshooting
