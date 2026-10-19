#!/usr/bin/env bash
# msu (my-shell-utils)
#
# Copyright (c) 2015 GochoMugo <mugo@forfuture.co.ke>


#set -e errexit


MSU_EXE="${BASH_SOURCE[0]}"
MSU_REAL_EXE=$(readlink -f "${MSU_EXE}")
MSU_LIB=$(dirname "${MSU_REAL_EXE}") # directory holding our library
export MSU_EXE
export MSU_LIB


# modules
# shellcheck source=lib/core.sh
source "${MSU_LIB}/core.sh" # so LOW-LEVEL
msu_require "metadata"      # how you like me now?


# warn user, if we are running as root/superuser.
msu_run core_utils.is_superuser && {
  printf '\n'
  printf '%s\n' " !!         you are running as SUPERUSER        !! "
  printf '%s\n' " !! with much power, comes great responsibility !! "
  printf '%s\n' " !!           you have been WARNED!             !! "
  printf '\n'
}


# parse command line arguments
case "${1:-''}" in
  "env" )
    msu__load
  ;;
  "re" | "require" )
    msu_require "${2:-''}"
  ;;
  "r" | "run" )
    msu_run "${@:2}"
  ;;
  "x"  | "execute" )
    msu_execute "${2:-''}" "${@:3}"
  ;;
  "i" | "install" )
    msu_run core_utils.install "${@:2}"
    msu_run core_utils.update_check
  ;;
  "im" | "install-many" )
    msu_run core_utils.install_from_list "${@:2}"
    msu_run core_utils.update_check
  ;;
  "u" | "uninstall" )
    msu_run core_utils.uninstall "${@:2}"
    msu_run core_utils.update_check
  ;;
  "um" | "uninstall-many" )
    msu_run core_utils.uninstall_from_list "${@:2}"
    msu_run core_utils.update_check
  ;;
  "up" | "upgrade" )
    msu_run core_utils.upgrade "${2}"
  ;;
  "ls" | "list" )
    msu_run core_utils.list_modules "${2}"
    msu_run core_utils.update_check
  ;;
  "nk" | "nuke" )
    msu_run core_utils.nuke
  ;;
  "h" | "help" )
    if [ "${2}" ]
    then
      msu_run core_utils.show_help "${2}"
      msu_run core_utils.update_check
    else
      printf '\n'
      printf '%s\n' " msu by ${MSU_AUTHOR_NAME} <${MSU_AUTHOR_EMAIL}>"
      printf '\n'
      printf '%s\n' " usage:"
      printf '%s\n' "    msu require|install|uninstall <mod>..."
      printf '%s\n' "    msu execute <path> <arg>..."
      printf '%s\n' "    msu install-many|uninstall-many <path>..."
      printf '%s\n' "    msu run <mod>.<func>"
      printf '%s\n' "    msu list"
      printf '%s\n' "    msu upgrade [version]"
      printf '%s\n' "    msu nuke"
      printf '%s\n' "    msu version [mod]"
      printf '%s\n' "    msu where <mod>"
      printf '%s\n' "    msu help [mod]"
      printf '\n'
      printf '%s\n' " commands:"
      printf '%s\n' "    h  | help            show help information of module [mod] or this help info"
      printf '%s\n' "    i  | install         install the module(s) <mod>..."
      printf '%s\n' "    im | install-many    install from module-list(s) at path(s) <path>..."
      printf '%s\n' "    ls | list            list installed modules"
      printf '%s\n' "    nk | nuke            nuke msu entirely"
      printf '%s\n' "    r  | run             run the function <func> in module <mod>"
      printf '%s\n' "    re | require         require the library module <mod>"
      printf '%s\n' "    u  | uninstall       uninstall the module(s) <mod>..."
      printf '%s\n' "    um | uninstall-many  uninstall from module-list(s) at path(s) <path>..."
      printf '%s\n' "    up | upgrade         upgrade to the latest version"
      printf '%s\n' "    v  | version         show version information of module [mod] or msu itself"
      printf '%s\n' "    w  | where           show path to an external module"
      printf '%s\n' "    x  | execute         execute file at the path <path>"
      printf '\n'
      printf '%s\n' " for more help information, see msu(1)"
      printf '\n'
      printf '%s\n' " see https://github.com/GochoMugo/msu/issues for bug reporting"
      printf '%s\n' " and feature requests"
      printf '\n'
      msu_run core_utils.update_check
    fi
  ;;
  "v" | "version" )
    if [ "${2}" ]
    then
      msu_run core_utils.show_metadata "${2}"
    else
      printf '%s\n' "  version   ${MSU_VERSION}"
      printf '%s\n' "  build     ${MSU_BUILD_HASH:-?}"
      printf '%s\n' "  date      ${MSU_BUILD_DATE:-?}"
    fi
    msu_run core_utils.update_check
  ;;
  "w" | "where" )
    msu_run core_utils.where "${2}"
    msu_run core_utils.update_check
  ;;
  * )
    # maybe, we are being used in a shebang e.g. #!/usr/bin/env msu
    if [ "${1}" ]
    then
        FILE="$(readlink -f "${1}" 2> /dev/null)"
        if [ -r "${FILE}" ]
        then
            msu_execute "${FILE}" "${@:2}"
        fi
    fi
    # otherwise, we just ignore it!
  ;;
esac
