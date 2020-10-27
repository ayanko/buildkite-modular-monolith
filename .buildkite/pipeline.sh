#!/bin/bash

# call actual script and collect stderr output as well
output=$(.buildkite/pipeline_script.sh 2>&1)

if [[ $? == 0 ]]; then
  # on success just print output
  echo "$output"
else
  # on failure generate emulated step that print error using base64
  lines=$(echo "$output" | base64)
  echo "steps:"
  echo "  - label: \":skull_and_crossbones:\""
  echo "    commands:"
  for line in $lines; do
    echo "      - \"echo $line >> pipeline.err\""
  done
  echo "      - \"cat pipeline.err | base64 -d\""
  echo "      - \"false\""
fi
