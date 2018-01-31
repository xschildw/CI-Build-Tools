#!/bin/bash

# This script checkout the head of PLFM develop branch, and starts a tomcat server using 
# `mvn cargo:run` within a docker container.

# The required environment variables are:

# USERNAME -- Github user who is running this build
# GITHUB_TOKEN -- The Github token that grants access to GITHUB_ACCOUNT for USERNAME
# USER_EMAIL -- The email of the USERNAME above

# user - e.g. 'ktruong'
# org_sagebionetworks_stack_iam_id - the id of the developer's AWS secret key
# org_sagebionetworks_stack_iam_key - the developer's AWS secret key
# org_sagebionetworks_stackEncryptionKey - the stack encryption key, common to all dev builds
# rds_password - the password for the build database, common to all dev builds

currentdir="$PWD"

# remove the last build clone
set +e
rm -R Synapse-Repository-Services
set -e

build=${stack}${user}

# clone/pull the github repo
git clone https://github.com/Sage-Bionetworks/Synapse-Repository-Services.git
# https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/

cd Synapse-Repository-Services

git remote add upstream https://${USERNAME}:${GITHUB_TOKEN}@github.com/Sage-Bionetworks/Synapse-Repository-Services.git
git config user.name "${USERNAME}"
git config user.email "${USER_EMAIL}"

git fetch upstream
git checkout -b ${build} upstream/develop

rds_user_name=${stack}${user}

clean_up_container() {
	if [ $(docker ps --format {{.Names}} -af name=$1) ]; then
		echo "cleaning up containers ..."
		docker stop $1
		docker rm $1
	fi
}

clean_up_volumes() {
	echo "cleaning up volumes ..."
	docker volume prune -f
}

# the containers are ${build}-rds and ${build}-plfm

# remove plfm container, if any
plfm_container_name=${build}-plfm
clean_up_container ${plfm_container_name}
# remove rds container, if any
rds_container_name=${build}-rds
clean_up_container ${rds_container_name}

clean_up_volumes

echo "creating .m2 folder at ${currentdir}/.m2/ ..."
mkdir -p ${currentdir}/.m2/

# start up rds container
echo "starting up rds container: ${rds_container_name}..."
docker run --name ${rds_container_name} \
-m 1500M \
-e MYSQL_ROOT_PASSWORD=default-pw \
-e MYSQL_DATABASE=${rds_user_name} \
-e MYSQL_USER=${rds_user_name} \
-e MYSQL_PASSWORD=${rds_password} \
-d mysql:5.6

# make sure RDS is ready to go
sleep 20

tables_schema_name=${rds_user_name}tables
docker exec ${rds_container_name} mysql -uroot -pdefault-pw -sN -e "CREATE SCHEMA ${tables_schema_name};"
docker exec ${rds_container_name} mysql -uroot -pdefault-pw -sN -e "GRANT ALL ON ${tables_schema_name}.* TO '${rds_user_name}'@'%';"

# create plfm container and run `mvn cargo:run`
echo "creating plfm container: ${plfm_container_name} ..."
docker run --name ${plfm_container_name} \
-m 5500M \
-p 8888:8080 \
--link ${rds_container_name}:${rds_container_name} \
-v ${currentdir}/.m2:/root/.m2 \
-v ${currentdir}/Synapse-Repository-Services:/repo \
-e MAVEN_OPTS="-Xms256m -Xmx2048m -XX:MaxPermSize=512m" \
-w /repo \
-d maven:3-jdk-8 \
bash -c "mvn clean install \
-Dmaven.test.skip=true
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
-Duser.home=/root;\
cd integration-test; \
mvn cargo:run \
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

# wait for tomcat setting up the container
sleep 200

# call your script that interact with PLFM after this,
# then call PLFM-cleanup.sh to tear down this setup.
