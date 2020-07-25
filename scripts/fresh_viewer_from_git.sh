#!/usr/bin/env bash

# Copyright 2020, Institute for Systems Biology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ "$#" -ne 1 ]; then
    echo "Usage: ./fresh_viewer_from_git.sh [latest | release]"
    exit 1
fi

if [ ${1} == "release" ]; then
  USE_SET=setViewerVarsRelease.sh
elif [ "${1}" == "latest" ]; then
  USE_SET=setViewerVarsLatest.sh
else
  exit 1
fi

source ~/setEnvVars.sh

mkdir -p ~/config
pushd ~/config > /dev/null
gsutil cp gs://${CONFIG_BUCKET}/${CURRENT_CONFIG_PATH}/${USE_SET} .
chmod u+x ${USE_SET}
source ./${USE_SET}
popd > /dev/null

# Refresh from git. Head into the Viewer repo
pushd ~/Viewers > /dev/null
git fetch --all --tags
git pull
if [ ${1} == "release" ]; then
  git checkout ${COMMIT}
elif [ "${1}" == "latest" ]; then
  git checkout master
fi

# Run yarn:

yarn install
yarn run build

# Back to current directory
popd > /dev/null

#
# Get config built
#

./prepare_config.sh ${1}
if [ $? ne 0 ]; then
  exit 1
fi

#
# Move in customization
#

cd ~/IDC-Viewer-Support/static_files

cp idc-black.svg ~/Viewers/platform/viewer/dist/idc-black.svg
cp idc-dark.svg ~/Viewers/platform/viewer/dist/idc-dark.svg
cp ~/scratch/app-config.js ~/Viewers/platform/viewer/dist/app-config.js

#
# Install in server buckets
#

gsutil web set -m index.html -e index.html gs://${WBUCKET}
gsutil -h "Cache-Control:no-cache, max-age=0" rsync -d -r . gs://${WBUCKET}

#
# Get back to tip
#

if [ ${1} == "release" ]; then
  pushd ~/Viewers > /dev/null
  git checkout master
  popd > /dev/null
fi
