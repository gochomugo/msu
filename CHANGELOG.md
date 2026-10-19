
# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).


## Unreleased

Fixed:

* Nuking msu should remove the load string from .bashrc.


## [0.8.2][0.8.2] - 2026-10-17

Changed:

* Replaced `wget` with `curl` for self upgrade.

Fixed:

* Notify user of new version (for upgrade) via stderr.
  This prevents cloberring of output when msu is used in a sub-shell.


## [0.8.1][0.8.1] - 2026-04-04

Fixed:

* Fix passing multiple arguments to `install-many` and `uninstall-many`
  sub-commands.


## [0.8.0][0.8.0] - 2026-03-28

Changed:

* `help` sub-command shows more information from
  external module.


## [0.7.0][0.7.0] - 2026-03-15

Added:

* `help` sub-command can show documentation of aliases
  in an external module.
* `install-many`, `uninstall` and `uninstall-many`
  sub-commands support the `--force` flag.
* Added bash completion.

Changed:

* `uninstall` fails if module does not exist, unless
  `--force` flag is used.


## [0.6.0][0.6.0] - 2026-03-09

Added:

* Added `where` sub-command.

Fixed:

* `install` command does not fail if installing from local path.
* `install` outputs error properly.
* `run` command supports interactive functions.
* `upgrade` command returns an exit code of zero if already at latest version.


## [0.5.0][0.5.0] - 2026-01-07

Added:

* Automatically checks for updates when some msu commands,
  such as `msu help`, are run.


## [0.4.0][0.4.0] - 2025-12-11

Revamped after years of neglect!


## [0.3.0][0.3.0] - 2016-03-19

Added:

* check dependencies aggressively, on installation

Removed:

* the `fs` and `net` modules are removed, to keep `msu` minimal


## [0.2.0][0.2.0] - 2016-02-26

Added:

* add command, `nuke`, for nuking `msu` (issue #19)
* add support for SSH in installing modules from private, remote repos (issue #18)
* allow assuming "yes" in a `yes_no` question, using `${MSU_ASSUME_YES}`

Fixed:

* fix using backspace as first key-press in password prompt
* fix unnecessary logging to a file named `log` when using `msu` in a shebang
* fix listing external modules, when directory at `${MSU_EXTERNAL_LIB}` does **not** exist
* fix listing internal modules i.e. only list the `*.sh` files


## [0.1.0][0.1.0] - 2016-02-13

Added:

* add the alias `msu.reload` for reloading aliases
* add support for use in shebang e.g `#!/usr/bin/env msu`

Changed:

* prefix all aliases added by msu library with `msu`

Fixed:

* Fix path to executable, if executed directly (not through symlink)


## [0.0.0][0.0.0] - 2016-01-24

This is the very first version of `msu`.


<!-- Release links are placed here for easier updating -->
[0.0.0]:https://github.com/GochoMugo/msu/releases/tag/0.0.0
[0.1.0]:https://github.com/GochoMugo/msu/releases/tag/0.1.0
[0.2.0]:https://github.com/GochoMugo/msu/releases/tag/0.2.0
[0.3.0]:https://github.com/GochoMugo/msu/releases/tag/0.3.0
[0.4.0]:https://github.com/GochoMugo/msu/releases/tag/0.4.0
[0.5.0]:https://github.com/GochoMugo/msu/releases/tag/0.5.0
[0.6.0]:https://github.com/GochoMugo/msu/releases/tag/0.6.0
[0.7.0]:https://github.com/GochoMugo/msu/releases/tag/0.7.0
[0.8.0]:https://github.com/GochoMugo/msu/releases/tag/0.8.0
[0.8.1]:https://github.com/GochoMugo/msu/releases/tag/0.8.1
[0.8.2]:https://github.com/GochoMugo/msu/releases/tag/0.8.2
