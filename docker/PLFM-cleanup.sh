# This script is used to clean up after PLFM-starts.sh

# continue to execute the all lines in this file even if previous commands fail.
set +e

# determine job name
if [ ! ${JOB_NAME} ]; then
	JOB_NAME=${stack}${user}
fi

rds_user_name=${stack}${user}

clean_up_container() {
if [ $(docker ps --format {{.Names}} -af name=$1) ]; then
  docker stop $1
  docker rm $1
fi
}

clean_up_volumes() {
  docker volume prune -f
}

# remove plfm container, if any
plfm_container_name=${JOB_NAME}-plfm
clean_up_container ${plfm_container_name}
# remove rds container, if any
rds_container_name=${JOB_NAME}-rds
clean_up_container ${rds_container_name}

clean_up_volumes

cd ..
rm -rf Synapse-Repository-Services