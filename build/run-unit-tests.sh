#!/bin/bash

echo " > Running run-unit-tests.sh"
set -e
export DOCKER_IMAGE_AND_TAG=${1}

pwd
cd ..
make deps
make test
make coverage
make lint

exit 0