#!/bin/bash

set -e
set -o pipefail

initialize_git() {
	rm -rf registry-sync-tools
	eval $(ssh-agent -s)
	ssh-add ~/.ssh/id_rsa
	ssh-keyscan -H $GIT_DOMAIN >> ~/.ssh/known_hosts
	git clone $GIT_SSH_URL
	cp -f registry-sync-tools/image_list.txt ./
}

# initialization
initialize() {
	# sets colors for use in output
	GREEN='\e[32m'
	BLUE='\e[34m'
	YELLOW='\e[0;33m'
	RED='\e[31m'
	BOLD='\e[1m'
	CLEAR='\e[0m'

	# pre-configure ok, warning, and error output
	OK="[${GREEN}OK${CLEAR}]"
	INFO="[${BLUE}INFO${CLEAR}]"
	NOTICE="[${YELLOW}!!${CLEAR}]"
	ERROR="[${RED}ERROR${CLEAR}]"
}

registry_image_sync() {
	# do login registry
	docker login --username=$DOCKER_USER --password=$DOCKER_PASS $REGISTRY_SRC
	echo -e "${INFO} login $REGISTRY_SRC succ"
	docker login --username=$DOCKER_USER --password=$DOCKER_PASS $REGISTRY_DST
	echo -e "${INFO} login $REGISTRY_DST succ"
	# do image sync
	while read line; do
		if [[ "${line:0:1}" == '#' ]] || [[ -z ${line} ]]; then
			continue
		fi
		echo -e "${INFO}start sync image:$line ..."
		# sync image
		docker pull ${REGISTRY_SRC}/${line}
		echo -e "${INFO} pull ${REGISTRY_SRC}/${line} succ"
		docker tag ${REGISTRY_SRC}/${line} ${REGISTRY_DST}/${line}
		docker push ${REGISTRY_DST}/${line}
		echo -e "${INFO} push ${REGISTRY_DST}/${line} succ"
		echo -e "${OK} sync image:${line} succ\n"
	done < image_list.txt
}

registry_sync() {
	# check image changement
	image_sync=1
	if [ -f image_list.txt ] && [ -f image_list_old.txt ]
	then
		new_image_content=`cat image_list.txt`
		old_image_content=`cat image_list_old.txt`
		if [ "$new_image_content" != "$old_image_content" ]
		then
			echo -e "${INFO}image changement exists, do image sync ..."
		else
			echo -e "${INFO}image changement does not exist, skipping image sync ..."
			image_sync=0
		fi
	else
		echo -e "${NOTICE} skipping image changement check, do image sync ..."
	fi

	if [ $image_sync -ne 0 ]
	then
		echo -e "${INFO} start registry image sync ..."
		registry_image_sync
		mv image_list.txt image_list_old.txt
		echo -e "${OK} registry image sync succ.\n"
	fi
}

main() {
	initialize
	if [ "$1" == "-h" ] || [ "$#" -ne 5 ]; then
		echo -e "${NOTICE} Usage:"
		echo -e "${NOTICE} $0 WORKING_SPACE REGISTRY_SRC REGISTRY_DST GIT_DOMAIN GIT_SSH_URL: sync specific images from one docker registry to another."
		exit 0
	fi

	cd $1

	REGISTRY_SRC=$2
	REGISTRY_DST=$3
	GIT_DOMAIN=$4
	GIT_SSH_URL=$5

	initialize_git

	registry_sync
	echo -e "${OK} registry sync succ."
}

main "$@"
