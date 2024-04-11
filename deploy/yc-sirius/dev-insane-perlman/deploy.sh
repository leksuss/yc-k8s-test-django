#!/bin/bash

VERSION=$(git rev-parse --short HEAD)
if [[ -n $1 ]]; then
    VERSION=$1
fi

REPO="leksuss/django-site:"
TAG="$REPO$VERSION"
LATEST="${REPO}latest"
BUILD_TIMESTAMP=$( date '+%F_%H:%M:%S' )
docker build -t "$TAG" -t "$LATEST" --build-arg VERSION="$VERSION" --build-arg BUILD_TIMESTAMP="$BUILD_TIMESTAMP" ../../../backend_main_django/
docker push "$TAG"
docker push "$LATEST"