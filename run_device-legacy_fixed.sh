#!/bin/bash

# Copyright 2020 Manuel Pöll
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit -o nounset -o pipefail -o xtrace

composeCommandsBuild() {
    cat <<EOF | tr '\n' '; '
( cd "${CONTAINER_RB_AOSP_BASE}/src/.repo/repo" && git checkout "v1.13.9.4" )
"./scripts/build-device/10_fetch-extract-factory-images.sh" "$AOSP_REF" "$BUILD_ID" "$DEVICE_CODENAME" "$DEVICE_CODENAME_FACTORY_IMAGE"
"./scripts/build-device/11_clone-src-device.sh" "$AOSP_REF"
"./scripts/build-device/12_fetch-extract-vendor.sh" "$BUILD_ID" "$DEVICE_CODENAME"
"./scripts/build-device/13_build-device.sh" "$AOSP_REF" "$RB_BUILD_TARGET" "$GOOGLE_BUILD_TARGET"
"./scripts/analysis/18_build-tools.sh"
( cd "${CONTAINER_RB_AOSP_BASE}/src/.repo/repo" && git checkout "default" )
EOF
}

composeCommandsAnalysis() {
    cat <<EOF | tr '\n' '; '
"./scripts/analysis/19_preprocess-imgs.sh" "$AOSP_REF" "$GOOGLE_BUILD_TARGET" "$RB_BUILD_TARGET" "$RB_BUILD_ENV"
"./scripts/analysis/20_diffoscope-files.sh" \
    "${CONTAINER_RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}/${GOOGLE_BUILD_ENV}" \
    "${CONTAINER_RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}/${RB_BUILD_ENV}" \
    "$DIFF_PATH" "device"
"./scripts/analysis/21_generate-diffstat.sh" "$DIFF_PATH" "device"
"./scripts/analysis/22_generate-metrics.sh" "$DIFF_PATH" "device"
"./scripts/analysis/23_generate-visualization.sh" "$DIFF_PATH"
EOF
}

main() {
    # Argument sanity check
    if [[ "$#" -ne 6 ]]; then
        echo "Usage: $0 <AOSP_REF> <BUILD_ID> <DEVICE_CODENAME> <DEVICE_CODENAME_FACTORY_IMAGE> <RB_BUILD_TARGET> <GOOGLE_BUILD_TARGET>"
        echo "AOSP_REF: Branch or Tag in AOSP, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds , e.g. android-5.1.1_r37"
        echo "BUILD_ID: version of AOSP, corresponds to a tag, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds , e.g. LMY49J"
        echo "DEVICE_CODENAME: Internal code name for device, see https://source.android.com/setup/build/running#booting-into-fastboot-mode for details. , e.g. manta"
        echo "DEVICE_CODENAME_FACTORY_IMAGE: Alternative internal code name for device, see https://developers.google.com/android/images for details, e.g. mantaray"
        echo "RB_BUILD_TARGET: Tuple of <BUILD>-<BUILDTYPE>, see https://source.android.com/setup/build/building#choose-a-target for details, e.g. manta-user"
        echo "GOOGLE_BUILD_TARGET: Tuple of <BUILD>-<BUILDTYPE>, see https://source.android.com/setup/build/building#choose-a-target for details, e.g. aosp_manta-user"
        exit 1
    fi
    local -r AOSP_REF="$1"
    local -r BUILD_ID="$2"
    local -r DEVICE_CODENAME="$3"
    local -r DEVICE_CODENAME_FACTORY_IMAGE="$4"
    local -r GOOGLE_BUILD_TARGET="$5"
    local -r RB_BUILD_TARGET="$6"
    # Reproducible base directory
    if [[ -z "${RB_AOSP_BASE+x}" ]]; then
        # Use default location
        local -r RB_AOSP_BASE="${HOME}/aosp"
        mkdir -p "${RB_AOSP_BASE}"
    fi

    local -r GOOGLE_BUILD_ENV="Google"
    local -r RB_BUILD_ENV="Ubuntu14.04"
    local -r RB_BUILD_ENV_DOCKER="docker-${RB_BUILD_ENV}"

    local -r DIFF_DIR="${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV_DOCKER}"
    local -r DIFF_PATH="${RB_AOSP_BASE}/diff/${DIFF_DIR}"

    local -r CONTAINER_RB_AOSP_BASE="${HOME}/aosp"
    local -r CONTAINER_NAME_BUILD="${DIFF_DIR}--build"
    local -r CONTAINER_NAME_ANALYSIS="${DIFF_DIR}--analysis"

    # Perform legacy AOSP build in docker container
    docker run --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "$CONTAINER_NAME_BUILD" \
        --user=$(id -un) \
        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${CONTAINER_RB_AOSP_BASE}/src" \
        --mount "type=bind,source=${RB_AOSP_BASE}/build,target=${CONTAINER_RB_AOSP_BASE}/build" \
        --mount "type=bind,source=/boot,target=/boot" \
        --mount "type=bind,source=/lib/modules,target=/lib/modules" \
        "mobilesec/rb-aosp-build-legacy:latest" "/bin/bash" -l -c "$(composeCommandsBuild)"
    docker rm "$CONTAINER_NAME_BUILD"

    # Run SOAP analysis via new container based on dedicated image
    docker run --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "$CONTAINER_NAME_ANALYSIS" \
        --user=$(id -un) \
        --mount "type=bind,source=${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET},target=${CONTAINER_RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}" \
        --mount "type=bind,source=${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET},target=${CONTAINER_RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}" \
        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${CONTAINER_RB_AOSP_BASE}/src" \
        --mount "type=bind,source=${RB_AOSP_BASE}/diff,target=${CONTAINER_RB_AOSP_BASE}/diff" \
        --mount "type=bind,source=/boot,target=/boot" \
        --mount "type=bind,source=/lib/modules,target=/lib/modules" \
        "mobilesec/rb-aosp-analysis:latest" "/bin/bash" -l -c "$(composeCommandsAnalysis)"
    docker rm "$CONTAINER_NAME_ANALYSIS"

    # Generate report overview on the host
    "./scripts/analysis/24_generate-report-overview.sh" "${RB_AOSP_BASE}/diff"
}

main "$@"
