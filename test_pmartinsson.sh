#!/usr/bin/env bash
set -o nounset

# Copyright (C) 2014 Patrik Martinsson <martinsson@patrik.gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Mode: vim, tabstop=2; softtabstop=2; shiftwidth=2; 
#
# This is the test-script for tcp_monitor.sh 
# Source is maintaned at <https://github.com/patchon/tcp_monitor>



# * * * * * * * * * * * * * * * * * * * * 
# Global variables, named g_variable-name
#
g_tcp_monitor="timeout 1 $(pwd)/tcp_monitor.sh"
g_tcp_monitor_wo_timeout="$(pwd)/tcp_monitor.sh"
g_pass="PASS"
g_fail="FAIL"
g_failure="0"
g_verbose="0"




# * * * * * * * * * * * *
# Function declarations, 
#


# A function that prints a pretty message about whats beeing done. 
#
# Arguments, 
# - A string containing the message to print
#
# Returns,
# - Function doesn't "return" in that sense. 
# 
function pretty_print {
  local message=${1}
  local padding="80"
  
  # Remove timeout and print, 
  message=${message/timeout ?/}
  printf "%-${padding}s %-10s" "Testing ${message}" " => " 
}



# A function that prints a pretty message if a test succeeds. 
#
# Arguments, 
# - A string containing the message to print
# - A string containing the exit code of the command
#
# Returns,
# - Function doesn't "return" in that sense. 
# 
function print_pass {
  local message=${1}
  local exit_code=${2}

  tput setaf 2
  printf "%s\n" "${g_pass} (exit = $exit_code)"
  tput setaf 0
  
  if [[ ${g_verbose} -eq 1 ]]; then 
    tput setaf 4
    echo -e ${message} "\n"
    tput setaf 0
  fi
}



# A function that prints a pretty message if a test fails. 
#
# Arguments, 
# - A string containing the message to print
# - A string containing the exit code of the command
#
# Returns,
# - Function doesn't "return" in that sense. 
# 
function print_fail {
  local message="${1}"
  local exit_code="${2}"

  tput setaf 1
  printf "%s\n" "${g_fail} (exit = $exit_code)"
  tput setaf 0
  
  if [[ 1 -eq 1 ]]; then 
    tput setaf 4
    echo -e ${message} "\n"
    tput setaf 0
  fi

  g_failure="1"
}



# A function that will perform a given test, 
#
# Arguments, 
# - A string of flags that should be passed to the command 
#
# Returns,
# - Function doesn't "return" in that sense. 
# 
function do_test {
  # The actual flags to test, 
  local flags=("$@")
  local exit_val=""

  # Loop the flags for testing, 
  for flag in "${flags[@]}"; do
    # Generate the command, 
    cmd="${g_tcp_monitor} "${flag}""
  
    # Print what we are doing, 
    pretty_print "${cmd}"
    
    # Get the result, 
    out=$(${cmd} 2>&1)
    exit_val=$?

    # Make something useful out of it, 
    if [[ ${exit_val} -eq 1 ]]; then
      print_pass "${out}" $exit_val
    else
      print_fail "${out}" $exit_val
    fi
  done
  echo ""
}



# A function that will print an header, 
#
# Arguments, 
# - A string that contains the actual header
#
# Returns,
# - Function doesn't "return" in that sense. 
# 
function print_header {
  local message=${1}
  local x 

  for ((x = 0; x < 25; x++));do 
    printf  "= "
  done
  
  echo -e "\n" $message

  for ((x = 0; x < 25; x++));do 
    printf  "= "
  done
  printf "\n \n"
}



# A function that will print an header, 
#
# Arguments, 
# - Function doesn't take any arguments. 
#
# Returns,
# - Returns a string containing the path to the newly create directory. 
# 
function create_tmp {
  local log_dir  
  log_dir=$(mktemp -d --suffix='--a b c-x Y' 2>&1)
  
  if [[ $? -ne 0 ]]; then
    echo "Error creating tempfile (${log_dir})." >&2; exit 1;
  else
    echo $log_dir
  fi
} 



# * * * * * * 
# A function that tests command-line options with invalid values
#
# Arguments, 
# - Function doesn't take any arguments. 
#
# Returns,
# - Function doesn't return in that sense.
# 
function testcase_a {
  local header_message="Testing command-line options with invalid values."
  local flags=()
  print_header "${header_message}"

  # All of these values should generate errors, 
  # - Specified cofigfile doesn't exist, 
  # - Can't write output file to specified path, 
  # - Bogus value is given to the -n parameter, 
  # - Bogus value is given to the -d parameter, 
  flags=("-c /config_no_exist"
           "-f /proc/no_write_here"
           "-n B|O*[G](U)?S="
           "-d A\$*^\"\'"
          )
  
  do_test "${flags[@]}"
}



# * * * * * * 
# A function that tests command-line options with values out of bound
#
# Arguments, 
# - Function doesn't take any arguments. 
#
# Returns,
# - Function doesn't return in that sense.
# 
function testcase_b {
  local header_message="Testing command-line options with values out of bound."
  local flags=()
  print_header "${header_message}"

  # All of these values should generate errors, 
  # - Specified value to -n is negative, 
  # - Specified value to -n is "to high", 
  # - Specified value to -d is negative, 
  # - Specified value to -d is "to high", 
  flags=("-n -100" 
           "-n 1234567" 
           "-d -100"
           "-d 121"
         )
  
  do_test "${flags[@]}"
}


# * * * * * * 
# A function that tests command-line options with missing values within/without 
# quotes. 
#
# Arguments, 
# - Function doesn't take any arguments. 
#
# Returns,
# - Function doesn't return in that sense.
function testcase_c {
  local header_message="Testing command-line options with missing values 
                        within/without quotes." 
  local cmd=""
  local out=""
  local exit_val=""
  print_header "$header_message"
  
  # All of these empty values should generate errors, 
  # - These are handeled here (not passed to the test_function) since we want to 
  #   avoid quoting problems. 
  for flag in -c -d -f -n; do
  
    # Print and execute test, 
    pretty_print "${g_tcp_monitor} $flag \" \""
    out=$(${g_tcp_monitor} $flag " " 2>&1)
    exit_val=$?
  
    # Make sure we are alright, 
    if [[ $exit_val -eq 1 ]]; then
      print_pass "${out}" "$exit_val"
    else
      print_fail "${out}" "$exit_val"
    fi
  
    # Same as above, but with single-quotes,
    pretty_print "${g_tcp_monitor} $flag ' '"
    out=$(${g_tcp_monitor} $flag ' ' 2>&1)
    exit_val=$?
  
    if [[ $exit_val -eq 1 ]]; then
      print_pass "${out}" "$exit_val"
    else
      print_fail "${out}" "$exit_val"
    fi
    
    # Same as above, but with nothing at all, 
    pretty_print "${g_tcp_monitor} $flag"
    out=$(${g_tcp_monitor} $flag 2>&1)
    exit_val=$?
  
    if [[ $exit_val -eq 1 ]]; then
      print_pass "${out}" "$exit_val"
    else
      print_fail "${out}" "$exit_val"
    fi
  done
  echo ""
}



# * * * * * * 
# A function that tests command-line options with invalid values within/without 
# quotes and spaces. 
#
# Arguments, 
# - Function doesn't take any arguments. 
#
# Returns,
# - Function doesn't return in that sense.
function testcase_d {
  local header_message="Testing command-line options with invalid values within 
                        quotes and spaces." 
  print_header "$header_message"

  # All of these empty values should generate errors, 
  # - These are handeled here (not passed to the test_function) since we want to
  #   avoid quoting problems. 
  # 
  # - Note that -f is not tested here, since it will create an actual output-
  #   file
  for flag in -c -d -n; do
    # Print command and execute, 
    pretty_print "${g_tcp_monitor} $flag \"  x y spaces \""
    out=$(${g_tcp_monitor} $flag "  x y spaces  " 2>&1)
    exit_val=$?

    # Make sure we are alright, 
    if [[ $exit_val -eq 1 ]]; then
      print_pass "${out}" "$exit_val"
    else
      print_fail "${out}" "$exit_val"
    fi
  
    # Same with single-quotes, 
    pretty_print "${g_tcp_monitor} $flag ' x y spaces '"
    out=$(${g_tcp_monitor} $flag ' x y spaces ' 2>&1)
    exit_val=$?

    if [[ $exit_val -eq 1 ]]; then
      print_pass "${out}" "$exit_val"
    else
      print_fail "${out}" "$exit_val"
    fi
  done
  echo ""
}



# * * * * * * 
# A function that tests valid commandline-options for output-file where 
# directory does't exist and should be created
#
# Arguments, 
# - Function doesn't take any arguments. 
#
# Returns,
# - Function doesn't return in that sense.
# 
function testcase_e {
  local header_message="Testing of valid commandline-options for output-file 
                        where directory does't exist and should be created (with
                        spaces)."
  # Set up vars, 
  local exit_val=""
  local lines=""
  local tmp_dir=$(create_tmp) 
  local log_file="${tmp_dir}/another dir/log_file"
  local out=""
  
  
  print_header "$header_message"
  
  # Print command and execute, 
  pretty_print "${g_tcp_monitor_wo_timeout} -n 1 -f \"${log_file}\""
  out=$(${g_tcp_monitor_wo_timeout} -n 1 -f "${log_file}" 2>&1)
  exit_val=$?
  
  # Make sure we are alright. Now, we check so the exit-code is fine, but we 
  # also want to make sure that we *atleast got something* in our output file. 
  # We can verify our header, and also that we got a couple of rows. This test 
  # will however fail if we don't have any sockets established when running, 
  # I find that *hihgly* unlikely though. We could ofcourse prevent that by 
  # making sure we have sockets avalable for listing (eg. by creating them).
  if [[ $exit_val -eq 0 ]]; then
    if grep -q "Refreshing 1 / 1 with an interval of 1 second(s)" \
               "${log_file}"; then
      
      # A bit sloppy, just get me the lines 
      lines=$(cat "${log_file}" | wc -l)

      if [[ "${lines}" -gt 4 ]]; then
        print_pass "Success : ${log_file} contained ${lines} number of lines and
                    contains given parameters." "${exit_val}"
      else
        print_fail "${log_file} contained fewer than 4 lines. This mostly
                    indicates an error ($out)" "${exit_val}"
      fi
    fi
  else
    print_fail "${log_file} contained fewer than 4 lines. This mostly indicates 
                an error" "${exit_val}"
  fi
  echo ""
  
  # Remove temporary files, 
  rm -r "${tmp_dir}"
  [[ $? -ne 0 ]] && { echo "Error deleting tempfile (see above for reason)." 
                      >&2; exit 1; }
} 



# * * * * * * 
# A function that tests valid commandline-options for output-file where 
# directory does't exist and should be created
#
# Arguments, 
# - Function doesn't take any arguments. 
#
# Returns,
# - Function doesn't return in that sense.
# 
function testcase_f {
  local header_message="Testing of valid commandline-options for output-file 
                        where directory does't exist and cant be created (with
                        spaces)."
  # Set up vars, 
  local exit_val=""
  local tmp_dir="/proc/test case"
  local log_file="${tmp_dir}/output"
  local out=""

  print_header "$header_message"
  pretty_print "${g_tcp_monitor_wo_timeout} -n 1 -f \"${log_file}\""
  out=$(${g_tcp_monitor_wo_timeout} -n 1 -f "${log_file}" 2>&1)
  exit_val=$?
  
  # Make sure we are alright.
  if [[ $exit_val -eq 0 ]]; then
    print_fail "We should have returned an error, but exit-code suggests 
                otherwise ($out)" "${exit_val}"
  else
    print_pass "Success : We couldn't create a directory and exit-code suggest
                that we couldn't." "${exit_val}"
  fi
  echo ""
} 



# * * * * * * 
# A function that tests valid commandline-options for config-file where the 
# config-file contains both valid and invalid values
#
# Arguments, 
# - Function doesn't take any arguments. 
#
# Returns,
# - Function doesn't return in that sense.
# 
function testcase_g {
  local header_message="Testing of valid commandline-options for config-file 
                        where the config-file contains both valid and invalid 
                        values"

  # Set up vars, 
  local exit_val=""
  local lines=""
  local tmp_dir=$(create_tmp) 
  local conf_file="${tmp_dir}/g_tcp_monitor.conf"
  local out=""

  cat <<- EOF >> "${conf_file}"
	# This is a comment, ignore me, 
	DELAY=5
	# Another comment, 
	I'm not a valid part of this config, break please. 
	NUMBER_OF_REFRESHES=1
	EOF

  print_header "$header_message"
  pretty_print "${g_tcp_monitor_wo_timeout} -c \"${conf_file}\""
  out=$(${g_tcp_monitor_wo_timeout} -c "${conf_file}" 2>&1)
  exit_val=$?

  # Make sure we are alright.
  if [[ $exit_val -eq 0 ]]; then
    print_fail "We should have returned an error, but exit-code suggests 
                otherwise ($out)" "${exit_val}"
  else
    print_pass "Success : We returned an error because of invalid values in 
                config. ($out)" "${exit_val}"
  fi
  
  # Remove temporary files, 
  rm -r "${tmp_dir}"
  [[ $? -ne 0 ]] && { echo "Error deleting tempfile (see above for reason)." 
                      >&2; exit 1; }
  echo ""
} 



# * * * * * * 
# A function that tests valid commandline-options for config-file where the 
# config-file contains only valid.
#
# Arguments, 
# - Function doesn't take any arguments. 
#
# Returns,
# - Function doesn't return in that sense.
# 
function testcase_g {
  local header_message="Testing of valid commandline-options for config-file 
                        where the config-file contains only valid values"

  # Set up vars, 
  local exit_val=""
  local lines=""
  local tmp_dir=$(create_tmp) 
  local conf_file="${tmp_dir}/g_tcp_monitor.conf"
  local out_file="${tmp_dir}/outfile"
  local out=""

  cat <<- EOF >> "${conf_file}"
	# This is a comment, ignore me, 
	DELAY=2
	# Another comment, 
	NUMBER_OF_REFRESHES=2
  FILE=$out_file
	EOF

  print_header "$header_message"
  pretty_print "${g_tcp_monitor_wo_timeout} -c \"${conf_file}\" -f \"${out_file}\""
  out=$(${g_tcp_monitor_wo_timeout} -c "${conf_file}" -f "${out_file}" 2>&1)
  exit_val=$?

  # Make sure we are alright.
  if [[ $exit_val -eq 0 ]]; then
    if grep -q "Refreshing 2 / 2 with an interval of 2 second(s)" \
      "${out_file}";then
      # Make sure we have atleast 4 lines
      lines=$(cat "${out_file}" | wc -l)
      if [[ "${lines}" -gt 4 ]]; then
        print_pass "'${out_file}' contained ${lines} number of lines *and*
                 configuration was set correctly." "${exit_val}"
      else
        print_fail "'${out_file}' contained fewer than 4 lines. 
                    This mostly indicates an error." "${exit_val}"
      fi
    else
        print_fail "Could not verify that parameters where set 
                    correctly." "${exit_val}"
    fi
  else
    print_fail "Bad exitstatus from ${g_tcp_monitor_wo_timeout} ($out)" \
               "${exit_val}"
  fi

  # Remove temporary files, 
  rm -r "${tmp_dir}"
  [[ $? -ne 0 ]] && { echo "Error deleting tempfile (see above for reason)." 
                      >&2; exit 1; }
  echo ""
} 



# * * * * * * 
# A function that tests valid commandline-options for config-file where the 
# config-file contains only valid but are overridden by the commandline-
# option.
#
# Arguments, 
# - Function doesn't take any arguments. 
#
# Returns,
# - Function doesn't return in that sense.
# 
function testcase_h {
  local header_message="Testing of valid commandline-options for config-file 
                        where the config-file contains only valid values but
                        are overridden by the commandline-options."

  # Set up vars, 
  local exit_val=""
  local lines=""
  local tmp_dir=$(create_tmp) 
  local conf_file="${tmp_dir}/g_tcp_monitor.conf"
  local out_file="${tmp_dir}/outfile"
  local out=""

  cat <<- EOF >> "${conf_file}"
	# This is a comment, ignore me, 
	DELAY=1
	# Another comment, 
	NUMBER_OF_REFRESHES=1
	FILE="${tmp_dir}/no_no"
	EOF

  print_header "$header_message"
  pretty_print "${g_tcp_monitor_wo_timeout} -c \"${conf_file}\" -f "${out_file} -d2 -n3""
  out=$(${g_tcp_monitor_wo_timeout} -c "${conf_file}" -f "${out_file}" -d 2 -n 3 2>&1)
  exit_val=$?

  if [[ $exit_val -eq 0 ]]; then
    # Make sure output-file from config-file wasn't created (since it should
    # have been overridden by the option from the cli). 
    if [[ -f "${tmp_dir}/no_no" ]]; then
      print_fail "File ${tmp_dir}/no_no was found but should't exist ($out)." \
                 "${exit_val}"
    fi

    # Same here, make sure the commandline-option was the one that was read in, 
    # these values are not the same as from the config-file.
    if grep -q "Refreshing 3 / 3 with an interval of 2 second(s)" \
      "${out_file}";then
      # Make sure we have atleast 4 lines
      lines=$(cat "${out_file}" | wc -l)
      if [[ "${lines}" -gt 4 ]]; then
        print_pass "'${out_file}' contained ${lines} number of lines *and*
                    configuration was set correctly." "${exit_val}"
      else
        print_fail "'${out_file}' contained fewer than 4 lines. 
                    This mostly indicates an error." "${exit_val}"
      fi
    else
        print_fail "Could not verify that parameters where set 
                    correctly." "${exit_val}"
    fi
  else
    print_fail "Bad exitstatus from ${g_tcp_monitor_wo_timeout} ($out)" \
               "${exit_val}"
  fi
  
  # Remove temporary files, 
  rm -r "${tmp_dir}"
  [[ $? -ne 0 ]] && { echo "Error deleting tempfile (see above for reason)." 
                      >&2; exit 1; }
  echo ""
} 



# * * * * * * 
# A function that tests so output from ss is good. We do that by doing 
# a telnet to google.com and we look for the expected output. This is 
# in some way "a regression-test". It is so in the sense that we check 
# so the output from ss is valid, if an update to ss breaks the expected'
# output, this test should show that and failure should occur. 
#
# Arguments, 
# - Function doesn't take any arguments. 
#
# Returns,
# - Function doesn't return in that sense.
# 
function testcase_i {
  local header_message="Testing if output from ss is as expected."

  # Set up vars, 
  local exit_val=""
  local lines=""
  local tmp_dir=$(create_tmp) 
  local out_file="${tmp_dir}/outfile"
  local out=""
  local pid_of_connection=""
  local line=""

  # This just validated the ip:, since the port part can be anything 
  local re_ip_port="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:.*$"
  local re_num="^[0-9]+$"
  local local_addr=""
  local remote_addr=""
  local pid=""
  local prog=""

  print_header "$header_message"
  pretty_print "${g_tcp_monitor_wo_timeout} -o \"${out_file}\""
  
  # Just open a connection to google,keep it open for 60 sec 
  ( echo "open google.com 80"; sleep 60; ) | telnet &> /dev/null &
  pid_of_connection=$!
  #disown 
  out=$(${g_tcp_monitor_wo_timeout} -n 1 -f "${out_file}" 2>&1)
  exit_val=$?

  if [[ $exit_val -eq 0 ]]; then
    
    # Grep the telnet line socket we created above, 
    line=$(egrep -m1 "${pid_of_connection}[ ]+\/[ ]+telnet" "${out_file}") 

    if [[ $? -eq 0 ]]; then

      # Read in the fields,     
      read local_addr remote_addr duration pid prog <<< "${line}"
      
      # Check each field so it contains what we expect, 
      if [[ ! $local_addr =~ $re_ip_port ]]; then
        print_fail "Local-port-field ($local_addr) doesn't 
                    match our re (${re_ip_port})." "$exit_val"
      fi
      
      if [[ ! $remote_addr =~ $re_ip_port ]]; then
        print_fail "Remote-port-field ($remote_addr) doesn't 
                    match our re (${re_ip_port})." "$exit_val"
      fi
      
      if [[ ! $duration =~ $re_num || ! $pid =~ $re_num ]]; then
        print_fail "Duration-field ($duration) doesn't match our re 
                    (${re_num})." "$exit_val"
      fi

      if [[ ! $pid =~ $re_num ]]; then
        print_fail "Pid-field ($pid) doesn't match our re 
                    (${re_num})." "$exit_val"
      fi
      
      if [[ ! $prog ]]; then
        print_fail "Progname-field ($prog) is empty." "$exit_val"
      fi
      
      print_pass "Fields ($local_addr - $remote_addr - $duration - $pid - $prog)
                  seeems fine." "${exit_val}"
    else
      print_fail "Could not verify output from ss in ${out_file}." "$exit_val"
    fi
  else
    print_fail "Unexpected exit from ${g_tcp_monitor_wo_timeout} 
    ($out)" "$exit_val"
  fi

  # Terminate the connection, 
  kill $pid_of_connection
  if [[ $? -ne 0 ]]; then
    kill -9 $pid_of_connection || 
    { echo "Could not terminate telnet-session ($pid_of_connection)" >&2; 
      exit 1; }
  fi

  # Remove temporary files, 
  rm -r "${tmp_dir}"
  [[ $? -ne 0 ]] && { echo "Error deleting tempfile (see above for reason)." 
                      >&2; exit 1; }
  echo ""
} 




# * * * * * * * * * * * *
# Main start, 
#

# Test if verbose,  
[[ $# == 1 && $1 == "-v" ]] && g_verbose=1

printf "\n%s\n\n" "Testing begins at $(date)"

# Run testcases, 
testcase_a
testcase_b
testcase_c
testcase_d
testcase_e
testcase_f
testcase_g
testcase_h
testcase_i

if [[ $g_failure -ne 0 ]]; then
  echo -n "Didn't pass all tests ! " >&2
  if [[ $g_verbose -eq 0 ]]; then
    echo "(use -v to get verbose output)" >&2 
  else
    echo ""
  fi
  exit 1
fi

echo "Passed all tests !"
exit 
