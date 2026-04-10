# Environment
Expects `$PASSWORD_STORE_DIR` to be set to a directory. It should contain folders, each one containing login credentials for a specific service. For example `$PASSWORD_STORE_DIR/google/pass.gpg` would be your google password.

Expects `$PASSWORD_STORE_DIR/blank.gpg` to be a file encrypted by the same key as all other gpg files in the folder. This file is used to test if the gpg key is unlocked and cached, so it shouldn't contain any sensitive data. You can create it like so: `echo blank | gpg -e -r <gpgid> > $PASSWORD_STORE_DIR/blank.gpg`

Expects `$DMENU_PROGRAM` to be set to the name of a program like `dmenu`. This means that the program should take a newline seprated list in stdin, and output one entry, chosen by the user, to stdout.

# Configuration
`pw` attempts to automatically enter the correct credentials based on window class & title. This behaviour is defined in the mapfile (`$PASSWORD_STORE_DIR/.map`). Each line in the mapfile defines one association between class/title and pass entries, as shown below (note that `pw` stops at the first line that matches the class & title, so put more specific regexes at the top of the mapfile)
```
<class> /// <title regex> /// <pass subfolder fragment> /// <entry sequence> # optional comment
```
- matching class & title: the line will match if both of these match
 - class:
  - 'browser' will match if window class is `$BROWSER` or appears in `$BROWSERS`
  - 'terminal' will match if window class is `$TERMINAL` or appears in `$TERMINALS`
  - 'other' will match anything else
 - title regex: will match if the window title matches the given regex
- credential entry:
 - pass subfolder fragment: the beginning of the name of a folder in in `$PASSWORD_STORE_DIR` to take credentials from. the fact that you only supply the beginning is useful if you have multiple accounts for the same website. for example, I may have two folders in the password directory: `linkedin-alice` and `linkedin-bob`. If I use `linkedin` in the mapfile, when i use pw and this line in the mapfile matches, I will be prompted to choose between `linkedin-alice` and `linkedin-bob`. If there is only one folder in the pass directory that starts with my fragment, I won't be prompted to choose.
 - entry sequence: a string of characters that tells `pw` how to enter your credentials. it's read character by character. For a lowercase character, `pw` will look for entries in the selected subfolder that start with that character. If there are multiple matches, the user will be prompted to choose one, and then the contents of that entry will be typed. Any other character must be one of:
  - '.' -> allows the user to choose any entry in the subfolder & types its contents
  - '$' -> types the contents of the entry that starts with the system hostname
  - '~' -> types the contents of the entry that starts with the current user's username
  - 'T' -> presses the tab key
  - 'E' -> presses the enter key
  - ' ' -> presses the space key

Here is an example line I have in my personal mapfile:
```
browser /// LinkedIn Login .* LinkedIn /// linkedin /// uTpE
```
It will match when the current window is a browser whose title matches that regex (ie the current tab is the linkedin login page). Let's suppose that in `$PASSWORD_STORE_DIR` I have 2 subfolders: `linkedin-alice` and `linkedin-bob`, each containing `user.gpg` & `pass.gpg`. Then, when I run `pw` with the browser window open, I will first be prompted to choose between the alice and bob accounts. Let's say I choose `linkedin-alice`. Then, `pw` will type the decrypted contents of `linkedin-alice/user.gpg` (the username) press `Tab`, type the contents of `linkedin-alice/pass.gpg` (password) and finally press `Return`, logging me in.

# Installation

# Usage


# Troubleshooting
