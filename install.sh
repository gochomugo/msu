#!/usr/bin/env bash
# Installs msu
#
# Copyright (c) 2015 GochoMugo <mugo@forfuture.co.ke>


set -o errexit
set -o nounset


LIB="${LIB:-${HOME}/lib}"
MARKER=" >>>"
MSU_LIB="${LIB}/msu"
PREVIOUS_LOAD_STRING=""


if [ -f "${MSU_LIB}/metadata.sh" ] ; then
  printf '%s\n' "${MARKER} loading existing metadata"
  # shellcheck disable=SC1090,SC1091
  source "${MSU_LIB}/metadata.sh"
  PREVIOUS_LOAD_STRING="${MSU_INSTALL_LOAD_STRING:-}"
fi


BASHRC="${BASHRC:-${HOME}/.bashrc}"
BASHRC_TMP_FILE="${BASHRC}.msu-migrate"
BIN="${BIN:-${HOME}/bin}"
MAN="${MAN:-${HOME}/share/man}"
MSU_EXE="${BIN}/msu"
MSU_MAN="${MAN}"
EXPORT_MAN_PATH="export MANPATH=\"${MSU_MAN}\":\${MANPATH}"
EXPORT_BIN_PATH="export PATH=\"${BIN}\":\${PATH}"


trap 'rm -f "${BASHRC_TMP_FILE}" ; rm -rf "${MSU_LIB}".staging.*' EXIT


function check_dep() {
  command -v "${1}" > /dev/null 2>&1 || {
    printf '%s\n' "\`${1}' is NOT available. It is required for: ${2}" > /dev/stderr
    exit 1
  }
}


function check_deps() {
  check_dep "awk" "processing help information"
  check_dep "bash" "runtime"
  check_dep "cat" "file reading, stream concat"
  check_dep "command" "command lookup/execution"
  check_dep "cp" "file copying"
  check_dep "curl" "self-upgrade"
  check_dep "cut" "stream cutting"
  check_dep "dirname" "path manipulation"
  check_dep "git" "install, self-upgrade, module-install, metadata gen."
  check_dep "grep" "regexp matching"
  check_dep "id" "check user id"
  check_dep "ln" "symlink creation"
  check_dep "mkdir" "directory creation"
  check_dep "mv" "file renaming"
  check_dep "popd" "pop directory from stack"
  check_dep "printf" "line printing"
  check_dep "pushd" "push directory onto stack"
  check_dep "readlink" "handling symlinks"
  check_dep "rm" "file removal"
  check_dep "tar" "self-upgrade"
  check_dep "tput" "formatting styles"
  check_dep "tr" "character translation"
}


# COPIED verbatim from lib/core_utils.sh. Keep in sync!
function copy_dir_atomic() {
  local staging_dir="${2}.staging.$$"
  rm -rf "${staging_dir}"
  mkdir -p "$(dirname "${staging_dir}")"
  cp -r "${1}" "${staging_dir}"
  rm -rf "${2}"
  mv "${staging_dir}" "${2}"
}


function remove_bashrc_lines() {
  if [ ! -f "${BASHRC}" ] ; then
      return
  fi
  local removees="${1}"
  local tmp="${BASHRC_TMP_FILE}"
  local line
  local removee
  local keep
  while IFS='' read -r line || [ -n "${line}" ] ; do
    keep=1
    while IFS='' read -r removee || [ -n "${removee}" ] ; do
      if [ "${line}" = "${removee}" ] ; then
        keep=0
        break
      fi
    done <<EOF
${removees}
EOF
    if [ "${keep}" -eq 1 ] ; then
      printf '%s\n' "${line}"
    fi
  done < "${BASHRC}" > "${tmp}"
  mv "${tmp}" "${BASHRC}"
}


printf '%s\n' "${MARKER} checking if all dependencies are available"
check_deps


printf '%s\n' "${MARKER} checking if ${BIN} is in \${PATH}"
if [ -f "${BASHRC}" ] && grep -F -q "${EXPORT_BIN_PATH}" "${BASHRC}" ; then
  : # already added to ${BASHRC} by a previous run
elif grep "${BIN}" <<< "${PATH}" > /dev/null ; then
  : # already in \${PATH}
else
  printf '%s\n' "${MARKER} ${BIN} not in path. Adding it to ${BASHRC}. You need to restart your terminal for this to take effect!"
  {
    printf '%s\n' ""
    printf '%s\n' "# added by msu"
    printf '%s\n' "${EXPORT_BIN_PATH}"
  } >> "${BASHRC}"
fi


printf '%s\n' "${MARKER} loading metadata"
source lib/metadata.sh


printf '%s\n' "${MARKER} copying library"
[ "${MSU_EXE}" == "${MSU_LIB}" ] && {
  MSU_LIB="${MSU_LIB}-lib"
}
copy_dir_atomic lib "${MSU_LIB}"


printf '%s\n' "${MARKER} checking if ${MSU_MAN} is in \${MANPATH}"
if [ -f "${BASHRC}" ] && grep -F -q "${EXPORT_MAN_PATH}" "${BASHRC}" ; then
  : # already added to ${BASHRC} by a previous run
elif grep "${MSU_MAN}" <<< "${MANPATH:-}" > /dev/null ; then
  : # already in \${MANPATH}
else
  printf '%s\n' "${MARKER} ${MSU_MAN} not in manpath. Adding it to ${BASHRC}."
  printf '%s\n' "${MARKER} !! You need to restart your terminal for this to take effect!"
  {
    printf '%s\n' ""
    printf '%s\n' "# added by msu"
    printf '%s\n' "${EXPORT_MAN_PATH}"
  } >> "${BASHRC}"
fi


# there are cases where manpages are not generated yet
if [ -f dist/docs/man/man1/msu.1 ] && [ -f dist/docs/man/man3/msu.3 ]
then
  printf '%s\n' "${MARKER} copying manpages"
  mkdir -p "${MSU_MAN}/man1" "${MSU_MAN}/man3"
  cp -r dist/docs/man/man1/*.1 "${MSU_MAN}/man1" || true
  cp -r dist/docs/man/man3/*.3 "${MSU_MAN}/man3" || true
fi


# tarballs do NOT ship with the .git directory
# instead, the metadata is generated at release time
if [ -d .git ]
then
  printf '%s\n' "${MARKER} generating metadata"
  MSU_BUILD_HASH=$(git rev-parse HEAD)
  MSU_BUILD_DATE=$(git show -s --format=%ci "${MSU_BUILD_HASH}")
  {
    printf '%s\n' "MSU_BUILD_HASH='${MSU_BUILD_HASH}'"
    printf '%s\n' "MSU_BUILD_DATE='${MSU_BUILD_DATE}'"
  } >> "${MSU_LIB}"/metadata.sh
fi


printf '%s\n' "${MARKER} linking executable"
mkdir -p "$(dirname "${MSU_EXE}")"
rm -f "${MSU_EXE}"
ln -sf "${MSU_LIB}"/msu.sh "${MSU_EXE}"


if [ -n "${PREVIOUS_LOAD_STRING}" ] && [ "${PREVIOUS_LOAD_STRING}" != "${MSU_INSTALL_LOAD_STRING}" ] ; then
  printf '%s\n' "${MARKER} removing outdated loader string from ${BASHRC}"
  remove_bashrc_lines "${PREVIOUS_LOAD_STRING}"
fi


printf '%s\n' "${MARKER} make bash load msu into environment on start"
grep "${MSU_INSTALL_LOAD_STRING}" "${BASHRC}" > /dev/null || {
  {
    printf '%s\n' ""
    printf '%s\n' "${MSU_INSTALL_LOAD_STRING}"
  } >> "${BASHRC}"
}


printf '%s\n' "${MARKER} storing installation configuration"
{
  printf '%s\n' "MSU_INSTALL_LIB='${LIB}'"
  printf '%s\n' "MSU_INSTALL_BIN='${BIN}'"
  printf '%s\n' "MSU_INSTALL_MAN='${MAN}'"
  printf '%s\n' "MSU_INSTALL_LOAD_STRING='${MSU_INSTALL_LOAD_STRING}'"
} >> "${MSU_LIB}"/metadata.sh



printf '%s\n' "${MARKER} finished installing"
printf '%s\n' "${MARKER} !! Restart your terminal to load msu into environment"

printf '\n'
"${MSU_EXE}" version
printf '\n'
