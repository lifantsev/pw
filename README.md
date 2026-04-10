## Description

`pw` turns the `$PASSWORD_STORE_DIR` into a convenient password manager with autofilling capabilities. Navigate to a login page, run `pw`, and the correct credentials will automatically be typed and entered, instantly logging you in. It looks at the current window's class and title to decide which password file to decrypt and type (this behaviour is [fully configurable](#configuration)). Note that although `pw` is great to use along with `pass`, it does not depend on it. All you need is a password-store with gpg files.

### Why use `pw`?
- It automatically fills in all credentials with no user input required (as long as you [set up rules in the mapfile](#configuration))
    - If you haven't set up a rule, you manually choose which password store entry to type
- It can be used to enter passwords into any application - not just browsers
- It's as fast as possible without fully removing control from the user (all you do is run it)
    - On my machine `pw` takes ~350ms to automatically detect the website, type username and password, and hit enter
    - 200ms of that is waiting for `wl-copy` and `gpg`
- It's not a browser extentsion (those are prone to [some issues](https://cmpxchg8b.com/passmgrs.html))
- You use a browser that doesn't support extensions (like `qutebrowser`)

### Why not to use `pw`
- you don't use wayland (`pw` depends on `wl-copy` and `wtype`)
- you want website detection rules out of the box (you need to [manually set them](#configuration))
- you want OTP support

### Alternatives
- [tessen](https://github.com/ayushnix/tessen): a more mature project, but it doesn't automatically detect the website/application (requires user input)
- [browserpass](https://github.com/browserpass/browserpass-extension): comes with the advantages and disadvantages of being a browser extension
- [awesome password store](https://github.com/tijn/awesome-password-store): a list of extensions and interfaces for `pass`

## Installation
Simply clone this repo somewhere on your machine, `chmod +x` the `main.sh` file, and run `main.sh` anytime you want to run the program. You can also use an alias or add to the $PATH if it's convenient.

Personally, I use NixOS and have installed this script by adding `pkgs.writeShellScriptBin "pw" ''/path/to/pw/main.sh "$@"''` to my `environment.systemPackages`. I've bound SUPER+P to `pw` and SUPER+SHIFT+P to `pw --interactive`. I also use qutebrowser, and have created a userscript: `echo "hint inputs -f" >> "$QUTE_FIFO" && pw "$@"`. This puts me in insert mode at the first input field and then runs `pw`. I find this convenient, and you might too.

## Usage
`pw` is best used by creating a keybinding that runs it.
### no args
Tries to match the current window's class & title against lines in the mapfile. If a match is found, enters credentials automatically based on the subfolder fragment and entry sequence on that line (see [configuration](#configuration) section). If no match is found, the user is prompted to select a subfolder, then an entry in it, and its contents will simply be typed.
### --interactive
Similar to `pw` with no args but asks for user confirmation at every step. Even if a match in the [mapfile](#configuration) is found, the user is still prompted to choose a subfolder, except the matches are separated at the top of the list of choices. Then the user chooses an entry in the subfolder, which is typed.
### --log
Enables logging to `/tmp/pw.log`. This shows values of variables & control flow of the program.
### -h | --help
Prints the contents quickhelp.txt and exits.
### --readme
Prints the contents of this README and exits.

## Environment
- `$PASSWORD_STORE_DIR` Should be set to a directory containing folders that contain login credentials.
    - For example `$PASSWORD_STORE_DIR/google/pass.gpg` would be your google password.

- `$PASSWORD_STORE_DIR/blank.gpg` Should exist and be encrypted with the same gpg key as everything else.
    - You can create it like so: `echo blank | gpg -e -r my-gpg-id > $PASSWORD_STORE_DIR/blank.gpg`

- `$DMENU_PROGRAM` Should be set to the name of a program like `dmenu`, `rofi`, or `bemenu`.

- `$GET_WINDOW_CLASS` Should be a script that outputs the current window's class.
    - For hyprland: `hyprctl activewindow -j | jq -r .class`

- `$GET_WINDOW_TITLE` Should output window title
    - For hyprland: `hyprctl activewindow -j | jq -r .title`

- `$GPG_UNLOCK` Optionally a script that allows the user to unlock their gpg key
    - If not set, defaults to `gpg --quiet -d $PASSWORD_STORE_DIR/blank.gpg`

## Configuration
`pw` attempts to automatically enter the correct credentials based on window class & title. This behaviour is defined in the mapfile (`$PASSWORD_STORE_DIR/.map`). Each line in the mapfile defines one association between class/title and pass entries, as shown below (note that `pw` stops at the first line that matches the class & title, so put more specific regexes at the top of the mapfile)
```
<class> /// <title regex> /// <folder name fragment> /// <entry sequence> # optional comment
```

### Matching Class & Title
Class: One of 'browser', 'terminal' or 'other'. Windows are classified using the environment variables `$BROWSER`, `$TERMINAL`, `$BROWSERS`, and `$TERMINALS`.

Title Regex: matched against window title using `awk` regex.

### Credential Entry:
Folder Name Fragment: The beginning of the name of a subfolder of `$PASSWORD_STORE_DIR`. If multiple subfolders share the given beginning, user will be prompted to choose one.

Entry Sequence: a string of characters that tells `pw` how to enter your credentials, read character by character:
- lowercase character -> selects an entry in the subfolder starting with that char (uses user input if there are multiple matches) & types its contents.
- `.` -> allows the user to choose any entry & types its contents
- `$` -> types contents of entry matching system hostname
- `~` -> types contents of entry matching current user's username
- `T` -> presses the tab key
- `E` -> presses the enter key
- ` ` -> presses the space key

### Examples
Here is an example line I have in my personal mapfile:
```
browser /// LinkedIn Login .* LinkedIn /// linkedin /// uTpE
```
It will match when the current window is a browser with the linkedin login page open. Let's suppose that in `$PASSWORD_STORE_DIR` I have 2 subfolders: `linkedin-alice` and `linkedin-bob`, each containing `user.gpg` & `pass.gpg`. Then, when I run `pw`, I will first be prompted to choose between the alice and bob accounts. Let's say I choose `linkedin-alice`. Then, `pw` will type the decrypted contents of `linkedin-alice/user.gpg` (the username) press `Tab`, type the contents of `linkedin-alice/pass.gpg` (password) and finally press `Return`, logging me in.

Or an example with the terminal:
```
terminal /// ssh /// ssh /// .E
```
Matches when the current window is a terminal, and the currently running command contains ssh. Let's say the `ssh` subfolder contains multiple entries (maybe passwords for different machines I frequently ssh into). Then when I run `pw`, I will be prompted to choose one of these passwords, it will be typed and the enter key will be hit, logging me into the remote connection.

## Dependencies

- `gpg`, to decrypt passwords
- `wl-copy`, to copy passwords
- `wtype`, to press 'Tab', 'Enter' and 'Ctrl+V' to paste passwords

## Troubleshooting

TODO
