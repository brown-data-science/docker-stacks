#!/bin/bash

# Builds and pushes a given image to gcr.io + all nodes in current kubectl
# context

set -e

DOCKER_REPO=""
DOCKER_PUSH="docker push"
FORCE=False
NAMED_TAG="latest"

usage() {
	echo "Usage:"
	echo "     -h – help"
	echo "     -r – Repository"
	echo "     -t – Tag e.g., fall-19"
	echo "     -f – Force build";
}

while getopts h:r:t:f opt; do
    echo $opt
	case "${opt}" in
		f) FORCE=True;;
		r) DOCKER_REPO={$OPTARG};;
		t) NAMED_TAG={$OPTARG};;
		h) usage; exit;;
	esac
done
shift $((OPTIND-1))

# Bail if we're on a dirty git tree
echo "Force Build? $FORCE"
if ! $FORCE; then
	if ! git diff-index --quiet HEAD; then
		echo "You have uncommited changes. Please commit them before building and"
		echo "populating. This helps ensure that all docker images are traceable"
		echo "back to a git commit."
		exit 1
	fi
fi

IFS='-' read -r -a images <<< "$1"

GIT_REV=$(git log -n 1 --pretty=format:%h)
TAG="${GIT_REV}"

for index in "${!images[@]}"
do
    IMAGE=${images[0]}

	for (( j=1; j<=$index; j++ )) 
	do
		IMAGE="${IMAGE}-${images[j]}"
	done
	
	echo "Building $IMAGE"
	if [ ! -f ${IMAGE}/Dockerfile ]; then
		echo "No such file: ${IMAGE}/Dockerfile"
		exit 1
	fi

	IMAGE_NAME=jupyterhub-${IMAGE}
	IMAGE_SPEC="${DOCKER_REPO}/${IMAGE_NAME}:${TAG}"
	docker build -f ${IMAGE}/Dockerfile -t ${IMAGE_SPEC} .
	${DOCKER_PUSH} ${IMAGE_SPEC}
	echo "Pushed ${IMAGE_SPEC}"

	# Create latest tag
	docker tag ${DOCKER_REPO}/${IMAGE_NAME}:${TAG} ${DOCKER_REPO}/${IMAGE_NAME}:${NAMED_TAG}
	docker push ${DOCKER_REPO}/${IMAGE_NAME}:latest

done

