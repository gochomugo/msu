
# msu

> A minimal Bash framework and CLI tool that makes writing, sharing
> and using bash scripts easy

[![Tests](https://github.com/GochoMugo/msu/workflows/Tests/badge.svg)](https://github.com/GochoMugo/msu/actions/workflows/test.yml)

* [Features](#features)
* [Installation](#installation)
* [Documentation](#documentation)
* [Showcase of modules using `msu`][showcase]
* [Project principles](#project-principles)
* [License](#license)
* Introductory blog posts:
  - [hack with msu](https://mugo.gocho.live/posts/hack-with-msu/)
  - [very first post](https://mugo.gocho.live/posts/msu-introduction/)


## features

> **`msu` wishlist**

* [x] [easy installation](#installation)
* [x] self upgrade
* [x] small internal library
* [x] tested on every bash release from 3.2 through 5.3
* [x] supports external modules
* [x] auto-loading aliases from modules
* [x] manpages
* [x] bash completion
* [ ] load/unload aliases
* [ ] error catching/handling
* [ ] compatibility for other shell types e.g. zsh


## installation

There are different ways of installing `msu`.

1. The preferred way is to use the **OFFICIAL RELEASE**. Download
   the latest tarball at https://github.com/GochoMugo/msu/releases/latest:

    ```bash
    $ tar xvf msu-x.x.x.tar.gz
    $ cd msu-x.x.x/
    $ ./install.sh
    ```

1. **Manual installing** by cloning this repo and running the
   `install.sh` script.

    ```bash
    $ git clone https://github.com/GochoMugo/msu.git
    $ cd msu/
    $ ./install.sh
    ```

   This method is preferable if you will be contributing to the 
   project. Note that this uses the master branch, possibly with
   unreleased changes. Also, the manpages are **not** installed.

See further [installation instructions][installation].


## documentation

You can browse msu documentation from your terminal using `man`:

```bash
$ man 1 msu       # command
$ man 3 msu       # library
```

A guide for [contributing to msu][contributing] is also available.


## project principles

1. **Little added complexity.** `msu` should **not** warrant the user to learn scripting all over again. An existing script should be converted into a module with less effort.
1. **Minimal**. `msu` core should be as little as possible. How? Use common algorithms and data structures. Avoid doing something too fancy.
1. **Highly configurable**. Using environment variables and command-line switches, `msu` should be configurable in all its operations, including installation.


## license

__The MIT License (MIT)__

Copyright &copy; 2015 GochoMugo <mugo@forfuture.co.ke>


[contributing]:https://github.com/GochoMugo/msu/blob/master/docs/contributing.md "Contributing to msu"
[installation]:https://github.com/GochoMugo/msu/tree/master/docs/installation.md "msu installation"
[showcase]:https://github.com/GochoMugo/msu/wiki/Showcase "showcase of modules using msu"
