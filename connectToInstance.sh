#!/bin/bash
#
# Quickly connect to one of the instances listed by listInstances.sh
# Version 0.0.1
#
# Run ./listInstances.sh -h for usage information
#
#include helpers
source "./_common.sh"

### Script logic
#####################################################################

version="v0.0.1"

# Print usage
usage() {
  echo -n "$(basename $0) [OPTION]... 

Quickly connect to one of the instances listed by listInstances.sh

Options:
  -i, --index     Which instance in list to connect to [default: 1]
  -k, --key       Path to private key to authenticate with [default: ~/.ssh/CoreOSKey_rsa]
  -g, --group     Security group to filter listInstances.sh with [default: coreosgroup]

  -h, --help        Display this help and exit
      --version     Output version information and exit
"
}

# Set a trap for cleaning up in case of errors or when script exits.
rollback() {
  die
}

main() {
  instances=$(./listInstances.sh -g "$securitygroup")
  if [ -z "$instances" ]; then
    die "No instances found."
  else
    eval keypath=$keypath
    instanceIp=$(echo "$instances" | sed -n "${index}p" | cut -f2 | tr -d "[[:space:]]")
    ssh -o StrictHostKeyChecking=no -i "$keypath" "core@${instanceIp}"
  fi
}

### Boilerplate
#####################################################################

# Iterate over options breaking -ab into -a -b when needed and --foo=bar into
# --foo bar
optstring=h
unset options
while (($#)); do
  case $1 in
    # If option is of type -ab
    -[!-]?*)
      # Loop over each character starting with the second
      for ((i=1; i < ${#1}; i++)); do
        c=${1:i:1}

        # Add current char to options
        options+=("-$c")

        # If option takes a required argument, and it's not the last char make
        # the rest of the string its argument
        if [[ $optstring = *"$c:"* && ${1:i+1} ]]; then
          options+=("${1:i+1}")
          break
        fi
      done
      ;;
    # If option is of type --foo=bar
    --?*=*) options+=("${1%%=*}" "${1#*=}") ;;
    # add --endopts for --
    --) options+=(--endopts) ;;
    # Otherwise, nothing special
    *) options+=("$1") ;;
  esac
  shift
done
set -- "${options[@]}"
unset options

# Set our rollback function for unexpected exits.
trap rollback INT TERM EXIT

### Main loop
#####################################################################

# Read the options and set stuff
index="1"
keypath="~/.ssh/CoreOSKey_rsa"
securitygroup="coreosgroup"

while [[ $1 = -?* ]]; do
  case $1 in
    -h|--help) usage >&2; safe_exit ;;
    --version) out "$(basename $0) $version"; safe_exit ;;
    -i|--index) shift; index=$1 ;;
    -k|--key) shift; keypath=$1 ;;
    -g|--group) shift; securitygroup=$1 ;;
    --endopts) shift; break ;;
  esac
  shift
done

# Store the remaining part as arguments.
args+=("$@")

### Run it
#####################################################################

main

safe_exit
