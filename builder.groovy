def basejobname = "fh_" + DEVICE + '-' + BUILD_TYPE
def BUILD_TREE = "/var/lib/jenkins/workspace/builder"

node("master") {
	currentBuild.displayName = basejobname

	stage('Sync') {
		sh '''#!/bin/bash
		cd '''+BUILD_TREE+'''
		rm -rf .repo/local_manifests
	        repo forall -c "git reset --hard"
	        repo forall -c "git clean -f -d"
	        repo sync -d -c -j32 --force-sync
		'''
	}
	stage('Clean') {
		sh '''#!/bin/bash
		cd '''+BUILD_TREE+'''
		make clean
		make clobber
		'''
	}
	stage('Build') {
		sh '''#!/bin/bash +e
		cd '''+BUILD_TREE+'''
		. build/envsetup.sh
		export USE_CCACHE=1
		export CCACHE_COMPRESS=1
		export FH_RELEASE=true
		lunch fh_$DEVICE-$BUILD_TYPE
		mka bacon
		'''
	}
	stage('Upload') {
		sh '''#!/bin/bash
		set -e
		cd '''+BUILD_TREE+'''
		gdrive upload '''+BUILD_TREE+'''/out/target/product/*/FireHound-*.zip -p 1UugE3Eb43arYnfn0muFvIkkDkbvj3NAr
		echo "Uploading $DEVICE build to gdrive"
		curl -X GET https://api.firehound.org/nodejs/api/gdrive-files
		'''
	}
}
