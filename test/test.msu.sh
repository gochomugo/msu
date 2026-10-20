#!/usr/bin/env bats
# tests against lib/msu.sh


setup() {
  BATS_TEST_TMPDIR="$(readlink -f "${BATS_TEST_TMPDIR}")"
  PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
  HOME="${BATS_TEST_TMPDIR}" ./install.sh
}


@test "load string uses '. msu env'" {
  grep ". msu env" "${BATS_TEST_TMPDIR}/.bashrc"
}


@test "command '. msu env' loads aliases into the current environment" {
  . msu env
  alias msu.reload
}


@test "command '. msu env' leaves a clean environment" {
  . msu env
  # Added by msu.sh
  [ ! "${MSU_EXE}" ]
  [ ! "${MSU_REAL_EXE}" ]
  [ ! "${MSU_LIB}" ]
  # Added by metadata.sh
  [ ! "${MSU_AUTHOR_NAME}" ]
  [ ! "${MSU_AUTHOR_EMAIL}" ]
  [ ! "${MSU_VERSION}" ]
  [ ! "${MSU_BUILD_HASH}" ]
  [ ! "${MSU_BUILD_DATE}" ]
  [ ! "${MSU_INSTALL_LIB}" ]
  [ ! "${MSU_INSTALL_BIN}" ]
  [ ! "${MSU_INSTALL_MAN}" ]
  [ ! "${MSU_INSTALL_LOAD_STRING}" ]
  # Added by core.sh
  [ ! "${MSU_REQUIRE_LOCK}" ]
  [ ! "$(type -t msu__check_deps)" ]
  [ ! "$(type -t msu__load)" ]
  [ ! "$(type -t msu_require)" ]
  [ ! "$(type -t msu_run)" ]
  [ ! "$(type -t msu_execute)" ]
}


@test "command '. msu env' does NOT set strict mode options" {
  local script
  script=$(cat <<EOF
. msu env
if set -o | grep -E "^(errexit|nounset|pipefail)" | grep -vq "off" ; then
  exit 1
fi
exit 0
EOF
  )
  bash -c "${script}"
}


@test "msu executed directly sets strict mode options" {
  local script="${BATS_TEST_TMPDIR}/strict-check.sh"
  printf '%s\n' 'if set -o | grep -E "^(errexit|nounset|pipefail)" | grep -vq "on" ; then exit 1 ; fi' > "${script}"
  cat >> "${script}" <<'EOF'
if [ "${BASH_VERSINFO[0]}" -gt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 4 ] ; } ; then
  shopt -q inherit_errexit || exit 1
fi
if [ "${BASH_VERSINFO[0]}" -gt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 2 ] ; } ; then
  shopt -q lastpipe || exit 1
fi
exit 0
EOF
  run msu execute "${script}"
  [ "${status}" -eq 0 ]
}


@test "msu respects MSU_STRICT_MODE=0 when executed directly" {
  local script="${BATS_TEST_TMPDIR}/strict-check.sh"
  printf '%s\n' 'if set -o | grep -E "^(errexit|nounset|pipefail)" | grep -vq "off" ; then exit 1 ; fi' > "${script}"
  cat >> "${script}" <<'EOF'
if [ "${BASH_VERSINFO[0]}" -gt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 4 ] ; } ; then
  shopt -q inherit_errexit && exit 1
fi
if [ "${BASH_VERSINFO[0]}" -gt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 2 ] ; } ; then
  shopt -q lastpipe && exit 1
fi
exit 0
EOF
  run env MSU_STRICT_MODE=0 msu execute "${script}"
  [ "${status}" -eq 0 ]
}


@test "msu respects MSU_DEBUG=1 when executed directly" {
  local script="${BATS_TEST_TMPDIR}/debug-check.sh"
  printf '%s\n' 'if set -o | grep "^xtrace" | grep -vq "on" ; then exit 1 ; fi' > "${script}"
  run env MSU_DEBUG=1 msu execute "${script}"
  [ "${status}" -eq 0 ]
}


@test "msu does NOT set xtrace by default" {
  local script="${BATS_TEST_TMPDIR}/debug-check.sh"
  printf '%s\n' 'if set -o | grep "^xtrace" | grep -vq "off" ; then exit 1 ; fi' > "${script}"
  run msu execute "${script}"
  [ "${status}" -eq 0 ]
}


@test "msu used in a shebang sets strict mode options" {
  local script="${BATS_TEST_TMPDIR}/shebang-check.sh"
  # use /usr/bin/env, since macos refuses a script as the shebang
  # interpreter when referenced by absolute path
  {
    printf '#!/usr/bin/env msu\n'
    printf '%s\n' 'if set -o | grep -E "^(errexit|nounset|pipefail)" | grep -vq "on" ; then exit 1 ; fi'
  } > "${script}"
  chmod +x "${script}"
  run "${script}"
  [ "${status}" -eq 0 ]
}


@test "command 'msu require' loads a module" {
  [ "$(type -t success)" != "function" ]
  . msu require console
  [ "$(type -t success)" == "function" ]
}


@test "command 'msu upgrade' upgrades msu" {
  skip "Upgrading is untested for now"
}


@test "command 'msu run' runs a module function" {
  run msu run console.log ian
  [ "${status}" -eq 0 ]
  echo "${output}" | grep "ian"
}


@test "command 'msu help' shows help information" {
  run msu help
  [ "${status}" -eq 0 ]
  echo "${output}" | grep "help information"
}


@test "command 'msu version' shows version information" {
  run msu version
  [ "${status}" -eq 0 ]
  echo "${output}" | grep "version"
  echo "${output}" | grep "build"
  echo "${output}" | grep "date"
}


@test "command 'msu' does not error if run without arguments" {
  run msu
  [ "${status}" -eq 0 ]
}


@test "program 'msu' can be used in a shebang" {
  bang_sh="${BATS_TEST_TMPDIR}/bang.sh"
  {
    echo "#!/usr/bin/env msu"
    echo "msu_require 'console'"
    echo "log 'LOGGED'"
  } > "${bang_sh}"
  chmod +x "${bang_sh}"
  run ${bang_sh}
  [ "${status}" -eq 0 ]
  echo "${output}" | grep "LOGGED"
}
