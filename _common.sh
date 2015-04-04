#!/bin/bash

# Detect whether output is piped or not.
[[ -t 1 ]] && piped=0 || piped=1

# Defaults
quiet=0
verbose=0
args=()

### Helpers
#####################################################################

out() {
  ((quiet)) && return

  local message="$@"
  if ((piped)); then
    message=$(echo $message | sed '
      s/\\[0-9]\{3\}\[[0-9]\(;[0-9]\{2\}\)\?m//g;
      s/✖/Error:/g;
      s/✔/Success:/g;
    ')
  fi
  printf '%b\n' "$message";
}
die() { out "$@"; exit 1; } >&2
err() { out " \033[1;31m✖\033[0m  $@"; } >&2
success() { out " \033[1;32m✔\033[0m  $@"; }

# Verbose logging
log() { (($verbose)) && out "$@"; }

# Notify on function success
notify() { [[ $? == 0 ]] && success "$@" || err "$@"; }

# Escape a string
escape() { echo $@ | sed 's/\//\\\//g'; }

# A non-destructive exit for when the script exits naturally.
safe_exit() {
  trap - INT TERM EXIT
  exit
}

check_aws_installed() {
  err_msg="The aws command line client is required to use these bash scripts. 
  Run 'pip install awscli'
  or see https://github.com/aws/aws-cli for more information."
  hash aws 2>/dev/null || die "$err_msg"
}

check_aws_setup() {
  aws ec2 describe-regions > /dev/null 2> /dev/null
  aws_out=$?
  if [ $aws_out -ne 0 ]; then
    die "Run 'aws configure' to setup your access details first."
  fi
}

check_aws_cli() {
  check_aws_installed
  check_aws_setup
}
