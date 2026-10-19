#!/usr/bin/env bash
# The Core
#
# Copyright (c) 2015 GochoMugo <mugo@forfuture.co.ke>


# we expect the executable exports a variable $MSU_LIB whose
# value is the path to the library holding this and other modules
if [ ! "${MSU_LIB}" ]
then
  # without this path, we can not do anything! We should exit now!
  printf '%s\n' "error: core: library path not set '${MSU_LIB}'" > /dev/stderr
  exit 1
fi


# mod vars
MSU_REQUIRE_LOCK='' # lock to ensure we don't source an already-sourced file
MSU_EXTERNAL_LIB="${MSU_EXTERNAL_LIB:-${HOME}/.msu}"
export MSU_EXTERNAL_LIB


# Logs a warning for each missing command set in ${DEPS}.
function msu__check_deps() {
  if [ ! "${DEPS}" ]
  then
    return
  fi
  for cmd in ${DEPS}
  do
    command -v "${cmd}" > /dev/null 2>&1 || {
      printf '%s\n' "warning: \`${cmd}' not found"
    }
  done
}


# Loads msu into current environment.
# Used from .bashrc.
function msu__load() {
  # loading aliases
  msu_require aliases

  # loading bash completion
  msu_require completion

  # clean up environment
  # Added by msu.sh
  unset MSU_EXE
  unset MSU_REAL_EXE
  unset MSU_LIB
  # Added by metadata.sh
  unset MSU_AUTHOR_NAME
  unset MSU_AUTHOR_EMAIL
  unset MSU_VERSION
  unset MSU_BUILD_HASH
  unset MSU_BUILD_DATE
  unset MSU_INSTALL_LIB
  unset MSU_INSTALL_BIN
  unset MSU_INSTALL_MAN
  unset MSU_INSTALL_LOAD_STRING
  # Added by core.sh
  unset MSU_REQUIRE_LOCK
  unset msu__check_deps
  unset msu__load
  unset msu_require
  unset msu_run
  unset msu_execute
}


# Loads a module into current environment.
#
# ${1} - Module path
function msu_require() {
  local resolved_paths=(
    "${MSU_LIB}/${1}.sh"
    "${MSU_EXTERNAL_LIB}/${1}.sh"
  )

  for resolved_path in "${resolved_paths[@]}" ; do
      case "${MSU_REQUIRE_LOCK}" in
        *":${resolved_path}:"*)
          return
          ;;
      esac
      if [ ! -f "${resolved_path}" ] ; then
          continue
      fi
      # shellcheck disable=SC1090
      source "${resolved_path}" || {
        printf '%s\n' "error: msu_require: failed to load module '${1}'" > /dev/stderr
        exit 1
      }
      msu__check_deps
      MSU_REQUIRE_LOCK=":${resolved_path}:${MSU_REQUIRE_LOCK}"
      return
  done

  printf '%s\n' "error: msu_require: did not find module '${1}'" > /dev/stderr
  exit 1
}


# Runs a function in a module.
#
# ${1} - Module path, '.' and function name concatenated
function msu_run() {
  local module
  local func
  local args
  local script
  module="${1%.*}"
  func="${1##*.}"
  args=""
  for arg in "${@:2}" ; do
      args+=" '${arg}'"
  done
  script=$(cat << EOF
  set -e
  MSU_LIB="${MSU_LIB}"
  source "${MSU_LIB}/core.sh"
  msu_require "${module}"
  if [ "\$(type -t "${func}")" == 'function' ] ; then
    ${func} ${args[@]}
  else
    printf '%s\n' "error: msu_run: can not find function '${func}'" > /dev/stderr
    exit 1
  fi
EOF
  )
  bash -c "${script}"
}


# Loads a file into current environment.
#
# ${1} - File path
function msu_execute() {
  # shellcheck source=/dev/null
  source "${1}"
}
