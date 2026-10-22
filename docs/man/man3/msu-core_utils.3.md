% msu-core_utils(3)
%
% November 2025


NAME
----

msu-core_utils - utilities for use with msu core.


SYNOPSIS
--------

These utilities help build up the msu ecosystem by offering functions
very common in working with msu.

    msu_require "core_utils"


DESCRIPTION
-----------

*upgrade(['VERSION'])*

   > Upgrades msu to version 'VERSION', if it is passed. Otherwise,
   > the function defaults to upgrading to the latest version. This
   > may hit the network to check for new releases and download
   > tarballs.

*install(['MODULE']...)*

   > Installs the modules 'MODULE'... into the directory pointed to
   > by `${MSU_EXTERNAL_LIB}`. To install remote modules, we require
   > prefix shorthands:

      bt: - from Bitbucket, using HTTPS e.g. 'bt:myusername/myrepo'
      bts: - from Bitbucket, using SSH e.g. 'bts:myusername/myrepo'
      gh: - from Github, using HTTPS e.g. 'gh:myusername/myrepo'
      ghs: - from Github, using SSH e.g. 'ghs:myusername/myrepo'
      gl: - for GitLab, using HTTPS e.g. 'gl:myusername/myrepo'
      gls: - for GitLab, using SSH e.g. 'gls:myusername/myrepo'

*install-many('PATH')*

   > Using a file at path 'PATH' containing a '\n'-delimited list
   > of modules, installs the listed modules. Shorthands can be
   > used in this list. This is useful in bootstrapping machines.

*uninstall(['MODULE']...)*

   > Uninstalls the modules 'MODULE'... from the directory pointed
   > to by `${MSU_EXTERNAL_LIB}`.

*uninstall-many('PATH')*

   > Using a file at path 'PATH' containing a '\n'-delimited list of
   > modules, uninstall the listed modules. As expected, shorthands
   > can not be used here.

*has_command('COMMAND')*

   > Return 0 if 'COMMAND' is available on the system. Otherwise,
   > return a non-zero return code.

*is_superuser()*

   > Return 0 if we are running as super-user (root). Otherwise,
   > return 1.

*list_modules()*

   > List installed external modules.

*sha256_file('FILE')*

   > Prints the sha256 checksum of the file 'FILE' to stdout.
   > Uses `sha256sum` when available, falling back to `shasum`.
   > Returns 1 if no sha256 tool is found.

*verify_checksum('FILE', 'CHECKSUM_FILE')*

   > Verifies that the file 'FILE' matches the checksum recorded
   > in the checksum file 'CHECKSUM_FILE'. Returns 0 for a match
   > and 1 on mismatch, missing or malformed checksum file.

*where('MODULE')*

   > Echoes the installation path of the external module 'MODULE'.
   > Returns 1 if module not installed.


RESOURCES
---------

Source code: https://github.com/GochoMugo/msu

Issue tracker: https://github.com/GochoMugo/msu/issues


AUTHOR
------

*msu* is developed and maintained by Gocho Mugo.


COPYING
-------

THE MIT LICENSE (MIT)

Copyright \(C) 2015 Gocho Mugo \<mugo@forfuture.co.ke>
