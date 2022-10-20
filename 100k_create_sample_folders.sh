#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF

Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-f] base_folder

Create a folder structure for testing.

Positional arguments:
  base_folder   The name of the base folder to create under the root folder.

Available options:
-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-f, --force     If base folder exists, delete it and recreate it

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
    -f | --force) force=1 ;; # example flag
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
  [[ ${#args[@]} -eq 0 ]] && msg "Missing base folder name" && usage

  return 0
}

box_create_folder() {
    local parent_id=$1
    local folder_name=$2
    local folder_id
    
    folder_id=$(box folders:create "$parent_id" "$folder_name" --id-only 2>/dev/null)
    echo "$folder_id"
}

box_base_folder_create(){
    box_create_folder 0 "$1"
}

box_folder_check() {
    local folder_name=$1
    local folder_id
    local type_name
    folder_id=$(box folders:items 0 --csv --fields id,type,name | grep -i ",$folder_name$" | cut -f2 -d,) || echo ""
    type_name=$(box folders:items 0 --csv --fields id,type,name | grep -i ",$folder_name$" | cut -f1 -d,) || echo ""
    
    if [[ -n "$type_name" && "$type_name" != "folder" ]]; then
        die "... Error\nFound a $type_name named $folder_name.  Please use another base folder name."
    fi
    echo "$folder_id"
}


box_base_folder_delete(){
    local base_folder_id=$1
    box folders:delete "$base_folder_id"
}

parse_params "$@"
setup_colors

base_folder_name="${args[0]}"


# Check if base folder exists
echo -n "Checking for base folder $base_folder_name"
base_folder_id=$(box_folder_check "$base_folder_name")
[[ -z "$base_folder_id" ]] && echo ", not found" || echo ", found with id: $base_folder_id"


# If base folder exists, delete it, only if --force is set
if [[ -n "${base_folder_id-}" ]]; then
    if [[ $force == 0 ]]; then
        die "Base folder exists"
    else
        box_base_folder_delete "$base_folder_id"
    fi
fi


# Create base folder
echo -n "Creating base folder ${args[*]-}"
base_folder_id=$(box_base_folder_create "${args[*]-}")
echo ", created with id: $base_folder_id"


# Create topic sub folders

echo "parent_id,id,type,name" > ./tmp/folders_1.csv
parent_id=$base_folder_id
for i in {0..9}
do
    new_folder_id=$(box folders:create $parent_id Topic_$i --id-only)
    echo "$parent_id,$new_folder_id,folder,Topic_$i" >> ./tmp/folders_1.csv 
    echo "$parent_id,$new_folder_id,folder,Topic_$i"
done


# Create sub folders for each topic
echo "parent_id,id,type,name" > ./tmp/folders_2.csv
while IFS="," read -r c_parent_id c_id c_type c_name
do
    if [ "$c_parent_id" = "parent_id" ]; then
        continue
    fi
    parent_id=$c_id
    for i in {0..9}
    do
        new_folder_id=$(box folders:create $parent_id "$c_name"_"SubTopic_$i" --id-only)
        echo "$parent_id,$new_folder_id,folder,"$c_name"_"SubTopic_$i"" >> ./tmp/folders_2.csv 
        echo "$parent_id,$new_folder_id,folder,"$c_name"_"SubTopic_$i""
    done
done < ./tmp/folders_1.csv



# msg "${RED}Read parameters:${NOFORMAT}"
# msg "- force: ${force}"
# # msg "- param: ${param}"
# msg "- base folder: ${args[*]-}"
