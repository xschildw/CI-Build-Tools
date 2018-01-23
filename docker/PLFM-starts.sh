#!/bin/bash

# This script checkout the head of PLFM develop branch, and starts a tomcat server using 
# `mvn cargo:run` within a docker container.

# The required environment variables are:

# USERNAME -- Github user who is running this build
# GITHUB_TOKEN -- The Github token that grants access to GITHUB_ACCOUNT for USERNAME
# USER_EMAIL -- The email of the USERNAME above

# user - e.g. 'pjmhill'
# m2_cache_parent_folder - the folder within which .m2 is to be found
# src_folder - the folder within which the source code is found
# org_sagebionetworks_stack_iam_id - the id of the developer's AWS secret key
# org_sagebionetworks_stack_iam_key - the developer's AWS secret key
# org_sagebionetworks_stackEncryptionKey - the stack encryption key, common to all dev builds
# rds_password - the password for the build database, common to all dev builds
# JOB_NAME - a unique string differentiating concurrent builds.  if omitted is the stack + user

# remove the last build clone
set +e
rm -R Synapse-Repository-Services
set -e

# determine job name
if [ ! ${JOB_NAME} ]; then
	JOB_NAME=${stack}${user}
fi

# clone/pull the github repo
git clone https://github.com/Sage-Bionetworks/Synapse-Repository-Services.git
# https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/

cd Synapse-Repository-Services

git remote add upstream https://${USERNAME}:${GITHUB_TOKEN}@github.com/Sage-Bionetworks/Synapse-Repository-Services.git
git config user.name "${USERNAME}"
git config user.email "${USER_EMAIL}"

git fetch upstream
git checkout -b ${JOB_NAME} upstream/develop

rds_user_name=${stack}${user}

clean_up_container() {
	if [ $(docker ps --format {{.Names}} -af name=$1) ]; then
		docker stop $1
		docker rm $1
	fi
}

clean_up_network() {
	if [ $(docker network ls | grep -q $1 && echo $?) ]; then
		docker network rm $1
	fi
}

clean_up_volumes() {
	if [ $label = windows-aws-containers ]; then
		docker volume prune -f
	fi
}

# the containers are ${JOB_NAME}-rds and ${JOB_NAME}-plfm

# remove plfm container, if any
plfm_container_name=${JOB_NAME}-plfm
clean_up_container ${plfm_container_name}
# remove rds container, if any
rds_container_name=${JOB_NAME}-rds
clean_up_container ${rds_container_name}
# remove the network if it's still there from last time
network_name=${JOB_NAME}
clean_up_network ${network_name}

clean_up_volumes

mkdir -p ${m2_cache_parent_folder}/.m2/

if [ $label = windows-aws-containers ]
then
	docker network create --driver l2bridge ${network_name}
else
	docker network create --driver bridge ${network_name}
fi

# start up rds container
docker run --name ${rds_container_name} \
--network=${network_name} \
-m 1500M \
-e MYSQL_ROOT_PASSWORD=default-pw \
-e MYSQL_DATABASE=${rds_user_name} \
-e MYSQL_USER=${rds_user_name} \
-e MYSQL_PASSWORD=${rds_password} \
-v /etc/localtime:/etc/localtime:ro \
-d mysql:5.6

# make sure RDS is ready to go
sleep 20

tables_schema_name=${rds_user_name}tables
docker exec ${rds_container_name} mysql -uroot -pdefault-pw -sN -e "CREATE SCHEMA ${tables_schema_name};"
docker exec ${rds_container_name} mysql -uroot -pdefault-pw -sN -e "GRANT ALL ON ${tables_schema_name}.* TO '${rds_user_name}'@'%';"

cd integration-test

# create plfm container and run `mvn cargo:run`
docker run -i --rm --name ${plfm_container_name} \
-m 5500M \
--network=${network_name} \
--link ${rds_container_name}:${rds_container_name} \
-v ${m2_cache_parent_folder}/.m2:/root/.m2 \
-v ${src_folder}:/repo \
-v /etc/localtime:/etc/localtime:ro \
-e MAVEN_OPTS="-Xms256m -Xmx2048m -XX:MaxPermSize=512m" \
-w /repo \
maven:3-jdk-8 \
bash -c "mvn cargo:run \
-Dorg.sagebionetworks.repository.database.connection.url=jdbc:mysql://${rds_container_name}/${rds_user_name} \
-Dorg.sagebionetworks.id.generator.database.connection.url=jdbc:mysql://${rds_container_name}/${rds_user_name} \
-Dorg.sagebionetworks.stackEncryptionKey=${org_sagebionetworks_stackEncryptionKey} \
-Dorg.sagebionetworks.stack.iam.id=${org_sagebionetworks_stack_iam_id} \
-Dorg.sagebionetworks.stack.iam.key=${org_sagebionetworks_stack_iam_key} \
-Dorg.sagebionetworks.stack.instance=${user} \
-Dorg.sagebionetworks.developer=${user} \
-Dorg.sagebionetworks.stack=${stack} \
-Dorg.sagebionetworks.table.enabled=true \
-Dorg.sagebionetworks.table.cluster.endpoint.0=${rds_container_name} \
-Dorg.sagebionetworks.table.cluster.schema.0=${tables_schema_name} \
-Duser.home=/root"

# call your script that interact with PLFM after this,
# then call PLFM-cleanup.sh to tear down this setup.
