#!/bin/bash
# TEMP: phase-2 test — deliberate shellcheck failure (unquoted vars). Delete after.
result=$(ls $HOME)
echo $result
