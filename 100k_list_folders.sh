#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF

Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] base_folder_id

List folders recursively from a base folder.

Positional arguments:
  base_folder_id   The id of the base folder to list.

Available options:
-h, --help      Print this help and exit
-v, --verbose   Print script debug info

EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1

  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  force=0
  param=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    # -f | --force) force=1 ;; # example flag
    # -p | --param) # example named parameter
    #   param="${2-}"
    #   shift
    #   ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
#   [[ -z "${param-}" ]] && die "Missing required parameter: param"
  [[ ${#args[@]} -eq 0 ]] && msg "Missing base folder id" && usage

  return 0
}

####################  Helpers  ####################

box_folder_check() {
    local folder_id=$1
    local output
    
    output=$(box folders:get $folder_id --csv --fields type,id,name | grep -i ",$folder_id,") || echo ""
    if [[ -z "$output" ]]; then
        die "Folder $folder_id not found"
    fi

    type=$(echo $output | cut -d, -f1)
    name=$(echo $output | cut -d, -f3)
    if [[ -n "$type" && "$type" != "folder" ]]; then
        die "... Error\nThe provided id is not a folder."
    fi
    echo "$name"
}

box_folder_list(){
    local parent_folder_id=$1
    local parent_folder_name=$2
    local output_file_name=$3
    local level=$4
    
    box folders:items $parent_folder_id --csv --fields type,id,name,parent | while read -r line; do
        type_name=$(echo "$line" | cut -f1 -d,)
        folder_id=$(echo "$line" | cut -f2 -d,)
        folder_name=$(echo "$line" | cut -f3 -d,)
        parent_id=$(echo "$line" | cut -f5 -d,)
        
        if [ "$type_name" == "folder" ]
        then
            echo "Folder: $folder_name"
            echo $parent_id,$level,$type_name,$folder_id,$folder_name >> $output_file_name
            if [ $level -lt 1 ]
            then
                box_folder_list "$folder_id" "$folder_name" "$output_file_name" "$((level+1))"
            fi
        fi
    done 
}

####################  Main script  ####################

parse_params "$@"
setup_colors

base_folder_id="${args[0]}"


# Check if base folder exists
echo -n "Checking for base folder $base_folder_id"
base_folder_name=$(box_folder_check "$base_folder_id")
[[ -z "$base_folder_name" ]] && echo ", not found" || echo ", found as $base_folder_name."

output_file_name=tree_"$base_folder_name".csv

# List folders recursively
echo "Listing folders recursively from $base_folder_name ($base_folder_id)"
echo parent_id,level,type,id,name > $output_file_name
box_folder_list "$base_folder_id" "$base_folder_name" "$output_file_name" 0   


# search example
# box search topic --content-types name --type folder --all --csv --fields type,id,name,parent
# list items w/ parent
# box folders:items 178230999536 --csv --fields type,id,name,parent

# msg "${RED}Read parameters:${NOFORMAT}"
# msg "- force: ${force}"
# msg "- param: ${param}"
# msg "- base folder: ${args[*]-}"
