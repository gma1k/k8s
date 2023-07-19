#!/usr/bin/env bash

docker volume ls -qf dangling=true | xargs --no-run-if-empty docker volume rm
