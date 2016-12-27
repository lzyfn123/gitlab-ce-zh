#!/bin/bash

if [[ -z "${DOCKER_USERNAME}" ]]; then
    DOCKER_USERNAME=twang2218
fi

generate_branch_dockerfile() {
    TAG=$1
    VERSION=$2
    BRANCH=$3
    cat ./template/Dockerfile.branch.template | sed "s/{TAG}/${TAG}/g; s/{VERSION}/${VERSION}/g; s/{BRANCH}/${BRANCH}/g"
}

generate_tag_dockerfile() {
    TAG=$1
    VERSION=$2
    cat ./template/Dockerfile.tag.template | sed "s/{TAG}/${TAG}/g; s/{VERSION}/${VERSION}/g;"
}

generate_readme() {
    TAG_8_11=$1
    TAG_8_12=$2
    TAG_8_13=$3
    TAG_8_14=$4
    TAG_8_15=$5
    TAG_LATEST=$TAG_8_15
    cat ./template/README.md.template \
        | sed "s/{TAG_8_11}/${TAG_8_11}/g; s/{TAG_8_12}/${TAG_8_12}/g; s/{TAG_8_13}/${TAG_8_13}/g; s/{TAG_8_14}/${TAG_8_14}/g; s/{TAG_8_15}/${TAG_8_15}/g; s/{TAG_LATEST}/${TAG_LATEST}/g;"
}

check_build_publish() {
    BRANCH=$1
    TAG=$2

    # If the TAG is empty, then use BRANCH name as TAG name for image
    if [[ -z "${TAG}" ]]; then
        TAG=${BRANCH}
    fi

    FILES=$(git show --stat HEAD~1 | grep '|' | cut -d' ' -f2)
    if (echo "${FILES}" | grep -q ${BRANCH}); then
        echo "${BRANCH} has been updated, need rebuild ${DOCKER_USERNAME}/gitlab-ce-zh:${TAG} ..."

        docker build -t "${DOCKER_USERNAME}/gitlab-ce-zh:${TAG}" ${BRANCH}
        if [[ -n "${DOCKER_PASSWORD}" ]]; then
            echo "Publish image '${DOCKER_USERNAME}/gitlab-ce-zh:${TAG}' to Docker Hub ..."
            docker login -u "${DOCKER_USERNAME}" -p "${DOCKER_PASSWORD}"
            docker push "${DOCKER_USERNAME}/gitlab-ce-zh:${TAG}"
        fi
    else
        echo "Nothing changed in ${BRANCH}."
    fi
}

branch() {
    if [ "$#" != "3" ]; then
        echo "Usage: $0 branch <image-tag> <version-tag> <branch>"
        echo ""
        echo "  e.g. $0 branch 8.15.0-ce.0 v8.15.0 8-15-stable-zh"
        exit 1
    fi
    TAG=$1
    VERSION=$2
    BRANCH=$3

    Dockerfile=$(generate_branch_dockerfile ${TAG} ${VERSION} ${BRANCH})
    echo "$Dockerfile"
    echo "$Dockerfile" | docker build -t "${DOCKER_USERNAME}/gitlab-ce-zh:${BRANCH}" -
    echo ""
    echo "List of available images:"
    docker images ${DOCKER_USERNAME}/gitlab-ce-zh
}

tag() {
    if [ "$#" != "2" ]; then
        echo "Usage: $0 tag <image-tag> <version-tag>"
        echo ""
        echo "  e.g. $0 tag 8.15.0-ce.0 v8.15.0"
        exit 1
    fi
    TAG=$1
    VERSION=$2

    Dockerfile=$(generate_tag_dockerfile ${TAG} ${VERSION})
    echo "$Dockerfile"
    echo "$Dockerfile" | docker build -t "${DOCKER_USERNAME}/gitlab-ce-zh:${VERSION:1}" -
    echo ""
    echo "List of available images:"
    docker images ${DOCKER_USERNAME}/gitlab-ce-zh
}

generate() {
    generate_branch_dockerfile  8.11.11-ce.0    v8.11.11    8-11-stable-zh  > 8.11/Dockerfile
    generate_tag_dockerfile     8.12.13-ce.0    v8.12.13    v8.12.13-zh     > 8.12/Dockerfile
    generate_tag_dockerfile     8.13.10-ce.0    v8.13.10    v8.13.10-zh     > 8.13/Dockerfile
    generate_tag_dockerfile     8.14.5-ce.0     v8.14.5     v8.14.5-zh      > 8.14/Dockerfile
    generate_tag_dockerfile     8.15.1-ce.0     v8.15.1     v8.15.1-zh      > 8.15/Dockerfile
    generate_branch_dockerfile  8.15.1-ce.0     v8.15.1     8-15-stable-zh  > testing/Dockerfile

    generate_readme \
        8.11.11 \
        8.12.13 \
        8.13.10 \
        8.14.5 \
        8.15.1 \
        > README.md
}

ci() {
    env | grep TRAVIS
    if [[ "${TRAVIS_BRANCH}" == "master" ]]; then
        check_build_publish 8.11
        check_build_publish 8.12
        check_build_publish 8.13
        check_build_publish 8.14
        check_build_publish 8.15
        check_build_publish testing
    elif [[ -n "${TRAVIS_TAG}" ]]; then
        MINOR_VERSION=$(echo "${TRAVIS_TAG}" | cut -d'.' -f2)
        BRANCH="8.${MINOR_VERSION}"
        check_and_build "${BRANCH}" "${TRAVIS_TAG:1}"
    else
        echo "Not in CI."
    fi

    if [[ -n "${DOCKER_TRIGGER_LINK}" ]]; then
        echo "Triggering the 'latest' build ..."
        curl -s -H "Content-Type: application/json" --data '{"docker_tag": "latest"}' -X POST "${DOCKER_TRIGGER_LINK}"
    fi

    docker images "${DOCKER_USERNAME}/gitlab-ce-zh"
}

run() {
    if [ "$#" != "1" ]; then
        echo "Usage: $0 run <image-tag>"
        echo ""
        echo "List of available images:"
        docker images ${DOCKER_USERNAME}/gitlab-ce-zh
        exit 1
    fi
    TAG=$1
    set -xe
    docker run -d -P ${DOCKER_USERNAME}/gitlab-ce-zh:${TAG}
    docker ps
}

main() {
    Command=$1
    shift
    case "$Command" in
        branch)     branch "$@" ;;
        tag)        tag "$@" ;;
        generate)   generate ;;
        run)        run "$@" ;;
        ci)         ci ;;
        *)          echo "Usage: $0 <branch|tag|generate|run|ci>" ;;
    esac
}

main "$@"