#!/bin/bash
#
#    Copyright (C) 2018 FireHound
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>

# Useful vars
DOW=$(date +%u)
CUR_TIME=$(date +%H)

function curl_targets(){
        echo -e "Getting the list of build targets...."
        crumb=$(wget -q --auth-no-challenge --user $USERNAME --password $PASSWORD --output-document - 'https://jenkins.firehound.org/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)' | sed 's/\:/\=/g')

        # Curl a list of targets
        for target in $(curl -s https://raw.githubusercontent.com/FireHound/jenkins/o8.1/build-targets | sed -e 's/#.*$//' | grep o8.1 | awk '{printf "fh_%s-%s|%s\n", $1, $2, $3 }')
        do

                # If build day matches the current day, add the device to the build queue
                if [[ $(echo $target | awk -F"|" '{print $2}') == $DOW ]];
                then
                        export DEV_TARG=$(echo $target | awk -F"_" '{print $2}' | awk -F"-" '{print $1}')
                        BUILD_TYPE=$(echo $target | awk -F"-" '{print $2}' | awk -F"|" '{print $1}')
                        LUNCH_TARGS=$(echo $target | awk -F "|" '{print $1}')
                        echo -e "${DEV_TARG} is scheduled to be built today. Building...."
                        curl -X POST https://$USERNAME:$API_TOKEN@jenkins.firehound.org/job/builder/buildWithParameters -d "token=$TOKEN" -d "LUNCH_TARG=${LUNCH_TARGS}" -d "BOT_API_KEY=${BOT_KEY}" -d "FILE_ID=${FILEID}"  -d "$crumb"
                fi
        done
}

function wipe_dependencies(){
        echo -e "Removing all device dependencies...."

        # Parse the dependencies file for paths
        deps=$(cat $WORKSPACE/device/*/*/fh.dependencies | jq '.[].target_path' | sed 's/\"//g')

        # Recursively delete all dependencies
        for i in $deps
        do
                rm -r $i
        done
        echo "Removed all device directories!"

        # Delete the roomservice manifest
        rm -rf $WORKSPACE/.repo/local_manifests
        echo "Removed all local manifests!"
}

function build_target(){
        repo sync -c --force-sync --no-tags --no-clone-bundle
        source build/envsetup.sh
        export USE_CCACHE=1
        make clobber
        export FH_RELEASE=true
        lunch $LUNCH_TARG
        mka bacon
}

function upload_build(){
        gdrive upload ${FIREHOUND_TARGET_PACKAGE} -p $FILEID
        echo "Syncing gdrive directory with the download website!"
        curl -X GET https://api.firehound.org/nodejs/api/gdrive-files
}
