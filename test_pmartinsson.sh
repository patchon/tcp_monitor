#!/bin/bash
set -o nounset

tcp_monitor="timeout 1 $(pwd)/tcp_monitor.sh"
tcp_monitor_wo_timeout="$(pwd)/tcp_monitor.sh"

g_pass="PASS"
g_fail="FAIL"


function pretty_print {
  local message="${1}"
  local padding="80"
  
  # Remove timeout and print, 
  message=${message/timeout ?/}
  printf "%-${padding}s %-10s" "Testing ${message}" " => " 
}


function print_pass {
  local message="${1}"
  local exit_code="${2}"

  tput setaf 2
  printf "%s\n" "${g_pass} (exit = $exit_code)"
  tput setaf 0
  
  if [[ 1 -eq 1 ]]; then 
    tput setaf 4
    echo -e ${message} "\n"
    #echo ${message/[^\n]/}
    #printf "%s\n\n" "${message/[^\n]/}"
    tput setaf 0
  fi
}

function print_fail {
  local message="${1}"
  local exit_code="${2}"

  tput setaf 1
  printf "%s\n" "${g_fail} (exit = $exit_code)"
  tput setaf 0
  
  if [[ 1 -eq 1 ]]; then 
    tput setaf 4
    echo -e ${message} "\n"
    #printf "%s\n\n" "${message/[^\n]/}"
    tput setaf 0
  fi

  g_failure="1"
}

# The test, 
function do_test {
  # The actual flags to test, 
  local flags=("$@")
  local exit_val=""

  # Loop the flags for testing, 
  for flag in "${flags[@]}"; do
    # Generate the command, 
    cmd="${tcp_monitor} "${flag}""
  
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

  printf "\n"
}

function print_header {

  local message="$1" 
  local x 

  for ((x = 0; x < 25; x++));do 
    printf  "= "
  done
  
  echo -e "\n\n"$message"\n"

  for ((x = 0; x < 25; x++));do 
    printf  "= "
  done
  printf "\n \n"
}

# 
# Flags are declared in the global scope, however i "feel" better if 
# we pass them as parameters into the function. It makes more sense to me 
# to do it that way. 




printf "\n%s\n\n" "Testing begins at $(date)"


# * * * * * * 
# Testing of commandline-options with invalid values, 
# 
header_message="Testing command-line options with invalid values."
print_header "${header_message}"

# All of these values should generate errors, 
# - Specified cofigfile doesn't exist, 
# - Can't write output file to specified path, 
# - Bogus value is given to the -n parameter, 
# - Bogus value is given to the -d parameter, 
g_flags=("-c /config_no_exist"
         "-f /proc/no_write_here"
         "-n B|O*[G](U)?S="
         "-d A\$*^\"\'"
        )

do_test "${g_flags[@]}"




# * * * * * * 
# 
# Testing command-line options with values out of bound
# 
header_message="Testing command-line options with values out of bound."
print_header "$header_message"

# All of these values should generate errors, 
# - Specified value to -n is negative, 
# - Specified value to -n is "to high", 
# - Specified value to -d is negative, 
# - Specified value to -d is "to high", 
g_flags=("-n -100" 
         "-n 1234567" 
         "-d -100"
         "-d 121"
        )

do_test "${g_flags[@]}"



# * * * * * * 
# 
# Testing command-line options with missing values
# 
header_message="Testing command-line options with missing values within/without 
                quotes." 
print_header "$header_message"

# All of these empty values should generate errors, 
# - These are handeled here (not passed to the test_function) since we want to 
#   avoid quoting problems. 
for flag in -c -d -f -n; do

  # Build up the command, 
  cmd="${tcp_monitor} $flag \" \""
  pretty_print "${cmd}"

  # Execute it, 
  out=$(${tcp_monitor} $flag " " 2>&1)
  exit_val=$?

  # Make sure we are alright, 
  if [[ $exit_val -eq 1 ]]; then
    print_pass "${out}" "$exit_val"
  else
    print_fail "${out}" "$exit_val"
  fi

  # Same as above, but with single-quotes,
  cmd="${tcp_monitor} $flag ' '"
  pretty_print "${cmd}"

  out=$(${tcp_monitor} $flag ' ' 2>&1)
  exit_val=$?

  if [[ $exit_val -eq 1 ]]; then
    print_pass "${out}" "$exit_val"
  else
    print_fail "${out}" "$exit_val"
  fi
  
  # Same as above, but with nothing at all, 
  cmd="${tcp_monitor} $flag"
  pretty_print "${cmd}"

  out=$(${tcp_monitor} $flag 2>&1)
  exit_val=$?

  if [[ $exit_val -eq 1 ]]; then
    print_pass "${out}" "$exit_val"
  else
    print_fail "${out}" "$exit_val"
  fi
done
echo ""



# * * * * * * 
# 
# Testing command-line options with invalid values within quotes and spaces.
# 
header_message="Testing command-line options with invalid values within quotes 
                and spaces." 
print_header "$header_message"

# All of these empty values should generate errors, 
# - These are handeled here (not passed to the test_function) since we want to 
#   avoid quoting problems. 
# 
# - Note that -f is not tested here, since it will create an actual output-file
for flag in -c -d -n; do
  # Print command and execute, 
  pretty_print "${tcp_monitor} $flag \"  x y spaces foo derp  \""
  out=$(${tcp_monitor} $flag "  x y spaces foo derp  " 2>&1)
  exit_val=$?

  # Make sure we are alright, 
  if [[ $exit_val -eq 1 ]]; then
    print_pass "${out}" "$exit_val"
  else
    print_fail "${out}" "$exit_val"
  fi
  
  # Same with single-quotes, 
  pretty_print "${tcp_monitor} $flag ' x y spaces foo derp '"
  out=$(${tcp_monitor} $flag ' x y spaces foo derp ' 2>&1)
  exit_val=$?

  if [[ $exit_val -eq 1 ]]; then
    print_pass "${out}" "$exit_val"
  else
    print_fail "${out}" "$exit_val"
  fi
done
echo ""




# * * * * * * 
# Testing of valid commandline-options for output-file where directory does't 
# exist and should be created
# 
function testcase_X {
  local header_message="Testing of valid commandline-options for output-file 
                        where directory does't exist and should be created (with
                        spaces)."
  # Set up vars, 
  local log_dir=""
  local log_file=""
  local lines=""
  local out=""
  local exit_val=""

  log_dir=$(mktemp -d --suffix='--a b c-x Y' 2>&1)
  [[ $? -ne 0 ]] && { echo "Error creating tempfile (${log_dir})." >&2; exit 1; }
  log_file="${log_dir}/log_file"
  
  print_header "$header_message"
  
  # Print command and execute, 
  pretty_print "${tcp_monitor_wo_timeout} -n 1 -f \"${log_file}\""
  out=$(${tcp_monitor_wo_timeout} -n 1 -f "${log_file}";)
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

      if [[ "${lines}" -gt 5 ]]; then
        print_pass "Success : ${log_file} contained ${lines} number of lines and
                    contains given parameters." "${exit_val}"
      else
        print_fail "${log_file} contained fewer than 5 lines. This mostly
                    indicates an error" "${exit_val}"
      fi
    fi
  else
    print_fail "${log_file} contained fewer than 5 lines. This mostly indicates 
                an error" "${exit_val}"
  fi
  
  # Remove temporary files, 
  rm -r "${log_dir}"
  [[ $? -ne 0 ]] && { echo "Error deleting tempfile (see above for reason)." 
                      >&2; exit 1; }
} 

testcase_X


# * * * * * * 
# Testing of valid commandline-options for output-file where directory does't 
# exist and should be created
# 
header_message="Testing of valid commandline-options for output-file where directory does't exist and can't be created"
print_header "$header_message"

g_log_dir="/proc/dir with spaces that does not exist"
g_log_file="${g_log_dir}/log_file"

cmd="${tcp_monitor_wo_timeout} -n 1 -f \"${g_log_file}\""
pretty_print "${cmd}"

out=$(${tcp_monitor_wo_timeout} -n 1 -f "${g_log_file}" 2>&1)

# Make something useful out of it, 
if [[ $? -eq 0 ]]; then
  echo "${g_fail} (SUCCESS: The exit-status of ${tcp_monitor_wo_timeout} suggests that we succeeded where we should have failed."
  ret=1
else
  pp_pass "${out}"
fi
echo ""



# * * * * * * 
# Testing of valid commandline-options for config-file where the config-file
# contains both valid and invalid values
# 
header_message="Testing of valid commandline-options for config-file where the config-file contains both valid and invalid values"
print_header "$header_message"

g_conf_dir="/tmp/directory with spaces"
g_conf_file="${g_conf_dir}/tcp_monitor.conf"

mkdir -pv "${g_conf_dir}"
rm -rf "${g_conf_file}"

cat << EOF >> "${g_conf_file}"
# This is a comment, ignore me, 
DELAY=5
# Another comment, 
I'm not a valid part of this config, break please. 
NUMBER_OF_REFRESHES=1 # Another valid, 
EOF

cmd="${tcp_monitor_wo_timeout} -c \"${g_conf_file}\""
pretty_print "${cmd}"

out=$(${tcp_monitor_wo_timeout} -c "${g_conf_file}" 2>&1)

# Make something useful out of it, 
if [[ $? -eq 0 ]]; then
  echo "${g_fail} (SUCCESS: The exit-status of ${tcp_monitor_wo_timeout} suggests that we succeeded where we should have failed."
  ret=1
else
  pp_pass "${out}"
fi



# * * * * * * 
# Testing of valid commandline-options for config-file where the config-file
# contains only valid values
# 
header_message="Testing of valid commandline-options for config-file where the config-file contains valid values"
print_header "$header_message"

g_conf_dir="/tmp/directory with spaces"
g_conf_file="${g_conf_dir}/tcp_monitor.conf"
g_output_file="${g_conf_dir}/output"

rm -rf "${g_conf_file}"
mkdir -pv "${g_conf_dir}"

cat << EOF >> "${g_conf_file}"
# This is a comment, ignore me, 
DELAY=2
NUMBER_OF_REFRESHES=2 
FILE="/${g_conf_dir}/output"
# Another comment, 
EOF

cmd="${tcp_monitor_wo_timeout} -c \"${g_conf_file}\""
pretty_print "${cmd}"

out=$(${tcp_monitor_wo_timeout} -c "${g_conf_file}" 2>&1)

# Make something useful out of it, 
if [[ $? -eq 0 ]]; then
  
  # Make sure our configuration-values where read in, 
  if grep -q "Refreshing 2 / 2 with an interval of 2 second(s)" "${g_output_file}";
  then
    # Make sure we have atleast 5 lines
    lines=$(cat "${g_output_file}" | wc -l)
    if [[ "${lines}" -gt 5 ]]; then
      pp_pass "'${g_output_file}' contained ${lines} number of lines *and* configuration was set correctly."
    else
      echo "${g_fail} '${g_output_file}' contained fewer than 5 lines. This mostly indicates an error"
      ret=1
    fi
  else
    echo "${g_fail} Could not verify that parameters where set correctly."
    ret=1
  fi
else
  echo "${g_fail}"
  ret=1
fi



# * * * * * * 
# Testing of valid commandline-options for config-file where the config-file
# contains only valid values
# 
header_message="Testing of valid config-file-options that are overrridden by commandline-options"
print_header "$header_message"

g_conf_dir="/tmp/directory with spaces"
g_conf_file="${g_conf_dir}/tcp_monitor.conf"
g_output_file="${g_conf_dir}/output"

rm -rf "${g_conf_dir}"
mkdir -pv "${g_conf_dir}"

cat << EOF >> "${g_conf_file}"
# This is a comment, ignore me, 
DELAY=5
NUMBER_OF_REFRESHES=10 
FILE="/${g_output_file}"
# Another comment, 
EOF

cmd="${tcp_monitor_wo_timeout} -c \"${g_conf_file}\""
pretty_print "${cmd}"

out=$(${tcp_monitor_wo_timeout} -c "${g_conf_file}" -d 3 -n 1 -f /tmp/output 2>&1)

# Make something useful out of it, 
if [[ $? -eq 0 ]]; then
  
  if [[ -f ${g_output_file} ]]; then
    echo "${g_fail} ${g_output_file} was found, when it should't been."
    ret=1
  else
    # Make sure our configuration-values where read in, 
    if grep -q "Refreshing 1 / 1 with an interval of 3 second(s)" "/tmp/output";
    then
      # Make sure we have atleast 5 lines
      lines=$(cat "/tmp/output" | wc -l)
      if [[ "${lines}" -gt 5 ]]; then
        pp_pass "'/tmp/output' contained ${lines} number of lines *and* configuration was set correctly (overridden by cli)."
      else
        echo "${g_fail} '/tmp/output' contained fewer than 5 lines. This mostly indicates an error"
        ret=1
      fi
    else
      echo "${g_fail} Could not verify that parameters where set correctly."
      ret=1
    fi
  fi
else
  echo "${g_fail}"
  ret=1
fi

  


exit






exit
#mkdir -p "/tmp/dir with spaces" \
#         /tmp/another dir with spaces/
#         
#        "-c /tmp/dir with spaces/config_file_valid"
#        "-c /tmp/dir with spaces/config_file_invalid"
#         "-c /tmp/dir with spaces/config_file_not_exist"

do_test "${g_flags[@]}"







exit 

# How often to refresh,
cmd="$tcp_monitor -n -100"
pretty_print "$cmd"
out=$(${cmd} 2>&1)

if [[ $? -eq 1 ]]; then
  pp_pass "${out} "
else
  echo "${g_fail}"
  ret=1
fi

# How often to refresh,
cmd="$tcp_monitor -n 1234567"
pretty_print "$cmd"
out=$(${cmd} 2>&1)

if [[ $? -eq 1 ]]; then
  pp_pass "${out} "
else
  echo "${g_fail}"
  ret=1
fi

# Number of times to refresh, 
cmd="$tcp_monitor -d -100"
pretty_print "$cmd"
out=$(${cmd} 2>&1)

if [[ $? -eq 1 ]]; then
  pp_pass "${out} "
else
  echo "${g_fail}"
  ret=1
fi

# Number of times to refresh, 
cmd="$tcp_monitor -d 121"
pretty_print "$cmd"
out=$(${cmd} 2>&1)

if [[ $? -eq 1 ]]; then
  pp_pass "${out} "
else
  echo "${g_fail}"
  ret=1
fi

  

  #g_term_width=$(tput cols)
  #g_outputwidth=$((${g_term_width}-${g_padding}-70))
  #if [[ ${#message} -gt ${g_outputwidth} ]]; then
  #  foo=$((${g_outputwidth}-4))
  #  message=${message:0:${g_outputwidth}}
  #  message="${message:0:$foo} *CUT_PP*"
  #fi
