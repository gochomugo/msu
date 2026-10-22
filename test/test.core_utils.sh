#!/usr/bin/env bats
# tests against ./lib/core_utils.sh


function setup() {
  BATS_TEST_TMPDIR="$(readlink -f "${BATS_TEST_TMPDIR}")"
  MSU_LIB="${PWD}"/lib
  MSU_EXTERNAL_LIB="${BATS_TEST_TMPDIR}/external-modules"
  source lib/core.sh
  source lib/core_utils.sh
}


function count_lines() {
  wc -l "${1}" | sed -e s/^\ *// | cut -d ' ' -f 1
}


# Extracts the body of the function ${2} (from its declaration line
# up to the closing brace) from the file ${1}.
function extract_function() {
  # index() is used instead of a regex, since escaping "(" in a regex
  # is not portable (e.g. bsd-awk errors on "\(")
  awk '
    $1 == "function" && index($2, name "(") == 1 { flag = 1 }
    flag { print }
    flag && $0 == "}" { exit }
  ' name="${2}" "${1}"
}


function mock_curl_for_upgrade() {
  local bin="${BATS_TEST_TMPDIR}/bin"
  PATH="${bin}:${PATH}"
  mkdir -p "${bin}"
  touch "${bin}/curl"
  chmod +x "${bin}/curl"
  echo "envsubst '\$TEST_TAG_NAME' < "${PWD}/test/data/upgrade.json" && touch "${BATS_TEST_TMPDIR}/curl_mocked"" > "${bin}/curl"
}


# Skips a test that requires network access, e.g. cloning modules
# from a remote repository. Set NO_NETWORK=1 to run in its absence.
function require_network() {
  if [ -n "${NO_NETWORK:-}" ] ; then
    skip "network usage disabled (NO_NETWORK is set)"
  fi
}


function test_is_module_installed() {
  local status="${1}"
  local output="${2}"
  local module_name="${3}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} ${module_name}" <<< "${output}"
  [ -d "${MSU_EXTERNAL_LIB}/${module_name}" ]
}


@test "\`copy_dir_atomic' copies a directory" {
  local src="${BATS_TEST_TMPDIR}/src"
  local dst="${BATS_TEST_TMPDIR}/dst"
  mkdir -p "${src}/nested"
  printf '%s\n' "content" > "${src}/file"
  printf '%s\n' "nested" > "${src}/nested/file"
  copy_dir_atomic "${src}" "${dst}"
  [ "$(cat "${dst}/file")" == "content" ]
  [ "$(cat "${dst}/nested/file")" == "nested" ]
  [ ! -d "${dst}.staging."* ]
}


@test "\`copy_dir_atomic' replaces the destination atomically" {
  local src="${BATS_TEST_TMPDIR}/src"
  local dst="${BATS_TEST_TMPDIR}/dst"
  mkdir -p "${src}" "${dst}"
  printf '%s\n' "old" > "${dst}/existing"
  printf '%s\n' "new" > "${src}/file"
  copy_dir_atomic "${src}" "${dst}"
  [ ! -e "${dst}/existing" ]
  [ "$(cat "${dst}/file")" == "new" ]
}


@test "\`copy_dir_atomic' in install.sh does NOT drift from the library" {
  local in_install
  local in_lib
  in_install=$(extract_function install.sh copy_dir_atomic)
  in_lib=$(extract_function lib/core_utils.sh copy_dir_atomic)
  [ "${in_install}" == "${in_lib}" ]
}


@test "\`for_each_line_in_file' runs a command for each line in the file" {
  local file="${BATS_TEST_TMPDIR}/file"
  echo -e "first\nsecond" > "${file}"
  [ "$(count_lines "${file}")" == 2 ]
  local -a calls=()
  function track() {
    calls+=("${1}")
  }
  for_each_line_in_file "${file}" track
  [ "${#calls[@]}" == 2 ]
  [ "${calls[0]}" == "first" ]
  [ "${calls[1]}" == "second" ]
}


@test "\`for_each_line_in_file' passes extra args to the command" {
  local file="${BATS_TEST_TMPDIR}/file"
  echo -e "first\nsecond" > "${file}"
  [ "$(count_lines "${file}")" == 2 ]
  local -a calls=()
  function track_with_extra() {
    calls+=("${1} ${2}")
  }
  for_each_line_in_file "${file}" track_with_extra --extra
  [ "${#calls[@]}" == 2 ]
  [ "${calls[0]}" == "--extra first" ]
  [ "${calls[1]}" == "--extra second" ]
}


@test "\`get_latest_version' returns the latest version of msu" {
  if [ -n "${CI}" ] ; then
    skip "GitHub API rate limiting causes this test case to fail often"
  fi
  get_latest_version | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'
}


@test "\`get_major_version' returns the major part of a semver version" {
  [[ "$(get_major_version 0.2.3)" == 0 ]]
  [[ "$(get_major_version 1.2.3)" == 1 ]]
  [[ "$(get_major_version 12.23.34)" == 12 ]]
}


@test "\`get_minor_version' returns the minor part of a semver version" {
  [[ "$(get_minor_version 1.0.3)" == 0 ]]
  [[ "$(get_minor_version 1.2.3)" == 2 ]]
  [[ "$(get_minor_version 12.23.34)" == 23 ]]
}


@test "\`get_patch_version' returns the major part of a semver version" {
  [[ "$(get_patch_version 1.2.0)" == 0 ]]
  [[ "$(get_patch_version 1.2.3)" == 3 ]]
  [[ "$(get_patch_version 12.23.34)" == 34 ]]
}


@test "\`has_command' checks if command is available" {
  has_command "cat"          # I can be almost certain that `cat` is available.
  ! has_command "dog"        # no dog person here?
}


@test "\`install' installs one or more modules" {
  local mod1="${BATS_TEST_TMPDIR}/mod1"
  local mod2="${BATS_TEST_TMPDIR}/mod2"
  local mod3="${BATS_TEST_TMPDIR}/parent/mod3"
  mkdir -p "${mod1}" "${mod2}" "${mod3}"
  run install "${mod1}" "${mod2}" "${mod3}"
  [ "${status}" -eq 0 ]
  local mods=("mod1" "mod2" "mod3")
  for mod in "${mods[@]}" ; do
    grep "${sym_tick} ${mod}" <<< "${output}"
    [ -d "${MSU_EXTERNAL_LIB}/${mod}" ]
  done
}


@test "\`install' fails if module exists" {
  local mod="${BATS_TEST_TMPDIR}/mod"
  mkdir -p "${mod}"

  # first install works
  run install "${mod}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod" <<< "${output}"

  # install again should fail
  run install "${mod}"
  [ "${status}" -eq 1 ]
  grep "module already installed: mod" <<< "${output}"

  # install can be forced
  run install --force "${mod}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod" <<< "${output}"

  # or use -f
  run install -f "${mod}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod" <<< "${output}"

  # --force after module name also works (options are parsed before modules)
  run install "${mod}" --force
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod" <<< "${output}"
}


@test "\`install' installs from github/gitlab/bitbucket" {
  require_network
  run install "BT:GochoMugo/msu-test"
  test_is_module_installed "${status}" "${output}" "msu-test"
  rm -rf "${MSU_EXTERNAL_LIB}"

  run install "bts:GochoMugo/msu-test"
  test_is_module_installed "${status}" "${output}" "msu-test"
  rm -rf "${MSU_EXTERNAL_LIB}"

  run install "gh:GochoMugo/msu"
  test_is_module_installed "${status}" "${output}" "msu"
  rm -rf "${MSU_EXTERNAL_LIB}"

  run install "GHS:GochoMugo/msu"
  test_is_module_installed "${status}" "${output}" "msu"
  rm -rf "${MSU_EXTERNAL_LIB}"

  run install "GL:GochoMugo/msu-test"
  test_is_module_installed "${status}" "${output}" "msu-test"
  rm -rf "${MSU_EXTERNAL_LIB}"

  run install "gls:GochoMugo/msu-test"
  test_is_module_installed "${status}" "${output}" "msu-test"
  rm -rf "${MSU_EXTERNAL_LIB}"
}


@test "\`install' errors on unknown remote mark" {
  run install "zz:user/repo"
  [ "${status}" -eq 1 ]
  grep "unknown remote mark: zz" <<< "${output}"
  [ ! -d "${MSU_EXTERNAL_LIB}/repo" ]
}


@test "\`install' returns 1 if any module failed to install" {
  run install "zz:user/repo" "zz:other/repo"
  [ "${status}" -eq 1 ]
  [ "$(grep -c "unknown remote mark: zz" <<< "${output}")" -eq 2 ]
}


@test "\`install' restores working directory after a failed clone" {
  local real_git
  real_git="$(command -v git)"
  local bin="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "${bin}"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if [ "${1}" = clone ] ; then' \
    '  exit 1' \
    'fi' \
    "exec \"${real_git}\" \"\${@}\"" > "${bin}/git"
  chmod +x "${bin}/git"
  PATH="${bin}:${PATH}"

  pushd "${BATS_TEST_TMPDIR}" > /dev/null
  mkdir -p mod-rel
  # the local module is referenced relative to the working directory
  run install "gh:nonexistent/repo" "mod-rel"
  popd > /dev/null
  [ "${status}" -eq 1 ]
  grep "${sym_cross} nonexistent/repo" <<< "${output}"
  grep "${sym_tick} mod-rel" <<< "${output}"
  [ -d "${MSU_EXTERNAL_LIB}/mod-rel" ]
}


@test "\`install' supports . as local path" {
  local mod="${BATS_TEST_TMPDIR}/mod"
  mkdir -p "${mod}"
  pushd "${mod}"
  run install "."
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod" <<< "${output}"
  [ -d "${MSU_EXTERNAL_LIB}/mod" ]
}


@test "\`install' supports versions (git tags)" {
  require_network
  local samplemodule="GL:GochoMugo/msu-test#v0.0.0"
  run install "GL:GochoMugo/msu-test#v0.0.0"
  test_is_module_installed "${status}" "${output}" "msu-test"
  pushd "${MSU_EXTERNAL_LIB}/msu-test"
  [ "$(git describe --tags)" == "v0.0.0" ]
}


@test "\`install_from_list' installs from a list in a file" {
  require_network
  local listpath="${BATS_TEST_TMPDIR}/list"
  echo "GH:GochoMugo/msu" > ${listpath}
  echo "GL:GochoMugo/msu-test" >> ${listpath}
  run install_from_list "${listpath}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} msu" <<< "${output}"
  grep "${sym_tick} msu-test" <<< "${output}"
  [ -d "${MSU_EXTERNAL_LIB}/msu" ]
  [ -d "${MSU_EXTERNAL_LIB}/msu-test" ]
}


@test "\`install_from_list' installs from multiple list files" {
  local mod1="${BATS_TEST_TMPDIR}/mod1"
  local mod2="${BATS_TEST_TMPDIR}/mod2"
  mkdir -p "${mod1}" "${mod2}"
  local list1="${BATS_TEST_TMPDIR}/list1"
  local list2="${BATS_TEST_TMPDIR}/list2"
  echo "${mod1}" > "${list1}"
  echo "${mod2}" > "${list2}"
  run install_from_list "${list1}" "${list2}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod1" <<< "${output}"
  grep "${sym_tick} mod2" <<< "${output}"
  [ -d "${MSU_EXTERNAL_LIB}/mod1" ]
  [ -d "${MSU_EXTERNAL_LIB}/mod2" ]
}


@test "\`install_from_list' shows error when no file path is provided" {
  run install_from_list
  [ "${status}" -eq 1 ]
  grep "no file path provided" <<< "${output}"
}


@test "\`install_from_list' supports -f/--force to force reinstall" {
  local mod="${BATS_TEST_TMPDIR}/mod"
  mkdir -p "${mod}"
  local listpath="${BATS_TEST_TMPDIR}/list"
  echo "${mod}" > "${listpath}"

  # first install works
  run install_from_list "${listpath}"
  [ "${status}" -eq 0 ]

  # install again should fail without force
  run install_from_list "${listpath}"
  [ "${status}" -eq 1 ]
  grep "module already installed: mod" <<< "${output}"

  # --force flag allows reinstall
  run install_from_list --force "${listpath}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod" <<< "${output}"

  # -f flag also allows reinstall
  run install_from_list -f "${listpath}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod" <<< "${output}"

  # --force after file path also works (options are parsed before modules)
  run install_from_list "${listpath}" --force
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod" <<< "${output}"
}


@test "\`install_from_list' supports -f/--force to force reinstall (git url)" {
  require_network
  local listpath="${BATS_TEST_TMPDIR}/list"
  echo "GL:GochoMugo/msu-test#v0.0.0" > "${listpath}"

  # first install works
  run install_from_list "${listpath}"
  [ "${status}" -eq 0 ]

  # install again should fail without force
  run install_from_list "${listpath}"
  [ "${status}" -eq 1 ]
  grep "module already installed: msu-test" <<< "${output}"

  # --force flag allows reinstall
  run install_from_list --force "${listpath}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} msu-test" <<< "${output}"

  # -f flag also allows reinstall
  run install_from_list -f "${listpath}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} msu-test" <<< "${output}"

  # --force after file path also works (options are parsed before modules)
  run install_from_list "${listpath}" --force
  [ "${status}" -eq 0 ]
  grep "${sym_tick} msu-test" <<< "${output}"
}


@test "\`is_semver_gt' compares 2 versions correctly" {
  [[ $(is_semver_gt 0.0.1 0.0.0) == 0 ]]
  [[ $(is_semver_gt 0.1.0 0.0.0) == 0 ]]
  [[ $(is_semver_gt 1.0.0 0.0.0) == 0 ]]
  [[ $(is_semver_gt 0.1.0 0.0.1) == 0 ]]
  [[ $(is_semver_gt 0.1.1 0.1.0) == 0 ]]
  [[ $(is_semver_gt 1.0.0 0.1.0) == 0 ]]
  [[ $(is_semver_gt 1.0.1 1.0.0) == 0 ]]
  [[ $(is_semver_gt 1.1.0 1.0.1) == 0 ]]
  [[ $(is_semver_gt 1.1.1 1.1.0) == 0 ]]

  [[ $(is_semver_gt 0.0.0 0.0.1) == 1 ]]
  [[ $(is_semver_gt 0.0.0 0.1.0) == 1 ]]
  [[ $(is_semver_gt 0.0.0 1.0.0) == 1 ]]
  [[ $(is_semver_gt 0.0.1 0.1.0) == 1 ]]
  [[ $(is_semver_gt 0.1.0 0.1.1) == 1 ]]
  [[ $(is_semver_gt 0.1.0 1.0.0) == 1 ]]
  [[ $(is_semver_gt 1.0.0 1.0.1) == 1 ]]
  [[ $(is_semver_gt 1.0.1 1.1.0) == 1 ]]
  [[ $(is_semver_gt 1.1.0 1.1.1) == 1 ]]
}


@test "\`is_superuser' checks if script is run as superuser" {
  local bin="${BATS_TEST_TMPDIR}/bin"
  PATH="${bin}:${PATH}"
  mkdir -p "${bin}"
  touch "${bin}/id"
  chmod +x "${bin}/id"

  # A normal user with id 1000.
  echo 'echo 1000' > "${bin}/id"
  ! is_superuser

  # Root user.
  echo 'echo 0' > "${bin}/id"
  is_superuser
}


@test "\`list_modules' lists installed modules" {
  # no modules
  run list_modules
  [ "${status}" -eq 0 ]
  [ "$(wc -l <<< "${output}")" -eq 1 ]

  # 1 module installed
  mkdir -p "${MSU_EXTERNAL_LIB}/mod1"
  run list_modules
  [ "${status}" -eq 0 ]
  grep "external modules" <<< "${output}"
  grep "mod1" <<< "${output}"
  [ "$(wc -l <<< "${output}")" -eq 2 ]

  # 2 modules installed
  mkdir -p "${MSU_EXTERNAL_LIB}/mod2"
  run list_modules
  [ "${status}" -eq 0 ]
  grep "mod1" <<< "${output}"
  grep "mod2" <<< "${output}"
  [ "$(wc -l <<< "${output}")" -eq 3 ]
}


@test "\`nuke' nukes msu entirely" {
  HOME="${BATS_TEST_TMPDIR}/msu"
  PATH="${HOME}/bin:${PATH}"
  source lib/metadata.sh
  ./install.sh
  [ -d "${HOME}/lib/msu" ]
  [ -e "${HOME}/bin/msu" ]
  [ -e "${HOME}/share/man/man1/msu.1" ]
  [ -e "${HOME}/share/man/man3/msu.3" ]
  grep "${MSU_INSTALL_LOAD_STRING}" "${HOME}/.bashrc"

  MSU_ASSUME_YES="yes" msu nuke
  [ ! -d "${HOME}/lib/msu" ]
  [ ! -e "${HOME}/bin/msu" ]
  [ ! -e "${HOME}/share/man/man1/msu.1" ]
  [ ! -e "${HOME}/share/man/man3/msu.3" ]
  ! grep "${MSU_INSTALL_LOAD_STRING}" "${HOME}/.bashrc"
}


@test "\`show_help' shows help for a module" {
  local sample_module="${MSU_EXTERNAL_LIB}/mod"
  mkdir -p "${sample_module}"
  {
    echo "# HELP: See the project README at https://example.com"
    echo "# HELP: Requires foobar >= 2.0 to be installed"
    echo
    echo "# DOC: does something useful"
    echo "alias foo='bar'"
    echo
    echo "# DOC: does something else"
    echo "alias baz='qux'"
    echo
    echo "# HELP: Set some option"
  } > "${sample_module}/aliases.sh"
  run show_help "mod"
  [ "${status}" -eq 0 ]
  local expected_output=$(cat << EOF

Aliases:

  foo          does something useful
  baz          does something else

More information:

  - See the project README at https://example.com
  - Requires foobar >= 2.0 to be installed
  - Set some option
EOF
  )
  [ "${output}" == "${expected_output}" ]
}


@test "\`show_help' supports multi-line HELP comments" {
  local sample_module="${MSU_EXTERNAL_LIB}/mod"
  mkdir -p "${sample_module}"
  {
    echo "# HELP: first line"
    echo "# second line"
  } > "${sample_module}/aliases.sh"
  run show_help "mod"
  [ "${status}" -eq 0 ]
  echo "${output}" | grep "first line second line"
  ! grep "Aliases:" <<< "${output}"
}


@test "\`show_help' supports multi-line DOC comments" {
  local sample_module="${MSU_EXTERNAL_LIB}/mod"
  mkdir -p "${sample_module}"
  {
    echo "# DOC: first line"
    echo "# second line"
    echo "alias foo='bar'"
  } > "${sample_module}/aliases.sh"
  run show_help "mod"
  [ "${status}" -eq 0 ]
  echo "${output}" | grep "foo" | grep "first line second line"
  ! grep "More information:" <<< "${output}"
}


@test "\`show_help' errors if module not specified" {
  run show_help
  [ "${status}" -eq 1 ]
  grep "module name not specified" <<< "${output}"
}


@test "\`show_help' errors if module aliases not found" {
  run show_help "unknown"
  [ "${status}" -eq 1 ]
  grep "module aliases not found: unknown" <<< "${output}"
}


@test "\`show_metadata' shows module metadata" {
  local sample_module="${MSU_EXTERNAL_LIB}/mod"
  mkdir -p "${sample_module}"
  {
    echo "author=john@example.com"
    echo "build=abc123"
    echo "date=2025-12-02"
  } > "${sample_module}/metadata.sh"
  run show_metadata "mod"
  [ "${status}" -eq 0 ]
  echo "${output}" | grep "author" | grep "john@example.com"
  echo "${output}" | grep "build" | grep "abc123"
  echo "${output}" | grep "date" | grep "2025-12-02"
}


@test "\`uninstall' uninstalls modules" {
  mkdir -p "${MSU_EXTERNAL_LIB}/mod1" "${MSU_EXTERNAL_LIB}/mod2"
  run uninstall mod1 mod2
  [ "${status}" -eq 0 ]
  local module_names=(mod1 mod2)
  for mod in "${module_names[@]}" ; do
    grep "${sym_tick} ${mod}" <<< "${output}"
    [ ! -d "${MSU_EXTERNAL_LIB}/${mod}" ]
  done

  # uninstall errors if module not installed (without --force)
  run uninstall mod1
  [ "${status}" -eq 1 ]
  grep "module not installed: mod1" <<< "${output}"

  # uninstall with --force silently ticks if module not installed
  run uninstall --force mod1
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod1 (not installed)" <<< "${output}"

  # uninstall with -f also works
  run uninstall -f mod1
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod1 (not installed)" <<< "${output}"

  # --force after a non-existent module name also works (options are parsed before modules)
  run uninstall mod1 --force
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod1 (not installed)" <<< "${output}"
}


@test "\`uninstall_from_list' uninstalls from a list in a file" {
  local listpath="${BATS_TEST_TMPDIR}/list"
  mkdir -p "${MSU_EXTERNAL_LIB}/mod1"
  mkdir -p "${MSU_EXTERNAL_LIB}/mod2"
  echo "mod1" > "${listpath}"
  echo "mod2" >> "${listpath}"
  run uninstall_from_list "${listpath}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod1" <<< "${output}"
  grep "${sym_tick} mod2" <<< "${output}"
  [ ! -d "${MSU_EXTERNAL_LIB}/mod1" ]
  [ ! -d "${MSU_EXTERNAL_LIB}/mod2" ]
}


@test "\`uninstall_from_list' uninstalls from multiple list files" {
  local list1="${BATS_TEST_TMPDIR}/list1"
  local list2="${BATS_TEST_TMPDIR}/list2"
  mkdir -p "${MSU_EXTERNAL_LIB}/mod1" "${MSU_EXTERNAL_LIB}/mod2"
  echo "mod1" > "${list1}"
  echo "mod2" > "${list2}"
  run uninstall_from_list "${list1}" "${list2}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod1" <<< "${output}"
  grep "${sym_tick} mod2" <<< "${output}"
  [ ! -d "${MSU_EXTERNAL_LIB}/mod1" ]
  [ ! -d "${MSU_EXTERNAL_LIB}/mod2" ]
}


@test "\`uninstall_from_list' shows error when no file path is provided" {
  run uninstall_from_list
  [ "${status}" -eq 1 ]
  grep "no file path provided" <<< "${output}"
}


@test "\`uninstall_from_list' accepts -f/--force flag" {
  local listpath="${BATS_TEST_TMPDIR}/list"
  mkdir -p "${MSU_EXTERNAL_LIB}/mod1"
  echo "mod1" > "${listpath}"

  run uninstall_from_list --force "${listpath}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod1" <<< "${output}"
  [ ! -d "${MSU_EXTERNAL_LIB}/mod1" ]

  # without --force, uninstalling a missing module errors
  run uninstall_from_list "${listpath}"
  [ "${status}" -eq 1 ]
  grep "module not installed: mod1" <<< "${output}"

  # -f also works; missing module is silently ticked
  run uninstall_from_list -f "${listpath}"
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod1 (not installed)" <<< "${output}"

  # --force after file path also works (options are parsed before modules)
  run uninstall_from_list "${listpath}" --force
  [ "${status}" -eq 0 ]
  grep "${sym_tick} mod1 (not installed)" <<< "${output}"
}


@test "\`update_check' checks for updates" {
  mock_curl_for_upgrade
  local timestamp="$(date '+%Y.%m.%d')"
  rm -f "/tmp/.msu-can-upgrade."*

  # First run runs curl and does not log any output.
  TEST_TAG_NAME="999.0.0" run update_check
  [ "${status}" -eq 0 ]
  ! grep "new msu version" <<< "${output}"
  [ -f "${BATS_TEST_TMPDIR}/curl_mocked" ]
  [ -f "/tmp/.msu-can-upgrade.${timestamp}" ]
  ! [ -f "/tmp/.msu-can-upgrade.${timestamp}.done" ]
  rm "${BATS_TEST_TMPDIR}/curl_mocked"

  # Second run does not run curl but logs notice.
  TEST_TAG_NAME="999.0.0" run update_check
  [ "${status}" -eq 0 ]
  grep "new msu version (999.0.0)" <<< "${output}"
  [ -f "/tmp/.msu-can-upgrade.${timestamp}.done" ]
  ! [ -f "${BATS_TEST_TMPDIR}/curl_mocked" ]

  # Third run does not run curl nor log any output.
  TEST_TAG_NAME="999.0.0" run update_check
  [ "${status}" -eq 0 ]
  ! grep "new msu version" <<< "${output}"
  ! [ -f "${BATS_TEST_TMPDIR}/curl_mocked" ]

  # Cleans up after itself.
  rm -f "/tmp/.msu-can-upgrade."*
  touch "/tmp/.msu-can-upgrade.2025-12-18"
  touch "/tmp/.msu-can-upgrade.2025-12-18.done"
  TEST_TAG_NAME="999.0.0" run update_check
  ! [ -f "/tmp/.msu-can-upgrade.2025-12-18" ]
  ! [ -f "/tmp/.msu-can-upgrade.2025-12-18.done" ]
}


@test "\`upgrade' upgrades to latest version" {
  skip "Upgrading is untested for now"
}


@test "\`where' prints installation path of module" {
  # installed module
  mkdir -p "${MSU_EXTERNAL_LIB}/mod"
  run where mod
  [ "${status}" -eq 0 ]
  grep "${MSU_EXTERNAL_LIB}/mod" <<< "${output}"

  # missing module
  mkdir -p "${MSU_EXTERNAL_LIB}/mod"
  run where unknown
  [ "${status}" -eq 1 ]
  grep "module not found: unknown" <<< "${output}"

  # module not specified
  mkdir -p "${MSU_EXTERNAL_LIB}/mod"
  run where
  [ "${status}" -eq 1 ]
  grep "module name not specified" <<< "${output}"
}
