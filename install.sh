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
  echo "${MARKER} loading existing metadata"
  # shellcheck disable=SC1090,SC1091
  source "${MSU_LIB}/metadata.sh"
  PREVIOUS_LOAD_STRING="${MSU_INSTALL_LOAD_STRING:-}"
fi


BASHRC="${BASHRC:-${HOME}/.bashrc}"
BIN="${BIN:-${HOME}/bin}"
MAN="${MAN:-${HOME}/share/man}"
MSU_EXE="${BIN}/msu"
MSU_MAN="${MAN}"


function check_dep() {
  command -v "${1}" > /dev/null 2>&1 || {
    echo "\`${1}' is NOT available. It is required for: ${2}" > /dev/stderr
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
  check_dep "echo" "line printing"
  check_dep "git" "install, self-upgrade, module-install, metadata gen."
  check_dep "grep" "regexp matching"
  check_dep "id" "check user id"
  check_dep "ln" "symlink creation"
  check_dep "mkdir" "directory creation"
  check_dep "mv" "file renaming"
  check_dep "popd" "pop directory from stack"
  check_dep "pushd" "push directory onto stack"
  check_dep "readlink" "handling symlinks"
  check_dep "rm" "file removal"
  check_dep "tar" "self-upgrade"
  check_dep "tput" "formatting styles"
  check_dep "tr" "character translation"
}


function remove_bashrc_lines() {
  if [ ! -f "${BASHRC}" ] ; then
      return
  fi
  local removees="${1}"
  local tmp="${BASHRC}.msu-migrate"
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


echo "${MARKER} checking if all dependencies are available"
check_deps


echo "${MARKER} checking if ${BIN} is in \${PATH}"
echo "${PATH}" | grep "${BIN}" > /dev/null || {
  echo "${MARKER} ${BIN} not in path. Adding it to ${BASHRC}. You need to restart your terminal for this to take effect!"
  {
    echo ""
    echo "# added by msu"
    echo "export PATH=\"${BIN}\":\${PATH}"
  } >> "${BASHRC}"
}


echo "${MARKER} loading metadata"
source lib/metadata.sh


echo "${MARKER} copying library"
[ "${MSU_EXE}" == "${MSU_LIB}" ] && {
  MSU_LIB="${MSU_LIB}-lib"
}
rm -rf "${MSU_LIB}"
mkdir -p "${MSU_LIB}"
cp -r lib/* "${MSU_LIB}"


echo "${MARKER} checking if ${MSU_MAN} is in \${MANPATH}"
echo "${MANPATH:-}" | grep "${MSU_MAN}" > /dev/null || {
  echo "${MARKER} ${MSU_MAN} not in manpath. Adding it to ${BASHRC}."
  echo "${MARKER} !! You need to restart your terminal for this to take effect!"
  {
    echo ""
    echo "# added by msu"
    echo "export MANPATH=\"${MSU_MAN}\":\${MANPATH}"
  } >> "${BASHRC}"
}


# there are cases where manpages are not generated yet
if [ -f dist/docs/man/man1/msu.1 ] && [ -f dist/docs/man/man3/msu.3 ]
then
  echo "${MARKER} copying manpages"
  mkdir -p "${MSU_MAN}/man1" "${MSU_MAN}/man3"
  cp -r dist/docs/man/man1/*.1 "${MSU_MAN}/man1" || true
  cp -r dist/docs/man/man3/*.3 "${MSU_MAN}/man3" || true
fi


# tarballs do NOT ship with the .git directory
# instead, the metadata is generated at release time
if [ -d .git ]
then
  echo "${MARKER} generating metadata"
  MSU_BUILD_HASH=$(git rev-parse HEAD)
  MSU_BUILD_DATE=$(git show -s --format=%ci "${MSU_BUILD_HASH}")
  {
    echo "MSU_BUILD_HASH='${MSU_BUILD_HASH}'"
    echo "MSU_BUILD_DATE='${MSU_BUILD_DATE}'"
  } >> "${MSU_LIB}"/metadata.sh
fi


echo "${MARKER} linking executable"
mkdir -p "$(dirname "${MSU_EXE}")"
rm -f "${MSU_EXE}"
ln -sf "${MSU_LIB}"/msu.sh "${MSU_EXE}"


if [ -n "${PREVIOUS_LOAD_STRING}" ] && [ "${PREVIOUS_LOAD_STRING}" != "${MSU_INSTALL_LOAD_STRING}" ] ; then
  echo "${MARKER} removing outdated loader string from ${BASHRC}"
  remove_bashrc_lines "${PREVIOUS_LOAD_STRING}"
fi


echo "${MARKER} make bash load msu into environment on start"
grep "${MSU_INSTALL_LOAD_STRING}" "${BASHRC}" > /dev/null || {
  {
    echo ""
    echo "${MSU_INSTALL_LOAD_STRING}"
  } >> "${BASHRC}"
}


echo "${MARKER} storing installation configuration"
{
  echo "MSU_INSTALL_LIB='${LIB}'"
  echo "MSU_INSTALL_BIN='${BIN}'"
  echo "MSU_INSTALL_MAN='${MAN}'"
  echo "MSU_INSTALL_LOAD_STRING='${MSU_INSTALL_LOAD_STRING}'"
} >> "${MSU_LIB}"/metadata.sh



echo "${MARKER} finished installing"
echo "${MARKER} !! Restart your terminal to load msu into environment"

echo
"${MSU_EXE}" version
echo
