##
## Creating a Certified Synapse User
##

## Required parameters
# ADMIN_USERNAME -- the admin user
# ADMIN_APIKEY -- the admin API key
# REPO_ENDPOINT -- the dev-stack endpoint (https://repo-dev.dev.sagebase.org)
# USERNAME_TO_CREATE -- the username of the test user that will be created
# PASSWORD_TO_CREATE -- the password of the test user that will be created
# EMAIL_TO_CREATE -- the email of the test user that will be created

## This script will terminate on any error
set -e

## Step 1 -- Validate that the repo endpoint is reachable
echo "Validate that the repo endpoint is reachable"
curl $REPO_ENDPOINT/repo/v1/version

## Step 2 -- Create a test user
# POST /admin/user
echo "Create a test user"
url=$REPO_ENDPOINT/repo/v1/admin/user
data="{\"username\":\"$USERNAME_TO_CREATE\", \"email\":\"$EMAIL_TO_CREATE\", \"password\":\"$PASSWORD_TO_CREATE\", \"session\":{\"acceptsTermsOfUse\":true}}"
signed_headers=$(curl -s https://raw.githubusercontent.com/kimyen/CI-Build-Tools/PLFM-5028/dev-stack/sign_request.sh | bash -s $url $ADMIN_USERNAME $ADMIN_APIKEY)
new_user=$(echo curl -X POST -H \"Accept:application/json\" -H \"Content-Type:application/json\" $signed_headers -d \'$data\' \"$url\" | bash)
prefix="{\"id\":\""
suffix="\"}"
id=$(echo $new_user | sed -e "s/^$prefix//" -e "s/$suffix$//")
echo "Created user with ID: $id"

## Step 3 -- Add the test user to Certified user group
# PUT /user/{id}/certificationStatus
echo "Add the test user to Certified user group"
url=$REPO_ENDPOINT/repo/v1/user/$id/certificationStatus?isCertified=True
signed_headers=$(curl -s https://raw.githubusercontent.com/kimyen/CI-Build-Tools/PLFM-5028/dev-stack/sign_request.sh | bash -s $url $ADMIN_USERNAME $ADMIN_APIKEY)
echo curl -X PUT -H \"Accept:application/json\" -H \"Content-Type:application/json\" $signed_headers \"$url\"
echo curl -X PUT -H \"Accept:application/json\" -H \"Content-Type:application/json\" $signed_headers \"$url\" | bash

## Step 4 -- Verified that the new user can login using username and password
# POST /login
echo "Verified that the new user can login using username and password"
url=$REPO_ENDPOINT/auth/v1/login
data="{\"username\":\"$USERNAME_TO_CREATE\", \"password\":\"$PASSWORD_TO_CREATE\"}"
echo curl -X POST -H \"Accept:application/json\" -H \"Content-Type:application/json\" -d \'$data\' \"$url\" | bash

