#!/bin/bash

set -euo pipefail

###############################################################################

declare -r GH_API_BASE_URL="https://api.github.com/repos"
declare -r GH_OWNER_REPO_REGEXP='^git\@github\.com\:(.*)\.git$'
declare -r DEFAULT_BASE_BRANCH='master'
declare -r PIPELINE_FILE='.buildkite/pipeline.yml'
declare -r MODULAR_ROOTS=(gems)

###############################################################################

function print_main_steps {
  cat $PIPELINE_FILE
}

function print_dir_steps {
  local dir="$1"
  cat "$dir/$PIPELINE_FILE" | sed '1 d'
}

function print_skip_steps {
  echo "  - label: \":point_up: Skip $1\""
  echo "    command: \"true\""
}

function print_error_steps {
  local error=$(echo "$1" | base64)
  cat<<YAML
steps:
  - label: ":skull_and_crossbones:"
    commands:
      - "echo \"${error}\" | base64 -d"
      - "false"
YAML
}

function gh_api_request {
  local url="$GH_API_BASE_URL/$GH_OWNER_REPO/$1"
  local response=$(
    curl -s \
    -H "Authorization: token ${GH_TOKEN}" \
    -w "%{http_code}" \
    -X GET "$url"
  )
  local code=$(echo "$response" | tail -n1)
  local body=$(echo "$response" | sed '$ d')
  if [[ $code != 200 ]]; then
    print_error_steps "GH API ERROR: url=$url code=$code body=$body"
    exit 0
  fi
  _result="$body"
}

function is_path_changed {
  local json="$1"
  local dir="$2"
  echo "$json" | jq "first(.files[] | select(.filename | startswith(\"$dir\"))) | any"
}

###############################################################################

# declare owner/repo pair
if [[ ${BUILDKITE_REPO} =~ $GH_OWNER_REPO_REGEXP ]]; then
  declare -r GH_OWNER_REPO="${BASH_REMATCH[1]}"
else
  print_error_steps "Can't parse BUILDKITE_REPO=${BUILDKITE_REPO}"
  exit 0
fi

# declare base branch
if [[ -n "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" ]]; then
  declare -r base_branch="$BUILDKITE_PULL_REQUEST_BASE_BRANCH"
else
  declare -r base_branch="$DEFAULT_BASE_BRANCH"
fi

# declare current branch
declare -r current_branch="$BUILDKITE_BRANCH"

# enforce_changed if current branch is base one
if [[ "$current_branch" == "$base_branch" ]]; then
  declare -r enforce_changed=true
else
  declare -r enforce_changed=false
fi

# general retun from functions
declare _result

###############################################################################

# perform GH compare request
if [[ $enforce_changed == false ]]; then
  gh_api_request "compare2/$base_branch...$current_branch"
  compare_json="$_result"
fi

# print main steps
print_main_steps

for root in ${MODULAR_ROOTS[@]}; do
  for path in $root/*; do
    if [[ $enforce_changed == true ]]; then
      dir_changed=true
    else
      dir_changed=$(is_path_changed "$compare_json" "$path")
    fi

    if [[ $dir_changed == true ]]; then
      # print dir steps
      print_dir_steps "$path"
    else
      # print skip steps
      print_skip_steps "$path"
    fi
  done
done
