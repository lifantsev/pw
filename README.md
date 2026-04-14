## Description

`pw` is a simple bash script that turns the `$PASSWORD_STORE_DIR` into a convenient password manager with autofilling capabilities. Navigate to a login page, run `pw`, and the correct credentials will automatically be typed and entered, instantly logging you in. It looks at the current window's class and title to decide which password files to decrypt and type (this behaviour is [fully configurable](#mapfile)).
- Note that although `pw` is great to use along with `pass`, it does not depend on it. All you need is a password-store containing gpg files.

### Why use `pw`?
- It automatically fills in all credentials with no user input required (as long as you [set up rules in the mapfile](#mapfile))
    - If you haven't set up a rule, you manually choose a password store entry
- It's as fast as possible without fully removing control from the user (all you do is run it)
    - On my machine `pw` takes ~300ms to automatically detect the website, type username and password, and hit enter
    - 200ms of that is waiting for `gpg` to decrypt files
- It can be used to enter passwords into any application - not just browsers
- It's not a browser extension
    - Some browsers like `qutebrowser` don't support extensions
    - Extensions are prone to [some security issues](https://cmpxchg8b.com/passmgrs.html)

### Why not use `pw`
- You don't use wayland (`pw` depends on `wl-copy` and `wtype`)
- You want website detection rules out of the box (`pw` expects you to [manually set them](#mapfile))
- You want OTP support
- You don't format your password store the way `pw` expects: a folder for each account, with a separate gpg file for each credential. for example:
    - `$PASSWORD_STORE_DIR/google-personal/` containing `username.gpg` and `password.gpg`
    - `$PASSWORD_STORE_DIR/spotify/` containing `username.gpg` and `password.gpg`

### Alternatives
- [tessen](https://github.com/ayushnix/tessen): a more mature project, but it doesn't automatically detect the website/application
- [browserpass](https://github.com/browserpass/browserpass-extension): comes with the advantages and disadvantages of being a browser extension
- [awesome-password-store](https://github.com/tijn/awesome-password-store): a list of extensions and interfaces for `pass`

## Installation
Simply clone this repo somewhere on your machine, `chmod +x` the `main.sh` file, and run `main.sh` anytime you want to run the program. You can also use an alias or add to the $PATH if it's convenient.

Personally, I use NixOS and have installed this script by adding `pkgs.writeShellScriptBin "pw" ''/path/to/pw/main.sh "$@"''` to my `environment.systemPackages`. I've bound SUPER+P to `pw`. I also use this qutebrowser userscript: `echo "hint inputs -f" >> "$QUTE_FIFO" && pw "$@"`. This puts me in insert mode at the first input field and then runs `pw`. I find this convenient, and you might too.

## Usage
`pw` is best used by creating a keybinding that runs it.
### no args
Tries to match the current window's class & title against lines in the mapfile. If a match is found, enters credentials automatically based on the subfolder and entry sequence specified on that line (see [configuration](#mapfile) section). If no match is found, the user is prompted to select an entry in the password store, whose contents will be typed.
### --interactive
Same as `pw` with no args but asks for user confirmation at every step, even if a match in the [mapfile](#mapfile) is found. The subfolder specified by the [mapfile](#mapfile) is used to highlight certain folders when the user is choosing from a list of them. The entry sequence is ignored, and the user just chooses one entry to type.
### --log
Enables logging to `/tmp/pw.log`. This shows values of variables & provides insight into the control flow of the program.
### -h | --help
Prints the contents of `quickhelp.txt` and exits.
### --readme
Prints the contents of this README and exits.

## Environment
- `$PASSWORD_STORE_DIR` Should be set to a directory containing folders that contain login credentials.
    - For example `$PASSWORD_STORE_DIR/google/pass.gpg` would be your google password.

- `$DMENU_PROGRAM` Should be set to the name of a program like `dmenu`, `rofi`, or `bemenu`.

- `$GET_WINDOW_CLASS` Should be a script that outputs the current window's class.
    - For hyprland: `hyprctl activewindow -j | jq -r .class`

- `$GET_WINDOW_TITLE` Should output window title
    - For hyprland: `hyprctl activewindow -j | jq -r .title`
    - I use: `t="$(hyprctl activewindow -j | jq -r .title)"; [[ "$(eval "$GET_WINDOW_CLASS")" == *"qutebrowser"* ]] && echo "${t/ - [^ ]*/} $(browser get-url | sed -e 's|^[^/]*//\([^/]*\)/.*|[\1]|')" || echo "$t"`
        - This appends the url of the site to the title if the current window is qutebrowser, and leaves the title unchanged otherwise. This is nice because now I can match against exact urls in my [mapfile](#mapfile), instead of the plain title which is sometimes an ambiguous string like `Login`.
            - Note that [`browser`](https://github.com/lifantsev/nixos/blob/main/config/custom-scripts/browser.sh) is a script I wrote that interfaces with a [qutebrowser userscript](https://github.com/lifantsev/nixos/blob/main/home/qutebrowser/userscripts/urlupdater.sh) to fetch the url of the currently active window
        - This can be replicated on chrome based browsers using the [url-in-title extension](https://chromewebstore.google.com/detail/url-in-title/ignpacbgnbnkaiooknalneoeladjnfgb).

## Mapfile
`pw` attempts to automatically enter the correct credentials based on window class & title. This behaviour is defined in the mapfile (`$PASSWORD_STORE_DIR/.map`). Each line in the mapfile defines one association between class/title and pass entries, as shown below (note that `pw` stops at the first line that matches the class & title, so put more specific regexes at the top of the mapfile)
```
<class> /// <title regex> /// <folder name fragment> /// <entry sequence> # optional comment
```

### Matching Class & Title
`<class>`: One of 'browser', 'terminal' or 'other'. Windows are classified using the environment variables `$BROWSER`, `$TERMINAL`, `$BROWSERS`, and `$TERMINALS`.

`<title regex>`: matched against window title using `awk` regex.

### Credential Entry:
`<folder name fragment>`: The beginning of the name of a subfolder of `$PASSWORD_STORE_DIR`. If multiple subfolders share the given beginning, user will be prompted to choose one.

`<entry sequence>`: a string of characters that tells `pw` how to enter your credentials, read character by character:
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
It will match when the current window is a browser with the linkedin login page open. Let's suppose that in `$PASSWORD_STORE_DIR` I have 2 subfolders: `linkedin-alice` and `linkedin-bob`, each containing `user.gpg` & `pass.gpg`. Then, when I run `pw`, I will first be prompted to choose between the alice and bob accounts. Let's say I choose `linkedin-alice`. Then, `pw` will type the decrypted contents of `linkedin-alice/user.gpg` (the username), press `Tab`, type the contents of `linkedin-alice/pass.gpg` (password), and finally press `Return`, logging me in.

Or an example with the terminal:
```
terminal /// ssh /// ssh-passwords /// .E
```
Matches when the current window is a terminal, and the currently running command contains ssh. Let's say the `ssh-passwords` subfolder contains multiple entries (maybe passwords for different machines I frequently ssh into). Then when I run `pw`, I will be prompted to choose one of these passwords, it will be typed and the enter key will be hit, logging me into the remote connection.

## Dependencies

- `gpg`, to decrypt passwords
- `wl-copy`, to copy passwords
- `wtype`, to press 'Tab', 'Enter', 'Space' and 'Ctrl+V' to paste passwords
- `awk`, to find lines in the mapfile that match the window's class & title

## Troubleshooting

- Make sure all required [env vars](#environment) are set correctly.
- Make sure your `gpg-agent` is set up correctly, and caches passwords properly
- Use the logging flag: `pw --log` and look for issues in the logs
    - Check that `window_title` and `window_class` have the values you would expect
        - If they don't, look for problems with `eval "$GET_WINDOW_TITLE"` and `eval "$GET_WINDOW_CLASS"`.
    - Check that `pass_entry_folder_fragment` and `pass_entry_sequence` have the values you expect
        - If not, look for problems with your mapfile, check the regex patterns etc
    - Check that your clipboard is working properly, maybe `wl-copy` isn't properly copying the password
    - Check that the line `end of main.sh` appears at the bottom of the log.
        - If not, some command might be hanging.

