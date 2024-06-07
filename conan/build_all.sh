#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

CONAN_BASE="${SCRIPT_DIR}"

pkgs=( \
  capicxx-core-runtime \
  vsomeip \
  capicxx-someip-runtime \
  capicxx-generators \
  capicxx-cmake-modules \
  capi-config \
  example-app \
)

# Export the package recipes
for p in ${pkgs[@]}; do
    conan export "${CONAN_BASE}/${p}";
done

# Create the example workspace
cd "${CONAN_BASE}/workspace" && conan install . --build=missing;
