
# Simple Opinionated AOSP builds by an external Party (SOAP)

![SOAP logo](branding/soap-icon-v2.svg "SOAP logo")

This project aims to build AOSP in a reproducible manner and identify differences to the reference builds provided by Google. As reference builds we intend to track a selection of the following:
* [Factory images](https://developers.google.com/android/images) for phones by Google
* Generic system images as provided by [Android CI](https://ci.android.com)

This project enables the broader Android community, as well as any interested third parties, to track differences between AOSP and official Google builds. Furthermore, it can act as basis for future changes improving the reproducibility of Android.

## Usage Instructions

SOAP uses Docker to ensure a consistent environment for the build and analysis of AOSP artifacts and enables support for a wide range of Android versions. Depending on you preference, you may either
* invoke master shell scripts directly, resulting in the execution of SOAP in your terminal, or
* you may setup a Jenkins server which facilitates easier monitoring. We provide files in this repository that help your setup of SOAP pipelines in Jenkins.

In all cases, make sure you perform the following shared setup:

1. Your host environment requires a working Docker installation, refer to the [official install instructions](https://docs.docker.com/engine/install/) for guidance.
2. Ensure that you have at least a basic git configuration in your home directory (`~/.gitconfig`), this is required to check out the AOSP source code.
3. Acquire a copy of [this repository](https://github.com/mobilesec/reproducible-builds-aosp).
4. Build the docker images by invoking all `build-docker-image.sh` shell scripts found in the `docker` directory in this repository. (However, the working directory needs to be the root of the repository).

### Master Script Invocation

Setup for direct master script invocation is already finished. You can now invoke one of the following master scripts performing the AOSP build and SOAP analysis process:

- `run_device_fixed.sh`: Build a AOSP (Android 7+) device target and compare against the matching Google factory image. Parameters are provided as arguments.
- `run_device-legacy_fixed.sh`: Build a AOSP (Android 5-6) device target and compare against the matching Google factory image. Parameters are provided as arguments.
- `run-generic_fixed.sh`: Build a AOSP generic system images (GSI) and compare against the GSI build from Google. Parameters are provided as arguments.
- `run_generic_latest.sh`: Build a AOSP generic system images (GSI) and compare against the GSI build from Google. The `BUILD_NUMBER` parameter is the latest valid build from the Android CI dashboard, all other other parameters are hardcoded, change as needed.

### Jenkins Server

4. Follow the [official install instructions](https://www.jenkins.io/doc/book/installing/#debianubuntu) for Jenkins.
5. Invoke `jenkins/setup/01_create_pipelines.sh` to import the Jenkins pipelines found in the `jenkins` directory. As an alternative, one may create the parameterized pipelines via the GUI, refer to the `.Jenkinsfile` files for the build scripts and be sure to create all parameters required for them.
6. Adjust the imported pipeline scripts. Specifically, in the environment section perform the following changes
   - Ensure that `RB_AOSP_BASE` points to a location with sufficient space (see [Hardware requirements](https://source.android.com/setup/build/requirements\#hardware-requirements)

Setup is now finished. You can now invoke one of the following master scripts performing the AOSP build and SOAP analysis process:

- `run_device_jenkins_fixed.sh`: Build a AOSP (Android 7+) device target and compare against the matching Google factory image. Parameters are hardcoded in the script, change as needed.
- `run_device-legacy_jenkins_fixed.sh`: Build a AOSP (Android 5-6) device target and compare against the matching Google factory image. Parameters are hardcoded in the script, change as needed.
- `run_generic_jenkins_latest.sh`: Build a AOSP generic system images (GSI) and compare against the GSI build from Google. The `BUILD_NUMBER` parameter is the latest valid build from the Android CI dashboard, all other other parameters are hardcoded.
- `run_generic_jenkins_fixed.sh`: Build a AOSP generic system images (GSI) and compare against the GSI build from Google. Parameters are hardcoded in the script, change as needed.

## Parameters

### Device Builds

- `AOSP_REF`: Branch or tag in the AOSP codebase, refer to [Source code tags and builds](https://source.android.com/setup/start/build-numbers\#source-code-tags-and-builds) for a list. Specifically refer to the `Tag` column, e.g. `android-10.0.0_r40`.
- `BUILD_ID`: Specific version of AOSP, corresponds to a certain tag. Refer to the `Build` column in the same [Source code tags and builds](https://source.android.com/setup/start/build-numbers\#source-code-tags-and-builds) table, e.g. `QQ3A.200705.002`.
- `DEVICE_CODENAME`: Internal code name for the device, see the [Fastboot instructions](https://source.android.com/setup/build/running\#booting-into-fastboot-mode) for a list mapping branding names to the codenames. For example, the `Pixel 3 XL` branding name has the codename `crosshatch`.
- `DEVICE_CODENAME_FACTORY_IMAGE`: Alternative internal code name for device used in factory image list, see the [Google factory images](https://developers.google.com/android/images) for a list. E.g. the `Nexus 10` has the `DEVICE_CODENAME` `manta` in the build tooling (e.g `lunch`), but the `DEVICE_CODENAME_FACTORY_IMAGE` is `mantaray`.
- `RB_BUILD_TARGET`: Our build target as chosen in `lunch` (a helper function of AOSP), consisting of a tuple (`TARGET_PRODUCT` and `TARGET_BUILD_VARIANT`) combined via a dash. The [Choose a target](https://source.android.com/setup/build/building\#choose-a-target) section provides documentation for these. AOSP offers `TARGET_PRODUCT` values for each device with an `aosp\_` prefix. E.g a release build of the previously mentioned `Pixel 3 XL` device would be defined as `aosp_crosshatch-user`.
- `GOOGLE_BUILD_TARGET`: Very similar to `RB_BUILD_TARGET`, except that this represents Google's build target. Note that factory images provided by Google use a non-AOSP `TARGET_PRODUCT` variable. E.g a release build by Google for our running example would be defined as `crosshatch-user`.

### Generic Builds

- `BUILD_NUMBER`: Build number used by Google in the [Android CI Dashboard](https://ci.android.com).
- `BUILD_TARGET`: Build target consisting of a tuple (`TARGET_PRODUCT` and `TARGET_BUILD_VARIANT`) combined via a dash. Refer to the [Android CI Dashboard](https://ci.android.com) for available GSI targets.

## Reports

Once the build and subsequent analysis finishes, one can find the uncovered differences in `${RB_AOSP_BASE}/diff` in a folder named according to your build parameters. Optionally one can set the environment variable `RB_AOSP_BASE` ahead of the master script invocation to tell SOAP the base location where all (temporary and non-temporary) files should be placed under. If not specified, it defaults to `${HOME}/aosp`. Refer to [Hardware requirements](https://source.android.com/setup/build/requirements#hardware-requirements) for disk space demand.

When navigating the SOAP reports with a browser, start at `${RB_AOSP_BASE}/diff/reports-overview.html`. The links contain the AOSP source tag (or Google build id), build target and build environment for both the reference AOSP build and ours, specifically in the format ``. For each of these we provide the following reports:

- A **detailed HTML report** showing difference listings for all artifacts that exhibit variations.
- **CSV reports** summarizing the number of change lines **for all artifacts** via the tool diffstat. In a post-processing step, these CSV reports are cleaned from expected accountable changes that we deliberately let slip through into the difference reports, which we refer to as **diff score**.
- The individual CSV reports of each artifact are further aggregated into a single **change summary report**. Besides accumulated change lines, the individual CSV reports are also used as the basis to calculate a **weight score** that describes the relative amount of changes with regard to the overall artifact size.
- The final quantitative metrics are also visualized in a **hierarchical treemap** for improved navigation through detailed difference reports.

## Common Issues

### guestfs can't mount images

Problem:
```
++ virt-filesystems -a <disk-image>.img
libguestfs: error: /usr/bin/supermin exited with error status 1.
```

Permanent Solution (taken and slightly adjusted from bug report):
A permanent fix is the creation of following hook under `/etc/kernel/postinst.d/statoverride`:
```shell
#!/bin/sh
version="$1"
# passing the kernel version is required
[ -z "${version}" ] && exit 0
dpkg-statoverride --update --add root root 0644 "/boot/vmlinuz-${version}"
```

Temporary Solution:
Provide world read access to kernel via `sudo chmod +r "/boot/vmlinuz-"*`.

Background:
Our scripts use `libguestfs` (just like diffoscope internally) to access ext4 file system images without requiring root permissions. Internally libguestfs boots a small QEMU VM, which requires world read access to the currently active kernel image in `/boot/`. Ubuntu does not permit reading the local kernel images by non-root users, see [this bug](https://bugs.launchpad.net/ubuntu/+source/libguestfs/+bug/1673431).

In general it is strongly advised that you use the permanent solution, otherwise you'll have to fix the kernel permissions after each kernel update.

### APKtool doesn't run

Problem:
```
WARNING: Could not write to <tmp-dir>, using /tmp instead
```

Solution:
Create the following directory path for the user running the SOAP scripts: `mkdir -p  "${HOME}/.local/share/apktool/framework"`

Background:
Certain versions of the APKtool (we experienced this with `2.3.4`) do not run untill this local directory exists, see [this bug](https://github.com/iBotPeaches/Apktool/issues/2048) for details.

## Background and affiliation

Project by Johannes Kepler University Linz, Institute of Networks and Security. Details can be found at https://android.ins.jku.at/reproducible-builds/. SOAP reports can be found [here](https://android.ins.jku.at/soap/report-overview.html). This project has originally been developed by Manuel Pöll as his bachelor thesis project.

Detailed design decisions, results, and interpretations can be found in our paper and in the bachelor thesis:
- Manuel Pöll and Michael Roland: *"Automating the Quantitative Analysis of Reproducibility for Build Artifacts derived from the Android Open Source Project"*, in WiSec '22: 15th ACM Conference on Security and Privacy in Wireless and Mobile Networks, San Antonio, TX, USA, ACM, 2022. DOI [10.1145/3507657.3528537](https://doi.org/10.1145/3507657.3528537) (*accepted for publication*)
- [Manuel Pöll: *"An Investigation into Reproducible Builds for AOSP"*, Bachelor's thesis, Johannes Kepler University Linz, Institute of Networks and Security, 2020](https://github.com/mobilesec/reproducible-builds-aosp/raw/master/background-work/An-Investigation-Into-Reproducible-Builds-for-AOSP.pdf).

## License

Copyright 2020 Manuel Pöll

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
