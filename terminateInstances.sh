#!/bin/bash
#
# Terminate currently running instances in coreos cluster
# Version 0.0.1
#
# Run ./terminateInstances.sh -h for usage information
#
#include helpers
source "./_common.sh"

### Script logic
#####################################################################

version="v0.0.1"

# Print usage
usage() {
  echo -n "$(basename $0) [OPTION]... 

Terminate currently running instances in coreos cluster

Options:
  -g, --group     Filter by cluster security group [default: coreosgroup]
  -r, --region    Filter by region, comma seperate multiple regions 
                  e.g. 'us-east-1, us-west-1' [default: all regions]

  -s, --skip-aws-checks    Skip checking if aws cli is installed
  -h, --help        Display this help and exit
      --version     Output version information and exit
"
}

# Set a trap for cleaning up in case of errors or when script exits.
rollback() {
  die
}

main() {
  if [ "$regions" == "all" ]; then
    regions=(eu-central-1 sa-east-1 ap-northeast-1 eu-west-1 us-east-1 us-west-1 us-west-2 ap-southeast-2 ap-southeast-1)
  else
    regions=($(echo "$regions" | tr -d '[[:space:]]' | tr "," "\n" ))
  fi

  regionLength=${#regions[@]}

  if [ $regionLength -gt 1 ]; then
    printf "%s\n" "${regions[@]}" | xargs -n 1 -P "$regionLength" ./$0 -s "true" -g "$securitygroup" -r 
  else
    aws --region "$regions" ec2 describe-instances --filters "Name=group-name,Values=${securitygroup}" "Name=instance-state-name,Values=running" --output text | cut -s -f 8 | sed '/^$/d' | xargs aws --region "$regions" ec2 terminate-instances --instance-ids
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
securitygroup="coreosgroup"
regions="all"
skip_aws_checks=false

while [[ $1 = -?* ]]; do
  case $1 in
    -h|--help) usage >&2; safe_exit ;;
    --version) out "$(basename $0) $version"; safe_exit ;;
    -g|--group) shift; securitygroup=$1 ;;
    -r|--region) shift; regions=$1 ;;
    -s|--skip-aws-checks) shift; skip_aws_checks=true ;;
    --endopts) shift; break ;;
  esac
  shift
done

# Store the remaining part as arguments.
args+=("$@")

### Run it
#####################################################################

if ! [ $skip_aws_checks == true ]; then
  check_aws_cli
fi

main

safe_exit
