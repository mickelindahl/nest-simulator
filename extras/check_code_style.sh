#!/bin/bash

# check_code_style.sh
#
# This file is part of NEST.
#
# Copyright (C) 2004 The NEST Initiative
#
# NEST is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# NEST is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with NEST.  If not, see <http://www.gnu.org/licenses/>.

# This script performs a static code analysis and can be used to verify 
# if a source file fulfills the NEST coding style guidelines.
# Run ./extras/check_code_style.sh --help for more detailed information.

# Set default parameters.
unset FILE_TO_BE_CHECKED
GIT_START_SHA=master             # If 'file=' is not specified all changed files in that commit range are processed.
GIT_END_SHA=HEAD

VERA=vera++                      # The names of the static code analysis tools executables.
PEP8=pep8
CPPCHECK=cppcheck                # CPPCHECK version 1.69 or later is required !
CLANG_FORMAT=clang-format-3.6    # CLANG-FORMAT version 3.6 and only this version is needed !

INCREMENTAL=false                # Prompt the user before each file analysis.


# Exit script on 'Unknown option' condition.
# error_unknown_option "option"
error_unknown_option() {
  echo "[ERROR] Unknown option: $1"
  print_usage
  exit 1
}

# Exit script on error.
# error_exit "error_message"
error_exit() {
  echo "[ERROR] $1"
  exit 1
}

# Print usage and exit script.
usage() {
  print_usage
  exit 0
}

print_usage() {
    cat <<EOF
Usage: ./extras/check_code_style.sh [options ...]

This script processes C/C++ and Python source code files to verify compliance with the NEST
coding  style  guidelines.  The  checks are performed the same way as in the NEST Travis CI
build and test environment. If no file is specified, a local 'git diff' is issued to obtain 
the changed files in the commit range '<git-sha-start>..<git-sha-end>'. By default, this is 
'master..head'.

The script expects to be run from the base directory of the NEST sources,
i.e. all executions should start like:
    ./extras/check_code_style.sh ...

The setup of the tooling is explained here: 
    https://nest.github.io/nest-simulator/coding_guidelines_c++

Options:

    --help                      This help.

    --[i]ncremental             Prompt user before each file analysis.

    --file=/path/to/file        Perform the analysis on this file.

    --git-start=Git_SHA_value   Hash value (Git SHA) from which Git starts the diff.
                                Default: --git-start=master

    --git-end=Git_SHA_value     Hash value (Git SHA) at which Git ends the diff.
                                Default: --git-start=HEAD

    --cppcheck=exe              The name of the CPPCHECK executable.
                                Default: --cppcheck=cppcheck
                                Note: CPPCHECK version 1.69 or later is required.
                                      This corresponds to the version installed in
                                      the NEST Travis CI build and test environment.

    --clang-format=exe          The name of the CLANG-FORMAT executable.
                                Default: --clang-format=clang-format-3.6
                                Note: CLANG-FORMAT version 3.6 is required.
                                      This corresponds to the version installed in
                                      the NEST Travis CI build and test environment.

    --vera++=exe                The name of the VERA++ executable.
                                Default: --vera++=vera++

    --pep8=exe                  The name of the PEP8 executable.
                                Default: --pep8=pep8
EOF
}

echo ""
echo "+ + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +"
echo "+                       NEST STATIC CODE ANALYSIS TOOL                        +"
echo "+ + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +"

# Process parameters.
while test $# -gt 0 ; do
  case "$1" in
      --help)
          usage
          ;;
      --i)
          INCREMENTAL=true
          ;;
      --incremental)
          INCREMENTAL=true
          ;;
      --file=*)
          FILE_TO_BE_CHECKED="$( echo "$1" | sed 's/^--file=//' )"
          if [ ! -f $FILE_TO_BE_CHECKED ]; then
            error_exit "The specified file does not exist. File: $FILE_TO_BE_CHECKED"
          fi
          ;;
      --git-start=*)
          GIT_START_SHA="$( echo "$1" | sed 's/^--git-start=//' )"
          ;;
      --git-end=*)
          GIT_END_SHA="$( echo "$1" | sed 's/^--git-end=//' )"
          ;;
      --cppcheck=*)
          CPPCHECK="$( echo "$1" | sed 's/^--cppcheck=//' )"
          ;;
      --vera++=*)
          VERA="$( echo "$1" | sed 's/^--vera++=//' )"
          ;;
      --pep8=*)
          PEP8="$( echo "$1" | sed 's/^--pep8=//' )"
          ;;
      --clang-format=*)
          CLANG_FORMAT="$( echo "$1" | sed 's/^--clang-format=//' )"
          ;;
      *)
          error_unknown_option "$1"
          ;;
  esac
  shift
done

# Evaluate sed extended regex parameter.
# The sed syntax for extended regular expressions differs for the operating systems: BSD: -E  other: -r
EXTENDED_REGEX_PARAM=r
/bin/sh -c "echo 'hello' | sed -${EXTENDED_REGEX_PARAM} 's/[aeou]/_/g' "  >/dev/null 2>&1 || EXTENDED_REGEX_PARAM=E

# Verify the VERA++ installation.
$VERA ./nest/main.cpp >/dev/null 2>&1 || error_exit "Failed to verify the VERA++ installation. Executable: $VERA"
$VERA --profile nest ./nest/main.cpp >/dev/null 2>&1 || error_exit "Failed to verify the VERA++ installation. The profile 'nest' could not be found. See https://nest.github.io/nest-simulator/coding_guidelines_c++#vera-profile-nest"

# Verify the PEP8 installation.
$PEP8 --ignore="E121" ./extras/parse_travis_log.py || error_exit "Failed to verify the PEP8 installation. Executable: $PEP8"

# Verify the CPPCHECK installation. CPPCHECK version 1.69 or later is required.
# Previous versions of CPPCHECK halted on sli/tokenutils.cc (see https://github.com/nest/nest-simulator/pull/79)
$CPPCHECK --enable=all --inconclusive --std=c++03 ./nest/main.cpp >/dev/null 2>&1 || error_exit "Failed to verify the CPPCHECK installation. Executable: $CPPCHECK"
cppcheck_version=`$CPPCHECK --version | sed 's/^Cppcheck //'`
IFS=\. read -a cppcheck_version_a <<< "$cppcheck_version"
if [[ ${cppcheck_version_a[0]} -lt 1 ]]; then
  error_exit "Failed to verify the CPPCHECK installation. Version 1.69 or later is requires. The executable '$CPPCHECK' is of version $cppcheck_version."
elif [[ ${cppcheck_version_a[0]} -eq 1 && ${cppcheck_version_a[1]} -lt 69 ]]; then
  error_exit "Failed to verify the CPPCHECK installation. Version 1.69 or later is requires. The executable '$CPPCHECK' is of version $cppcheck_version."
fi

# Verify the CLNAG-FORMAT installation. CLANG-FORMAT version 3.6 and only 3.6 is required.
# The CLANG-FORMAT versions up to and including 3.5 do not support all configuration options required for NEST. 
# Version 3.7 introduced a different formatting. NEST relies on the formatting of version 3.6.
$CLANG_FORMAT -style=./.clang-format ./nest/main.cpp >/dev/null 2>&1 || erro_exit "Failed to verify the CLANG-FORMAT installation. Executable: $CLANG_FORMAT"
clang_format_version=`$CLANG_FORMAT --version | sed -${EXTENDED_REGEX_PARAM} 's/^.*([0-9]\.[0-9])\..*/\1/'`
if [[ "x$clang_format_version" != "x3.6" ]]; then
  error_exit "Failed to verify the CLANG-FORMAT installation. Version 3.6 is requires. The executable '$CLANG_FORMAT' is of version $clang_format_version."
fi

# Extracting changed files between two commits.
if [[ "x$FILE_TO_BE_CHECKED" != "x" && -f $FILE_TO_BE_CHECKED ]]; then
  file_names=$FILE_TO_BE_CHECKED
else
  file_names=`git diff --name-only $GIT_START_SHA..$GIT_END_SHA`
fi

if [ -z "$file_names" ]; then
  echo
  echo "There are no files to check."
  exit 0
fi

if [ ! -x ./extras/static_code_analysis.sh ]; then
  sudo chmod +x ./extras/static_code_analysis.sh
fi

RUNS_ON_TRAVIS=false
unset NEST_VPATH

./extras/static_code_analysis.sh "$RUNS_ON_TRAVIS" "$INCREMENTAL" "$file_names" "$NEST_VPATH" "$VERA" "$CPPCHECK" "$CLANG_FORMAT" "$PEP8"
