#!/bin/bash

# - install depends tools
# yum -y install libcurl-devel
#

rm -rf build
mkdir -p build
pushd build

cmake -DCMAKE_BUILD_TYPE=relwithdebinfo ..
cmake --build . --config relwithdebinfo

popd

# popd

# echo continue && read -n 1
