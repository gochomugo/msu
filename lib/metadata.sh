#!/usr/bin/env bash
# project metadata
#
# Copyright (c) 2015 GochoMugo <mugo@forfuture.co.ke>


# shellcheck disable=SC2034
{
  MSU_AUTHOR_NAME="GochoMugo"
  MSU_AUTHOR_EMAIL="mugo@forfuture.co.ke"
  # shellcheck disable=SC2016
  MSU_INSTALL_LOAD_STRING='# loading msu
[ "$(command -v msu)" ] && . msu env'
  MSU_VERSION="0.8.2"
}
