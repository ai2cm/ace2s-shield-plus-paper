#!/bin/bash

ROOT=$(dirname "$0")
SHiELD_BUILD=${ROOT}/submodules/SHiELD_build

cd ${SHiELD_BUILD}/Build
./COMPILE shield 64bit repro intel
