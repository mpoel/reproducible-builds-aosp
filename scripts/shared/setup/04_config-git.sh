#!/bin/bash
set -ex

# Dummy values since this user is shared. Note that these can't remain empty, otherwise repo refuses to init
git config --global user.name "Reproducible Builds dev"
git config --global user.email "rb-aosp@ins.jku.at"
