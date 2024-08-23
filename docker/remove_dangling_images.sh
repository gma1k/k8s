#!/bin/bash

set -eu

# List dangling Docker images
list_dangling_images() {
    docker images --quiet --filter=dangling=true
}

# Remove dangling images
remove_dangling_images() {
    local image_ids="$1"
    if [ -n "$image_ids" ]; then
        echo "Removing dangling images..."
        echo "$image_ids" | xargs --no-run-if-empty docker rmi
    else
        echo "No dangling images found."
    fi
}
