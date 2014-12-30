#!/usr/bin/env bash
set   -o nounset

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
# This is the tcp_monitor.sh, man tcp_monitor for more information. 
# Source is maintaned at <https://github.com/patchon/tcp_monitor>


# * * * * * * * * * * * * * * * * * * * * 
# Global variables, named g_variable-name
#

# Turn on the bash's extended globbing feature. Instead of turning it off and 
# in the script, we just turn it on here and leave it like that.
shopt -s extglob

# Just to "keep track" of how many updates we have left, 
g_cnt=0      

# A parameter determining the first run, 
g_first_run=1

# Simple regex that is used on various places, 
g_re_digits="^[1-9][0-9]*$"

# This defines the minimum seconds you can specify without having the 
# output "cut-off" 
g_option_d_threshold=5

# These are the various options, 
g_opt_c_set=""
g_option_c=""
g_option_d=""
g_option_d_default=1
g_option_f=""
g_option_n=""
g_option_n_default="not_set"
g_option_n_forever="0"






# * * * * * * * * * * * *
# Function declarations, 
#



# A function that makes a external call to ss, parses the output, and stores
# it an array for later use. 
#
# Arguments, 
# - Function doesn't take any argument.
#
# Returns,
# - Function doesn't "return" in that sense. 
# 
function get_output_from_ss {
  local output
  
  # Do the actual call to ss and remove first line, 
  output=$(IFS=$'\n' ss --tcp --processes state established 2>&1) 
  
  # The return here will most likely be zero, otherwise we have a serious
  # problem. You can never be to careful though.
  if [[ ${?} -ne 0 ]];then
    err_msg="Call to ss failed. This should not happen 
            ($(strip_error "${output}"))."
    error "$err_msg"
  fi
  
  # Remove first line, replace spaces with *one* ; *and* remove the first two 
  # columns from ss. Save the output from sed into the variable output. The 
  # return from sed will not determine we actually replaces what we wanted, it
  # will only return anything else than zero if something *very odd* happened. 
  # Same as above though, you can never be to careful
  output=$(echo "${output}" | sed -e 's/\s\+/;/g'      \
                            -e 's/[0-9]\+;[0-9]\+;//g' \
                            -e '1d' 2>&1)

  if [[ ${?} -ne 0 ]];then
    err_msg="Call to sed failed. This should not happen 
             ($(strip_error "${output}"))."
    error "${err_msg}"
  fi
  
  # Handle the case were we dont have *any* established connections, 
  if [[ -z $output ]]; then
    err_msg="Didn't get *any* output from ss, you don't seem to have any
						tcp-established-connections available."
    error "$err_msg"
  fi

  # Define the array where we will store data that we later want to print. 
  # Also the variables for the column-width. This is used globally. 
  g_print_arr=()
  g_min_length_col1=20
  g_min_length_col2=22

  # Now do the actual parsing of the data, 
  for row in ${output}; do
    
    # Reset variables to store ss-output in, 
    local info_col1="" 
    local info_col2=""
    local info_col3=""
    
    # If we don't got permission to read this info, this is what we will display
    # in the "gui", if we are running as root though, we should be able to read
    # everything, 
    local error="n/a"
    local warn="(try root)"
    local app_name="$error"
    local app_pid="$error"
    local app_fd="$error"
    local time_diff="$error"
    local time_fd_modified="$error"
    
    # Now, based on the output from ss, and the sed we did we now that each 
    # column is delimited by ";", so lets just read the columns into variables,
    IFS=';' read info_col1 info_col2 info_col3 <<< "$row"

    # Set default values if we can't parse/grab output from ss, 
    info_col1=${info_col1:=$error} 
    info_col2=${info_col2:=$error} 
    info_col3=${info_col3:=$error} 
    
    # Now since we want a structured layout, lets calculate the min width of
    # the two first columns, 
    if [[ ${#info_col1} -gt ${g_min_length_col1} ]] ; then
      g_min_length_col1=${#info_col1}
    fi

    if [[ ${#info_col2} -gt ${g_min_length_col2} ]]; then
      g_min_length_col2=${#info_col2}
    fi

    # If we are root, set a warning-message that will be displayed if we end
    # up with empty data in column3. This happens with nfs for example.
    if is_root; then
      warn="(we have no data from ss to parse)"
    fi

    # As long as the third column (the one with the actual pid/fd info) is not 
    # set to our default value, we know we that we have info in there that we
    # want to parse, 
    if [[ ${info_col3} != "${error}" ]]; then
      
      # Ok, so the parsing below is done according to the page 
      # http://www.cyberciti.biz/files/ss.html. The basic idea is to extract, 
      # app-name, pid and fd of the socket. The "typical" format according to 
      # the page is, 'users:((app-name,X,Y))' (where X is the pid and Y the fd).
      # But that isn't totally true. First off, the appname-part is enclosed 
      # with "", secondly on versions above iproute-3.12 (looking at the source 
      # of ss from the iproute-package), the actual output is 
      # 'users:(("app-name",pid=X,fd=Y))'. So, to make this script somewhat 
      # compatible with rhel 7 (which comes with iproute-3.12), fedora 20/21,
      # lets determine the delimiter. 
      
      # Extract the app-name, 
      var="${info_col3#*\"}"
      app_name="${var%%\"*}"
      app_name="${app_name:=${error}}"

      # Set the default delimiter,
      # Note, if the release-file isn't there we are kinda screwed anyways with
      # trying to determine version. If we want this to be more portable (that 
      # is outside rhel, we should definitely use a better way of determining 
      # the output from ss). Maybe look at the actual version of ss, even though
      # it wasn't really that easy to parses 
      delim="="
      if [[ -f "/etc/redhat-release" ]]; then
        local version
        local re_redhat="Red Hat Enterprise"

        version=$(cat /etc/redhat-release 2>&1)
        
        # Again, we cannot be to careful when checking return codes from 
        # external commands, 
        if [[ ${?} -ne 0 ]]; then
          err_msg="Call to cat failed. This should not happen 
                  ($(strip_error "${version}"))."
          error "${err_msg}"
        fi

        [[ ${version}  =~ $re_redhat ]] && delim=","
      fi
      
      # Extract the actual pid & fd,
      var="${info_col3#*${delim}}"
      app_pid="${var%%,*}"
      app_pid="${app_pid:=${error}}"

      var="${info_col3##*${delim}}"
      app_fd="${var%%)*}"
      app_fd="${app_fd:=${error}}"

      # Now we have what we need to extract the actual "last-modified-time" of 
      # the actual socket. This may not be the best way of finding out when a
      # socket was created, but I haven't found any other way so I went with 
      # your hint on this one. See the description for more info.
      if [[ -S /proc/${app_pid}/fd/${app_fd} ]]; then
        # There are times when the actual socket is being removed right between
        # the check above and the stat below. If that happens just skip that 
        # socket since it's been removed. 
        time_fd_modified=$(stat -c %Y /proc/${app_pid}/fd/${app_fd} 2>&1)
        [[ ${?} -ne 0 ]] && continue
        
        # Get the time-difference, 
        time_diff=$(calculate_time_diff ${time_fd_modified})
      else
        # Same goes here, we had info about a socket, but now it's removed, 
        # just continue
        continue 
      fi 
      
      # Reset the warning, this is just as a hint to the user to try with root
      # if values are missing. If values are missing and even though we run as 
      # root, there is an actual bug in the parsing-code, and that message is 
      # taken care of at the beginning. 
      warn=""
    fi
    
    # Add the values to our array, for later printing, 
    g_print_arr+=("${info_col1};${info_col2};${time_diff};${app_pid};${app_name};${warn}")
  done
} 



# A function that will print the actual data stored in a global array
# (filled up by the get_output_from_ss-function), 
#
# Arguments, 
# - Functions doesn't take an argument. 
#
# Returns, 
# - Function doesn't "return" in that sense, 
#
function print_data {

  # Just add some padding to minlength, 
  local padding=5
  local min_length_col3=10
  local min_length_col4=6
  local min_length_col5=3
  g_min_length_col1=$((g_min_length_col1+=${padding}))
  g_min_length_col2=$((g_min_length_col2+=${padding}))

  # Calculate the total-width of the output, 
  local total_width=$((g_min_length_col1+
                       g_min_length_col2+
                       min_length_col3+
                       min_length_col4+
                       min_length_col5))

  # Variables, 
  local info_col1="" 
  local info_col2=""
  local info_col3=""
  local app_pid="" 
  local app_name=""
  local warn=""
  local warn_wrap=""

  # Lets print a warning to the user if the estimated width isn't enough
  if [[ ! ${g_option_f} ]]; then 
    # Do the actual printing, 
    tput clear

    if ! terminal_is_wide_enough ${total_width} && [[ ${g_first_run} -eq 1 ]]; then
      warn_wrap='Warning, your output will be wrapped over multiple lines.
                 \nPlease increase your windowsize (if possible) if you want
                 one-line-output.'
      show_warning "$warn_wrap"
    fi 
  fi

  if [[ ${g_option_f} && ${g_first_run} == 1 ]]; then
    msg="Output from script is being redirected to ${g_option_f} (options 
    -d=$g_option_d, -n=$g_option_n ) ..."
    echo $msg
  fi

  # Set variables, 
  local term_lines=$(tput lines) 
  local term_max_lines=$((term_lines-5))
  local term_notice=""
  local format="%-${g_min_length_col1}s %-${g_min_length_col2}s %-10s %-6s %-3s %-25s"

  # Loop the actual array containing our output from ss (space delimited),
  for row in ${!g_print_arr[*]}; do
    
    # If it's the first iteration, print header, 
    if [[ ${row} -eq 0 ]]; then
      create_top_bottom_header ${total_width}
      printf_wrapper "${format}" \
             "LOCAL_ADDR:PORT"   \
             "FOREIGN_ADDR:PORT" \
             "DURATION"          \
             "PID"               \
             "/"                 \
             "PROGRAM_NAME"
      
      msg="Refreshing forever"  
      if [[ ${g_option_n_forever} -ne 1 ]]; then
        msg="Refreshing ${g_cnt} / ${g_option_n_static}"
      fi
      printf_wrapper "%s\n" "${msg} with an interval of ${g_option_d} second(s)"

      create_top_bottom_header ${total_width}
    fi
    
    # Ok, so bear with me here, 
    # - If we are not printing to a file, *and* 
    # - The total amount of lines to print is more than we have lines in the 
    #   terminal, *and* 
    # - The delay-parameter is set below the threshold (defualt 5sec), *and* 
    # - We are about to print on the max-limit-line ($term_max_line), *then* 
    # - Print a message to the user about the output been cut off, due to the
    #   way we handle current printing (and break). 
    if [[ ! ${g_option_f} ]]; then 
      if [[ ${row} -eq ${term_max_lines}             && 
            ${#g_print_arr[@]} -gt ${term_max_lines} && 
            ${g_option_d} -lt ${g_option_d_threshold} ]];then

        term_notice='(Notice : Output is cut of due to the current 
                     output-handling, showing '${term_max_lines}' of 
                     '${#g_print_arr[@]}' lines. See '${0}' -h for explanation.'
        echo ${term_notice}
        break 
      fi
    fi

    # Read in the data, into vars and print them in the table, 
    IFS=';' read info_col1 info_col2 time_diff app_pid app_name warn <<< \
            "${g_print_arr[${row}]}"
  
    printf_wrapper "${format}" \
           "${info_col1}"      \
           "${info_col2}"      \
           "${time_diff}"      \
           "${app_pid}"        \
           "/"                 \
           "${app_name} ${warn}"
    printf_wrapper "\n"
  done
}



# A function that will parse the command-line-options
#
# Arguments, 
# - Function doesn't take any options, 
#
# Returns,
# - Function doesn't "return" in that sense, 
# - "errors out" if errors are found in config-file
#
function parse_command_line {
  local opt_n_set=""
  local opt_d_set=""
  local opt_f_set=""

  # Oh, yeah. This small hack justs make sure that if a user has specified, 
  # an help-flag, we will show it directly. Shifting in options below is great
  # but we dont have any control over how the args come in. 
  # So if a user types, $0 -d 123 --help, we would just want to show the help, 
  # no more no less. This "extra loop" sorts that for us. 
  re_help="-[-]*h(elp)*"
  for arg in ${@}; do
    if [[ ${arg} =~ ${re_help} ]]; then
      show_usage
    fi
  done

  # Loop through input parameters. I'm not a fan of getopt/getopts. Never 
  # seem to use it, maybe it has some features that will make life easier for
  # me, but I always just shift in parameters like this and parse them. Works 
  # fine for me I guess. 
  while [[ "${#}" > 0 ]]
  do
    # Option to look for, 
    opt="${1}"
    
    # If value is empty, set flag 
    [[ ! "${2:-}" ]] && error "Option ${opt} must have an argument."
    
    # If we have a value, strip value from leading/trailing spaces, 
    value="${2##*( )}" 
    value="${value%%*( )}"

    # Test again after we remove spaces, 
    [[ ! "${value:-}" ]] && error "Option ${opt} must have an argument."
    
    case "${opt}" in

      # Handle -c/--config-file 
      -c|--config-file)

        # Make sure that the parameter hasn't already been set, and that we 
        # have a valute to parse, 
        is_opt_set "${g_opt_c_set}"
        validate_c_option "${opt}" "${value}"
        g_opt_c_set="${opt}"
        shift
      ;;

      # Handle -d/--delay 
      -d|--delay)
        
        # Make sure that the parameter hasn't already been set, and that we 
        # have a value to parse, 
        is_opt_set "${opt_d_set}"
        [[ ! ${value:-} ]] && error "Option ${opt} must have an argument."
        
        validate_d_option "${opt}" "${value}"
        g_opt_d_set="${opt}"
        shift
      ;;

      # Handle -f/--output-file 
      -f|--output-file)

        # Make sure that the parameter hasn't already been set, and that we 
        # have a value to parse, 
        is_opt_set "${opt_f_set}"
        [[ ! ${value:-} ]] && error "Option ${opt} must have an argument."
        
        validate_f_option "${opt}" "${value}"
        g_opt_f_set="${opt}"
        shift
      ;;
      
      # Handle -n/--number-of-refreshes 
      -n|--number-of-refreshes)
        
        # Make sure that the parameter hasn't already been set, and that we 
        # have a value to parse, 
        is_opt_set "${opt_n_set}"
        [[ ! ${value:-} ]] && error "Option ${opt} must have an argument."

        validate_n_option "${opt}" "${value}"
        g_opt_n_set="${opt}"
        shift
      ;;
    
      # Handle everything else, 
      *)
        err_msg="Unsupported opt (${opt}).\nUse -h|--help for usage-instructions"
        error "${err_msg}"
      ;;
    esac

    # Shift the argument-list,
    shift
  done
}



# A function that used to parse the specified config-file. 
#
# Arguments, 
# - A string containing the config-file to parse
#
# Returns, 
# - Function doesn't "return" in that sense, 
# - "errors-out" if value doesn't gets validated 
#
function parse_config_file {
  local config_file=${1}
  local cnt=0

  # Define re's for options of interest, the actual validation of the 
  # values are done in validate_*_option-functions. 
  local re_comment="^#.*$"
  local re_empty_lines="^$"
  local re_delay="^DELAY[ ]*="
  local re_file="^FILE[ ]*="
  local re_refreshes="^NUMBER_OF_REFRESHES[ ]*="

  # Read in the configfile and loop every line, 
  while read -r line; do
    cnt=$((cnt+1)) 
    
    # Skip comments and empty lines, 
    [[ ${line} =~ ${re_comment}     ]] && continue
    [[ ${line} =~ ${re_empty_lines} ]] && continue 
    
    # Set the delimiter and read values, 
    IFS='=' read option value <<< "${line}"
    
    # Remove quotes, and leading/trailing spaces, 
    value=${value//\"}
    value=${value//\'}
    value="${value##*( )}" 
    value="${value%%*( )}"

    # If a line matches, first check if value already been specified 
    # (by cli-opt), if not, validate value (and set it if validated), 
    if [[ ${line} =~ ${re_delay} ]]; then
      [[ ${g_option_d} ]] && continue
      validate_d_option "${option}" "${value}"
    
    elif [[ ${line} =~ ${re_file} ]]; then
      [[ ${g_option_f} ]] && continue
    
      # Seriously, you actually need to glob the path to the output-file ? 
      # Nope, not going to happen. 
      if [[ $value =~ \* ]];
      then
        err_msg="Error parsing option '${line}' in '${config_file}' on line ${cnt}
                 (globbing is output-file-name is not allowed, specify full path)."
        error "${err_msg}"
      fi
      validate_f_option "${option}" "${value}"
    
    elif [[ ${line} =~ ${re_refreshes} ]]; then
      [[ ${g_option_n} ]] && continue
      validate_n_option "${option}" "${value}"
    else
      err_msg="Error parsing option '${line}' in '${config_file}' on line ${cnt}"
      error "${err_msg}"
    fi
  done < "${config_file}"
} 



# A function that used to validate the value given to the c-option
#
# Arguments, 
# - A string containing the option-name 
# - A string containing the value to validate 
#
# Returns, 
# - Function doesn't "return" in that sense, 
# - "errors-out" if value doesn't gets validated 
#
function validate_c_option {
  local opt=${1}
  local val_to_validate="${2}"
  
  # echo "$val_to_validate"

  # Check if config exists, 
  if [[ ! -f "${val_to_validate}" ]];then 
    err_msg="Configuration-file '${val_to_validate}' doesn't seem to exist
						(or atleast is not readable by current user ['${USER}'])."
    error "${err_msg}"
  fi
  
  g_option_c="${val_to_validate}"
}



# A function that used to validate the value given to the d-option
#
# Arguments, 
# - A string containing the option-name 
# - A string containing the value to validate 
#
# Returns, 
# - Function doesn't "return" in that sense, 
# - "errors-out" if value doesn't gets validated 
#
function validate_d_option {
  local opt=${1}
  local val_to_validate=${2}

  local threshold_max_delay=120 # Doesn't seem to make sense to specify an 
                                # update every two minutes,
  
  # Check so it's a positive number, 
  if ! is_number_and_not_zero "${val_to_validate}"; then
    err_msg="Option '${opt}' should be followed by a positive number
						(not '${val_to_validate}')."
    error "${err_msg}"
  fi

  # Doesn't make sense to make refresh this rarely,
  if [[ "${val_to_validate}" -gt "${threshold_max_delay}" ]]; then
    err_msg="Option '${opt}' should be reasonable (shorter than 120 seconds). It
						just doesn't make sense to refresh the screen this rarely."
    error "${err_msg}"
  fi

  # Value is verified, set variable, 
  g_option_d="${val_to_validate}"
} 



# A function that used to validate the value given to the f-option
#
# Arguments, 
# - A string containing the option-name 
# - A string containing the value to validate 
#
# Returns, 
# - Function doesn't "return" in that sense, 
# - "errors-out" if value doesn't gets validated 
#
function validate_f_option {
  local opt="${1}"
  local val_to_validate="${2}"
  local error="" 
  local x=""
  
  # First off, figure out what we are dealing with, extract dir/file-name 
  # according to the dirname-command assumptions - we use the dirname-command
  # here and not shell-inbuilt-functionality (substr/globbing) since parsing a
  # dirname isn't always that easy, the dirname-command has already figured 
  # that out for us. 
  dir=$(dirname "${val_to_validate}" 2>&1) 
  
  # Check the return, I seriously don't know when then dirname-command could 
  # fail us, but always check for the return-code.
  if [[ $? -ne 0 ]]; then
    err_msg="Couldn't read dirname from '${val_to_validate}' (${dir})."
    error "${err_msg}"
  fi

  # So, we got a dirname from the -f parameter, just check if it's only a 
  # dirname given,
  dir_end_re="/$"
  if [[ "${val_to_validate}" =~ ${dir_end_re} ]]; then
    err_msg='-f must have a filename as parameter and not a directory
						('${val_to_validate}').'
    error "${err_msg}"
  fi
  
  # If the given directory doesn't exist, try to create it for the user, 
  # bail out if that fails. 
  if [[ ! -d "${dir}" ]]; then
    out=$(mkdir -p "${dir}" 2>&1)

    if [[ $? -ne 0 ]]; then
      err_msg="Directory '${dir}' doesn't seem to exist, and couldn't be created
							('${out}')."
      error "${err_msg}"
    fi
  fi 
  
  # Test if we can create and write to the file (or whatever the user has given
  # us). Now the redirection is done by the shell before printf runs, so we need
  # to redirect stderr not only for the printf-builtin, but to the whole shell 
  # in which the command runs. We do this by encapsulate the printf-builtin in 
  # {}. By using a builtin-command, we can skip a dependency to for eg. the 
  # 'touch-command'. 
  out=$({ printf "" >> "${val_to_validate}"; } 2>&1)
  if [[ $? -ne 0 ]]; then
    err_msg="Couldn't create output-file '${val_to_validate}' ($(strip_error "${out}"))."
    error "${err_msg}"
  fi

  # Value is verified, set variables,
  g_option_f="${val_to_validate}"
}



# A function that used to validate the value given to the n-option
#
# Arguments, 
# - A string containing the option-name 
# - A string containing the value to validate 
#
# Returns, 
# - Function doesn't "return" in that sense, 
# - "errors-out" if value doesn't gets validated 
#
function validate_n_option {
  local opt=${1}
  local val_to_validate=${2}
  local threshold_max_refreshes=7 # Note that this is the *length* of the 
                                  # string, not the actual number itself, 
  
  # Check so it's a positive number, 
  if ! is_number_and_not_zero ${val_to_validate}; then
    err_msg="Option '${opt}' should be followed by a positive number
						(not '${val_to_validate}')."
    error "${err_msg}"
  fi

  # Exit if the value seems unreasonable high, 
  if [[ ${#val_to_validate} -ge ${threshold_max_refreshes} ]]; then
    err_msg="Option '${opt}' should be reasonable (shorter than
						${threshold_max_refreshes}). If you want an value this high, skip 
						this parameter as the script then will refresh forever."
    error "${err_msg}"
  fi

  # Value is verified, set variable, 
  g_option_n="${val_to_validate}"
} 



# A function to check necessary binaries. Even though this script is packaged 
# with rpm and dependencies should be met, I always tend to be extra careful 
# when it comes to this. I've worked with ~150 users for a couple of years now
# and you never know what they do with their clients. 
# Lets be sure that we can find at least the essentials, 
#
# Arguments, 
# - Function doesn't take any argument.
#
# Returns,
# - Function doesn't "return" in that sense, 
# 
function check_necessary_binaries {
  local binaries_needed=("cat"
                         "sed"
                         "date"
                         "dirname"
                         "mkdir"
                         "tput"
                         "ss");

  # Just loop the list and test if we can find the binary, 
  for binary in ${binaries_needed[@]}; do
    if ! hash ${binary} 2>/dev/null; then
      error "Could not find ${binary} in PATH ($PATH)"
    fi
  done
}



# A "wrapper-function" that will just test if an variable is set and print
# out an appropriate error if it is. 
#
# Arguments, 
# - A string containing the variable to test, 
#
# Returns,
# - Function doesn't "return" in that sense, 
# - "errors out" if errors are found in config-file
#
function is_opt_set {
  opt_set=${1}
  
  # Give a clear message to the user that the option already been set, 
  if [[ ${opt_set} ]]; then 
    err_msg="Option '${opt_set}' is already set, you can only set the '${opt_set}'
             parameter once."
    error "${err_msg}"
  fi
} 



# A function that will print an error and exit, no more no less.
#
# Arguments, 
# - A message to be printed. 
#
# Returns,
# - Function doesn't "return" in that sense, 
# 
function error {
  local message=${1}
  IFS=$'\t\n'
  echo -e "\nError :" ${message} "\n" >&2 
  exit 1
} 



# A function that will calculate the difference between "now" and
# and the input-parameter. 
#
# Arguments, 
# - A string containing the seconds you want to compare 
#
# Returns,
# - A string that contains the difference between the input string and "now", in
#   seconds. 
#
function calculate_time_diff {
  local time_fd_modified=${1}
  local time_current=$(date +%s)
  local time_diff=$((time_current - time_fd_modified))
  echo ${time_diff}
}



# A function that determine if the user is root or not. 
#
# Arguments, 
# - Function doesn't take any argument.
#
# Returns,
# - 0 if you are root,  
# - 1 if you aren't root
#
function is_root { 
  [[ "$(whoami)" == "root" ]] && return 0
  return 1
}



# A "wrapper_function" for printf. If the -f-option is specified we print to 
# that instead of stdout. 
#
# Arguments, 
# - An array of strings that should be printed, 
#
# Returns,
# - Function doesn't "return" in that sense, 
# 
function printf_wrapper {
  if [[ ${g_option_f} ]]; then
    printf "${@}" >> "${g_option_f}"
  else
    printf "${@}"
  fi
} 



# A function that will determine if the width of the terminal is enough.  
#
# Arguments, 
# - An string width a width 
#
# Returns,
# - 0 if terminal is determined to be wide enough, 
# - 1 if terminal is determined to be to small, 
#
function terminal_is_wide_enough {
  local padding="75"
  local term_width=$(tput cols)
  local outputwidth=$((${1}+${padding}))
  [[ ${term_width} -lt ${outputwidth} ]] && return 1
  return 0 
}



# A function that will show a "warning/tip" to the user. 
#
# Arguments, 
# - A message to show, 
#
# Returns, 
# - Function doesn't "return" in that sense, 
#
function show_warning {
  local msg=${1}
  local timeout=6
  echo -e ${msg}
  for ((sec = ${timeout} - 1; sec >= 0; sec--));do 
    echo "Will show output in ${sec} seconds."
    sleep 1
    tput cuu1 
    tput el
  done
}



# A function that used to "strip" an error message gotten from a 
# "system/command-call $(command). 
#
# Arguments, 
# - A string containing the error-message to strip
#
# Returns,
# - A string containing the actual error
#
function strip_error {
  local message=${1}
  local x
  local err
  IFS=':' read x x x err  <<< "${message}"
  echo ${err/ /} 
}



# A function that used to show the 'help-screen'. 
#
# Arguments, 
# - Function doesn't take any argument.
#
# Returns,
# - Function doesn't "return" in that sense, just exits.
#
function show_usage {
  cat <<-End-of-message
	
  USAGE: ${0} [OPTIONS] 
  ---------------------------------

  Available Options,             Default            Min              Max
  -c | --config-file                -                -                -
  -d | --delay                      1                1               120 
  -n | --number-of-refreshes     Infinite            1             No limit  
  -f | --output-file             stdout              -                -

  See 'man ${0/.\//}' for more information. 

	End-of-message

  exit 0 
}



# A function that will create the "=" around the top-header, 
#
# Arguments, 
# - Functions doesn't take an argument. 
#
# Returns, 
# - Function doesn't "return" in that sense, 
#
function create_top_bottom_header {
  header_width=$(tput cols)  
  for ((x = 0; x < ${header_width}; x++));do 
    printf_wrapper "="
  done
  printf_wrapper "\n"
} 



# A function that determine if the user is root or not. 
#
# Arguments, 
# - Function doesn't take any argument.
#
# Returns,
# - 0 if string is digits and not starting with a 0 
# - 1 if string is anything else than above
#
function is_number_and_not_zero {
  local val_to_validate=${1}
   
  [[ $val_to_validate =~ $g_re_digits ]] && return 0 

  return 1
}


 






# * * * * * * * * * * * *
# Main start, 
#

# Check for needed binaries, 
check_necessary_binaries

# Parse the command-line, 
parse_command_line "$@"

# If an config-file is given, parse the values in there, 
if [[ ${g_opt_c_set} ]]; then
  parse_config_file "${g_option_c}"
fi

# Set options to defaults if not specified, 
g_option_d=${g_option_d:-${g_option_d_default}} 
g_option_n=${g_option_n:-${g_option_n_default}} 

# This variable is "static" in the sense that we do not alter it, 
g_option_n_static=${g_option_n}

# If the n-option is not set, make sure we refresh the interface 
# forever. That is taken care of by the g_option_n_forever-parameter. 
if [[ ${g_option_n} == "not_set" ]];then
  g_option_n=1
  g_option_n_forever=1
fi

# Save screen, 
if [[ ! ${g_option_f} ]]; then
  tput smcup
fi

# Just loop here until given conditions are true, 
while [[ ${g_cnt} -le ${g_option_n} ]]; do
  
  # Get the data to print, 
  get_output_from_ss 
  
  # Print the actual data, 
  print_data
  
  # Refresh at rate, min 1 sec, 
  sleep ${g_option_d}

  # Only run as many times as specified, 
  if [[ ${g_option_n_forever} -ne 1 ]]; then
    g_cnt=$((g_cnt+1)) 
  fi

  # Set global "state"
  g_first_run="0"
done

# Restore screen and exit, 
if [[ ! ${g_option_f} ]]; then
  tput rmcup
fi

exit 0 
