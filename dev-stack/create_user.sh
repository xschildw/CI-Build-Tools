##
## Creating a Certified Synapse User
##

## Required parameters
# ADMIN_USERNAME -- the admin user
# ADMIN_APIKEY -- the admin API key
# REPO_ENDPOINT -- the dev-stack endpoint (https://repo-dev.dev.sagebase.org/repo/v1)
# USERNAME_TO_CREATE -- the username of the test user that will be created
# PASSWORD_TO_CREATE -- the password of the test user that will be created
# EMAIL_TO_CREATE -- the email of the test user that will be created

## This script will terminate on any error
set -e

## Step 1 -- Validate that the repo endpoint is reachable
curl --fail-early $REPO_ENDPOINT/version

## Step 2 -- Create a test user
# POST /admin/user
url=$REPO_ENDPOINT/admin/user
data="{\"username\":\"$USERNAME_TO_CREATE\", \"email\":\"$EMAIL_TO_CREATE\", \"password\":\"$PASSWORD_TO_CREATE\"}"
signed_headers=$(curl -s https://raw.githubusercontent.com/kimyen/CI-Build-Tools/PLFM-5028/dev-stack/sign_request.sh | bash -s $url $ADMIN_USERNAME $ADMIN_APIKEY)
echo curl -i -v -X POST -H \"Accept:application/json\" -H \"Content-Type:application/json\" $signed_headers -d \'$data\' \"$url\" | bash

## Step 3 -- Login and get sessionToken
# POST /login
url=$REPO_ENDPOINT/login
data="{\"username\":\"$USERNAME_TO_CREATE\", \"password\":\"$PASSWORD_TO_CREATE\"}"
login_result=$(echo curl -i -v -X POST -H \"Accept:application/json\" -H \"Content-Type:application/json\" -d \'$data\' \"$url\" | bash)
session_token_raw=$(grep sessionToken $login_result)
prefix_to_remove="sessionToken"
session_token="$(echo ${session_token_raw#$prefix_to_remove})" 

## Step 4 -- Get the userId
# GET /userProfile
url=$REPO_ENDPOINT/userProfile
profile=$(echo curl -i -H \"Accept:application/json\" -H \"sessionToken:$session_token\" $url | bash)
id_raw=$(grep id $profile)
prefix_to_remove="ownerId"
id="$(echo ${id_raw#$prefix_to_remove})"

## Step 5 -- Add the test user to Certified user group
# PUT /user/{id}/certificationStatus
url=$REPO_ENDPOINT/user/$id/certificationStatus?isCertified=True
signed_headers=$(curl -s https://raw.githubusercontent.com/kimyen/CI-Build-Tools/PLFM-5028/dev-stack/sign_request.sh | bash -s $url $ADMIN_USERNAME $ADMIN_APIKEY)
echo curl -i -v -X POST -H \"Accept:application/json\" -H \"Content-Type:application/json\" $signed_headers -d \'$data\' \"$url\" | bash


