#!/bin/bash
. functions.sh

# COPY PASTE THIS IN JENKINS JOB

# Exit on error
# TODO :
# exit 0 = success
# exit 1 = instable
# exit 2 = failure
set -o errexit
CODE_SUCCESS=0
CODE_FAILURE=1
CODE_INSTABLE=2

# build_dir="$(cd "$1" && pwd)"
# src_dir="$(cd "$2" && pwd)"
# sha=$(git --git-dir="$src_dir/.git" rev-parse HEAD)

# Clean flag files
rm -f "$build_dir/build-started"
rm -f "$build_dir/build-finished"
touch "$build_dir/build-started" # used to detect aborts

## Init
notify-dashboard "platform=$CI_PLATFORM" "compiler=$CI_COMPILER" "options=$CI_OPTIONS" "build_url=$BUILD_URL" "job_url=$JOB_URL"
"$src_dir/scripts/ci/init-build.sh" "$build_dir" "$src_dir"

## Configure
notify-dashboard "status=configure"
"$src_dir/scripts/ci/configure.sh" "$build_dir" "$src_dir"

## Compile
notify-dashboard "status=build"
"$src_dir/scripts/ci/compile.sh" "$build_dir"
if [ $? = $CODE_SUCCESS ]; then
    notify-dashboard "status=success"
elif [ $? = $CODE_FAILURE ]; then
    notify-dashboard "status=fail"
    exit 1 # Build failed
fi

## [Full build] Count Warnings
if [[ -n "$CI_FULL_BUILD" ]]; then
    warning_count=$(count-warnings)
    echo "Counted $warning_count compiler warnings."
    notify-dashboard "fullbuild=true" "warnings=$warning_count"
fi

## Unit tests
if [[ -n "$CI_UNIT_TESTS" ]]; then
    notify-dashboard "tests_status=running"

    "$src_dir/scripts/ci/tests.sh" run "$build_dir" "$src_dir"

    notify-dashboard \
        "tests_total=$("$src_dir/scripts/ci/tests.sh" count-tests $build_dir $src_dir)" \
        "tests_failures=$("$src_dir/scripts/ci/tests.sh" count-failures $build_dir $src_dir)" \
        "tests_disabled=$("$src_dir/scripts/ci/tests.sh" count-disabled $build_dir $src_dir)" \
        "tests_errors=$("$src_dir/scripts/ci/tests.sh" count-errors $build_dir $src_dir)" \
        "tests_suites=$("$src_dir/scripts/ci/tests.sh" count-test-suites $build_dir $src_dir)" \
        "tests_crash=$("$src_dir/scripts/ci/tests.sh" count-crashes $build_dir $src_dir)"
        
    "$src_dir/scripts/ci/tests.sh" print-summary "$build_dir" "$src_dir"
fi

## Scene tests
if [[ -n "$CI_SCENE_TESTS" ]]; then
    notify-dashboard "scenes_status=running"
    
    "$src_dir/scripts/ci/scene-tests.sh" run "$build_dir" "$src_dir"
    
    notify-dashboard \
        "scenes_total=$("$src_dir/scripts/ci/scene-tests.sh" count-tests $build_dir $src_dir)" \
        "scenes_errors=$("$src_dir/scripts/ci/scene-tests.sh" count-errors $build_dir $src_dir)" \
        "scenes_crashes=$("$src_dir/scripts/ci/scene-tests.sh" count-crashes $build_dir $src_dir)"
    
    "$src_dir/scripts/ci/scene-tests.sh" print-summary "$build_dir" "$src_dir"
fi

touch "$build_dir/build-finished" # used to detect aborts
