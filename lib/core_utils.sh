#!/usr/bin/env bash
# useful utilities
#
# Copyright (c) 2015 GochoMugo <mugo@forfuture.co.ke>

# shellcheck disable=2181


# modules
msu_require "console"
msu_require "format"
msu_require "metadata"


# module variables
{
  # shellcheck disable=2034
  DEPS="git"
}


# Copies a directory to a destination path, atomically. The copy is
# performed into a staging directory, then swapped into place via
# rename, so that a failure mid-copy leaves the destination as-is.
#
# ${1} - source directory
# ${2} - destination path (replaced atomically)
function copy_dir_atomic() {
  local staging_dir="${2}.staging.$$"
  rm -rf "${staging_dir}"
  mkdir -p "$(dirname "${staging_dir}")"
  cp -r "${1}" "${staging_dir}"
  rm -rf "${2}"
  mv "${staging_dir}" "${2}"
}


# Executes a command for each line in the specified file.
# ${1}    - path to file
# ${2}    - function to call for each line
# ${@:3}  - extra args to pass to the function before the line (optional)
function for_each_line_in_file() {
  local file="${1}"
  local func="${2}"
  local -a extra_args=("${@:3}")
  if [ ! -f "${file}" ] ; then
    error "file does NOT exist"
    return 1
  fi
  while read -r line ; do
    "${func}" "${extra_args[@]}" "${line}"
  done < "${file}"
}


# Returns the version of the latest release.
function get_latest_version() {
  curl --silent https://api.github.com/repos/GochoMugo/msu/releases/latest |\
      grep tag_name |\
      grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'
}


# Returns the major part of a semver version.
# ${1} - semver version
function get_major_version() {
  grep -Eo '^[0-9]+' <<< "${1}"
}


# Returns the minor part of a semver version.
# ${1} - semver version
function get_minor_version() {
  grep -Eo '\.[0-9]+\.' <<< "${1}" | sed -e s/\\.//g
}


# Returns the patch version of a semver version.
# ${1} - semver version
function get_patch_version() {
  grep -Eo '[0-9]+$' <<< "${1}"
}


# checking if command is available on the system.
# ${1} - command to check for.
function has_command() {
  command -v "${1}" > /dev/null 2>&1
}


# Installs modules.
# ${*} - module names
function install() {
  local do_force=
  local -a modules=()

  for opt in "${@}" ; do
    case "${opt}" in
        "-f" | "--force" )
          do_force=1
          ;;
        * )
          modules+=("${opt}")
          ;;
    esac
  done

  mkdir -p "${MSU_EXTERNAL_LIB}"
  local failed
  local tmpdir=''
  for dir in "${modules[@]}" ; do
    local module_name
    local remote_mark

    remote_mark=$(printf '%s\n' "${dir}" | grep -Eo "[a-zA-Z0-9]+:" | grep -Eo "[^:]*" || true)
    if [ "${remote_mark}" ] ; then
      # requires cloning
      local shorthand
      local version
      local url
      remote_mark=$(printf '%s\n' "${remote_mark}" | tr '[:upper:]' '[:lower:]')
      shorthand="${dir##*:}"
      version="${shorthand##*#}"
      if [ "${version}" == "${shorthand}" ] ; then
        version=""
      fi
      shorthand="${shorthand%%#*}"
      case "${remote_mark}" in
        "gh" )
          url="https://github.com/${shorthand}.git"
        ;;
        "ghs" )
          url="git@github.com:${shorthand}.git"
        ;;
        "bt" )
          url="https://bitbucket.org/${shorthand}.git"
        ;;
        "bts" )
          url="git@bitbucket.org:${shorthand}.git"
        ;;
        "gl" )
          url="https://gitlab.com/${shorthand}.git"
        ;;
        "gls" )
          url="git@gitlab.com:${shorthand}.git"
        ;;
      esac
      if [ -z "${url:-}" ] ; then
        error "unknown remote mark: ${remote_mark}"
        cross "${shorthand}"
        failed=1
        continue
      fi
      if ! tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/msu-clone.XXXXXX")" ; then
        error "could not create temporary directory"
        cross "${shorthand}"
        failed=1
        continue
      fi
      if ! git clone --branch="${version:-master}" --depth=1 --quiet "${url}" "${tmpdir}/${shorthand##*/}" ; then
        error "could not clone module: ${shorthand}"
        cross "${shorthand}"
        failed=1
        rm -rf "${tmpdir}"
        tmpdir=''
        continue
      fi
      dir="${tmpdir}/${shorthand##*/}"
    fi

    dir="$(readlink -f "${dir}")"
    module_name="$(basename "${dir}")"
    if [ -e "${MSU_EXTERNAL_LIB}/${module_name}" ] ; then
      if [ -z "${do_force}" ] ; then
        error "module already installed: ${module_name}"
        return 1
      else
        rm -rf "${MSU_EXTERNAL_LIB:?}/${module_name}"
      fi
    fi
    copy_dir_atomic "${dir}" "${MSU_EXTERNAL_LIB}/${module_name}"
    tick "${module_name}"
    if [ -n "${tmpdir:-}" ] ; then
      rm -rf "${tmpdir}"
      tmpdir=''
    fi
  done
  if [ -n "${failed:-}" ] ; then
    return 1
  fi
}


# install many
# ${*} - optional -f/--force flag followed by one or more file paths
function install_from_list() {
  process_install_list install "${@}"
}


# Returns 0 if the first version is greater than the
# second version. Otherwise returns 1.
# ${1} - first version
# ${2} - second version
function is_semver_gt() {
  local version1
  local version2
  version1="${1}"
  version2="${2}"

  local version1_major
  local version2_major
  version1_major=$(get_major_version "${version1}")
  version2_major=$(get_major_version "${version2}")

  if [ "${version1_major}" -gt "${version2_major}" ] ; then
    printf '%s\n' 0
    return 0
  elif [ "${version1_major}" -lt "${version2_major}" ] ; then
    printf '%s\n' 1
    return 1
  fi

  local version1_minor
  local version2_minor
  version1_minor=$(get_minor_version "${version1}")
  version2_minor=$(get_minor_version "${version2}")

  if [ "${version1_minor}" -gt "${version2_minor}" ] ; then
    printf '%s\n' 0
    return 0
  elif [ "${version1_minor}" -lt "${version2_minor}" ] ; then
    printf '%s\n' 1
    return 1
  fi

  local version1_patch
  local version2_patch
  version1_patch=$(get_patch_version "${version1}")
  version2_patch=$(get_patch_version "${version2}")

  if [ "${version1_patch}" -gt "${version2_patch}" ] ; then
    printf '%s\n' 0
    return 0
  fi

  printf '%s\n' 1
  return 1
}


# checking if script is run as root/superuser.
function is_superuser() {
  [ "$(id -u)" = "0" ]
}


# listing installed modules.
function list_modules() {
  local is_header_printed=
  if [ ! -d "${MSU_EXTERNAL_LIB}" ] ; then
    return
  fi
  for mod in "${MSU_EXTERNAL_LIB}"/* ; do
    if [ ! -d "${mod}" ] ; then
      continue
    fi
    if [ -z "${is_header_printed}" ] ; then
      # shellcheck source=lib/format.sh
      printf '%b\n' "${clr_white:?}external modules${clr_reset:?}"
      is_header_printed=1
    fi
    printf '%b\n' "\\t$(basename "${mod}")"
  done
}


# nuke msu entirely
function nuke() {
  # just ask to ensure we really want to nuke
  log "you are about to remove the msu executable, internal and external libraries"
  log "this action will change your ~/.bashrc! You may want to back it up in case shit happens!"
  yes_no "I want to nuke msu" || return 1

  local nuke_script="/tmp/nuke_msu.${RANDOM}"
  local pattern_file="/tmp/nuke_msu.pattern.${RANDOM}"
  printf '%s\n' "${MSU_INSTALL_LOAD_STRING}" > "${pattern_file}"
  {
    printf '%s\n' "trap 'rm -f \"${nuke_script}\" \"${pattern_file}\"' EXIT"
    printf '%s\n' "printf '%s\n' '- removing load string from ~/.bashrc'"
    printf '%s\n' "cp ~/.bashrc /tmp/bashrc.msu"
    printf '%s\n' "grep -v -F -x -f '${pattern_file}' /tmp/bashrc.msu > ~/.bashrc"
    printf '%s\n' "rm -f '${pattern_file}' /tmp/bashrc.msu"
    printf '%s\n' "printf '%s\n' '- removing external modules'"
    printf '%s\n' "rm -rf '${MSU_EXTERNAL_LIB}'"
    printf '%s\n' "printf '%s\n' '- removing core'"
    printf '%s\n' "rm -rf '${MSU_LIB}'"
    printf '%s\n' "printf '%s\n' '- removing manpages'"
    printf '%s\n' "rm -rf ${MSU_INSTALL_MAN}/man1/msu*"
    printf '%s\n' "rm -rf ${MSU_INSTALL_MAN}/man3/msu*"
    printf '%s\n' "printf '%s\n' '- removing executable'"
    printf '%s\n' "rm -f '${MSU_EXE}'"
    printf '%s\n' "printf '%s\n' '!! Just nuked msu !!'"
  } > "${nuke_script}"
  # running the nuke script
  bash "${nuke_script}"
}


# Process a list of files, calling a function for each line.
# ${1}    - function name (e.g. install or uninstall)
# ${@:2}  - optional -f/--force flag followed by one or more file paths
function process_install_list() {
  local func="${1}"
  local force_flag=
  local -a listfiles=()

  shift
  for opt in "${@}" ; do
    case "${opt}" in
      "-f" | "--force" )
        force_flag="--force"
        ;;
      * )
        listfiles+=("${opt}")
        ;;
    esac
  done
  if [ "${#listfiles[@]}" -eq 0 ] ; then
    error "no file path provided"
    return 1
  fi

  for listfile in "${listfiles[@]}" ; do
    # shellcheck disable=2086
    # ${force_flag} is intentionally unquoted so that it expands to nothing when empty
    for_each_line_in_file "${listfile}" "${func}" ${force_flag}
  done
}


# Computes the sha256 checksum of a file, printed to stdout.
#
# ${1} - path to file
function sha256_file() {
  if has_command sha256sum ; then
    sha256sum "${1}" | awk '{print $1}'
  elif has_command shasum ; then
    shasum -a 256 "${1}" | awk '{print $1}'
  else
    error "no sha256 tool found (sha256sum or shasum)"
    return 1
  fi
}


# show help for an installed module using DOC comments in its aliases.sh
# ${1} - module name
function show_help() {
  if [ -z "${1}" ] ; then
    error "module name not specified"
    return 1
  fi
  local aliases_file
  aliases_file="${MSU_EXTERNAL_LIB}/${1}/aliases.sh"
  if [ ! -f "${aliases_file}" ] ; then
    error "module aliases not found: ${1}"
    return 1
  fi
  awk '
      /^# DOC: / {
          doc = substr($0, 8);
          next
      }
      /^# HELP: / {
          if (help != "") help_lines[++help_count] = help;
          help = substr($0, 9);
          next
      }
      /^# / {
          if (doc != "") doc = doc " " substr($0, 3)
          else if (help != "") help = help " " substr($0, 3)
          next
      }
      /^alias / {
          if (doc != "") {
              if (!aliases_header_printed) {
                  print ""
                  print "Aliases:"
                  print ""
                  aliases_header_printed = 1
              }
              name = $2
              sub(/=.*$/, "", name)
              printf "  %-12s %s\n", name, doc
          }
          if (help != "") {
              help_lines[++help_count] = help;
              help = ""
          }
          doc = ""
          next
      }
      {
          doc = ""
          if (help != "") {
              help_lines[++help_count] = help;
              help = ""
          }
      }
      END {
          if (help != "") help_lines[++help_count] = help
          if (help_count > 0) {
              print ""
              print "More information:"
              print ""
              for (i = 1; i <= help_count; i++) {
                  printf "  - %s\n", help_lines[i]
              }
          }
      }
  ' "${aliases_file}"
}


# show metadata for an installed module
function show_metadata() {
  local metadata_file
  metadata_file="${MSU_EXTERNAL_LIB}/${1}/metadata.sh"
  if [ ! -f "${metadata_file}" ] ; then
    error "module metadata not found: ${1}"
    return 1
  fi
  # shellcheck disable=SC1090
  source "${metadata_file}"
  printf '%b\n' " ${clr_white}${1}${clr_reset}"
  printf '%b\n' "    author\\t${clr_white}${author:?}${clr_reset}"
  printf '%b\n' "    build\\t${clr_white}${build:?}${clr_reset}"
  printf '%b\n' "    date\\t${clr_white}${date:?}${clr_reset}"
}


# uninstall module(s)
function uninstall() {
  local do_force=
  local -a modules=()

  for opt in "${@}" ; do
    case "${opt}" in
      "-f" | "--force" )
        do_force=1
        ;;
      * )
        modules+=("${opt}")
        ;;
    esac
  done

  local path
  for dir in "${modules[@]}" ; do
    path="${MSU_EXTERNAL_LIB}/${dir}"
    if [ -e "${path}" ] ; then
      rm -rf "${path}" > /dev/null
      tick "${dir}"
    elif [ -n "${do_force}" ] ; then
      tick "${dir} (not installed)"
    else
      error "module not installed: ${dir}"
      return 1
    fi
  done
}


# uninstall many
# ${*} - optional -f/--force flag followed by one or more file paths
function uninstall_from_list() {
  process_install_list uninstall "${@}"
}


function update_check() {
  local check_file_prefix="/tmp/.msu-can-upgrade."
  local check_file
  local done_file
  check_file="${check_file_prefix}$(date '+%Y.%m.%d')"
  done_file="${check_file}.done"

  if [ -f "${done_file}" ] ; then
    return 0
  elif [ -f "${check_file}" ] ; then
    local version
    version="$(cat "${check_file}")"

    if is_semver_gt "${version}" "${MSU_VERSION}" > /dev/null ; then
      write_text "notice" "A new msu version (${version}) is available!" 0 /dev/stderr
      write_text "notice" "You can upgrade using \`msu upgrade'." 0 /dev/stderr
    fi

    touch "${done_file}"
    return 0
  fi

  rm -f "${check_file_prefix}"*
  get_latest_version > "${check_file}" &
}


# upgrade myself
function upgrade() {
  log "upgrading myself"
  local version
  version="${1}"

  local lock_dir="${TMPDIR:-/tmp}/.msu.upgrade.lock"
  if ! mkdir "${lock_dir}" 2> /dev/null ; then
    error "another upgrade appears to be in progress; if certain there is none, remove the directory ${lock_dir}"
    return 3
  fi

  LIB=${MSU_INSTALL_LIB:-$(dirname "${MSU_LIB}")}
  BIN=${MSU_INSTALL_BIN:-$(readlink -f "$(dirname "$(command -v msu)")")}
  MAN=${MSU_INSTALL_MAN}

  if [ ! "${MAN}" ] ; then
    for path in ${MANPATH//\:/\n} ; do
      if [ -f "${path}/man1/msu.1" ] ; then
        MAN=${path}
        break
      fi
    done
  fi

  [ ! "${version}" ] && {
    version=$(get_latest_version)
    if [ ! "${version}" ] ; then
      error "network request error"
      return 3
    fi

    if ! is_semver_gt "${version}" "${MSU_VERSION}" > /dev/null ; then
      log "you have the latest version"
      return
    fi
  }

  local tmp_dir="${TMPDIR:-/tmp}/.msu.upgrade.$$"
  # shellcheck disable=SC2064
  trap "rm -rf \"${tmp_dir}\" \"${lock_dir}\"" EXIT
  mkdir -p "${tmp_dir}" || return 1
  pushd "${tmp_dir}" > /dev/null || return 1

  curl --silent --fail --location "https://github.com/GochoMugo/msu/releases/download/${version}/msu-${version}.tar.gz" --output "msu-${version}.tar.gz" || {
    error "network request error"
    return 3
  }
  curl --silent --fail --location "https://github.com/GochoMugo/msu/releases/download/${version}/msu-${version}.tar.gz.sha256" --output "msu-${version}.tar.gz.sha256" || {
    error "checksum file could not be downloaded"
    return 3
  }
  verify_checksum "msu-${version}.tar.gz" "msu-${version}.tar.gz.sha256" || return 3
  tar xvf "msu-${version}.tar.gz" > /dev/null 2>&1
  pushd "msu-${version}" > /dev/null || {
    error "could not change into directory with extracted contents"
    return 1
  }
  LIB="${LIB}" BIN="${BIN}" MAN="${MAN}" ./install.sh
  popd > /dev/null || return 1
}


# Verifies that a file matches the checksum recorded in a checksum
# file, as generated by `sha256sum` (e.g. release tarballs).
#
# ${1} - path to the file
# ${2} - path to the checksum file
function verify_checksum() {
  local expected
  local actual
  if [ ! -f "${2}" ] ; then
    error "checksum file not found: ${2}"
    return 1
  fi
  expected="$(awk '{print $1}' "${2}")"
  if [ ! "${expected}" ] ; then
    error "checksum file is empty: ${2}"
    return 1
  fi
  if ! actual="$(sha256_file "${1}")" ; then
    return 1
  fi
  if [ "${actual}" != "${expected}" ] ; then
    error "checksum mismatch: ${1}"
    return 1
  fi
}


function where() {
  if [ -z "${1}" ] ; then
    error "module name not specified"
    return 1
  fi
  local module_dir
  module_dir="${MSU_EXTERNAL_LIB}/${1}"
  if [ ! -d "${module_dir}" ] ; then
    error "module not found: ${1}"
    return 1
  fi
  printf '%s\n' "${module_dir}"
  return
}
