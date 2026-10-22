% msu(1)
%
% November 2025


NAME
----
msu - my shell utilities


SYNOPSIS
--------
*msu* require|install|uninstall 'MODULE'...

*msu* execute|install-many|uninstall-many 'PATH'

*msu* run 'MODULE'.'FUNC'

*msu* list

*msu* upgrade ['VERSION']

*msu* nuke

*msu* version ['MODULE']

*msu* where 'MODULE'

*msu* help ['MODULE']


DESCRIPTION
-----------

The msu(1) command adds useful utilities for use in your shell.
*msu* stands for 'My' 'Shell' 'Utilities'.


COMMANDS
--------

*h, help* ['MODULE']

   > Shows documentation of aliases of the specified module 'MODULE'.
   > If no module is specified, shows basic help information, shortened
   > for easier recap.

*i, install* 'MODULE'...

   > Installs the module 'MODULE' into the directory at
   > `${MSU_EXTERNAL_LIB}`. The module can be located either locally
   > or remotely.

   > If remote, a prefix shorthand is required to determine where to
   > fetch the module from. Available case-insensitive shorthands
   > include:

      bt: - from Bitbucket, using HTTPS e.g. 'bt:myusername/myrepo'
      bts: - from Bitbucket, using SSH e.g. 'bts:myusername/myrepo'
      gh: - from Github, using HTTPS e.g. 'gh:myusername/myrepo'
      ghs: - from Github, using SSH e.g. 'ghs:myusername/myrepo'
      gl: - for GitLab, using HTTPS e.g. 'gl:myusername/myrepo'
      gls: - for GitLab, using SSH e.g. 'gls:myusername/myrepo'

   > If the remote repository is private, SSH should be used
   > instead. This allows avoiding being prompted for password and
   > the request being rejected in cases where 2FA is enabled.

   > You can specify a version, using a git tag. For example,
   > 'gh:myusername/myrepo#v0.0.0' would fetch the remote module
   > at version 'v0.0.0', provided the git tag ('v0.0.0'; exactly
   > as specified) exists.

*im, install-many* 'PATH'

   > Installs modules listed in a file at path 'PATH'. Each line
   > of the file is assumed to be a single module and is eventually
   > passed to the *install* sub-command. This is useful when
   > bootstrapping machines.

*ls, list*

   > Lists the external modules you have installed.

*nk, nuke*

   > Uninstalls msu entirely from the machine. This involves
   > removing the msu executable, internal and external modules,
   > load strings added to ~/.bashrc and manpages.

*r, run* 'MODULE'.'FUNC'

   > Runs the function 'FUNC' in the module 'MODULE'. Any extra
   > arguments are passed to the function as is.

   > For example,

        $ msu run console.success 'a success message'

*re, require* 'MODULE'...

   > Loads the module 'MODULE' into a new bash environment,
   > making the modules' functions and variables available.
   > Usually, this environment should 'sourced' into the current
   > environment.

   > For example,

        $ . msu require console
        $ success 'a success message'

*u, uninstall* 'MODULE'...

   > Uninstalls the module 'MODULE' by removing its contents from
   > `${MSU_EXTERNAL_LIB}`.

*um, uninstall-many* 'PATH'

   > Uninstalls modules listed in a file at path 'PATH'. Each line
   > of the file is assumed to be a single module and is eventually
   > passed to the *uninstall* sub-command. This is useful in
   > un-bootstrapping machines (as a reverse of *install-many*).

*up, upgrade* ['VERSION']

   > Upgrades msu to the version 'VERSION', if passed. Otherwise
   > upgrades to the latest version. This request may hit the
   > network to check for new versions and execute downloads if
   > necessary. The downloaded tarball is verified against its
   > sha256 checksum before it is used. Concurrent upgrades are
   > prevented using a lock directory at '${TMPDIR}/.msu.upgrade.lock';
   > the lock is released when the upgrade ends, successfully or
   > not. Upgrade failures leave the existing installation intact.

*v, version* ['MODULE']

   > Shows version information for the module 'MODULE', if passed.
   > Otherwise, shows version information for msu itself.

*w, where* 'MODULE'

   > Prints the installation path of the external module 'MODULE'.
   > Exits with an error if module not installed.

*x, execute* 'PATH'

   > Executes the file at path 'PATH' by simply running the code
   > through bash, with the core library loaded before-hand. This
   > emulates the action of running a function with its body being
   > the contents of the file. This command should be considered
   > DANGEROUS as it is able to execute commands in a file without
   > the execution bit set.


ENVIRONMENT VARIABLES
---------------------

*`${MSU_EXTERNAL_LIB}`*

   > Set to the path to the directory holding the external modules.
   > It is where modules are installed to, with the *install*
   > and *install-many* sub-commands. It defaults to
   > `${HOME}/.msu`.

*`${MSU_STRICT_MODE}`*

   > Set to `0` to disable strict mode when msu is executed
   > directly (e.g. `msu version`) or used in a shebang. See
   > the STRICT MODE section below.

*`${MSU_DEBUG}`*

   > Set to `1` to trace execution of msu, e.g.

        $ MSU_DEBUG=1 msu version

   > Tracing only happens when msu is executed directly or
   > used in a shebang. It has no effect when msu is sourced
   > (e.g. `. msu env`).


ALIASES
-------

On startup, aliases are loaded. Aliases added by msu are prefixed
with 'msu'. Remember any alias (including those added by msu itself)
can be overridden. See msu(3) for more details on how aliases work.

One of the most important aliases is *msu.reload*.

*msu.reload*

   > Reloads aliases from internal and external modules. This
   > allows you to load new aliases after installing modules.

Other aliases are listed in man(3).


SHEBANG
-------

msu can be used in a shebang line, which in almost all cases would
be '#!/usr/bin/env msu'. The shell script (using the shebang),
would receive the path to itself as `${1}` and have the other
arguments follow as normal, in `${2}`, `${3}`, ... This means
that the script can accept command-line arguments.


STRICT MODE
-----------

When msu is executed directly or used in a shebang, strict mode is
enabled: `errexit`, `nounset` and `pipefail` are set, along with
`inherit_errexit` and `lastpipe` on bash versions that support them
(>= 4.4 and >= 4.2 respectively). This makes msu fail fast and
loudly on errors.

When msu is sourced (e.g. `. msu env` from `~/.bashrc`), strict
mode is NOT set, to avoid leaking the options into your shell.

Set `${MSU_STRICT_MODE}` to `0` to disable strict mode, e.g.

    $ MSU_STRICT_MODE=0 msu execute script.sh


CAVEATS
-------

The commands *install*, *install-many* and *upgrade* use git for
cloning repositories and generating module metadata. Therefore, the
command git(1) must be available.


UPGRADE INTEGRITY
-----------------

The tarball downloaded by *upgrade* is verified against the sha256
checksum published alongside the release (msu-x.y.z.tar.gz.sha256),
before it is used.

The TRUST BOUNDARY is the msu GitHub repository
(https://github.com/GochoMugo/msu) and anyone able to create or
modify a release in it. The checksum file is unsigned and taken
from the same source as the tarball, with which it shares the
trust. For this reason, verification protects against corrupted,
truncated or MANIPULATED-IN-TRANSIT downloads (e.g. through
proxies or mirrors), NOT against an attacker who can modify the
release itself. msu does not sign releases, since signing secrets
should not be entrusted to disk images and CI runners.


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
