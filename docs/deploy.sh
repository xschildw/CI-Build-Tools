# This script, when run from Jenkins, pushes the built documentation to AWS S3.
# See the s3_website.yml configuration file in the Synapse docs repository.

# Parameters
# GITHUB_USERNAME -- The Github user who is running this build
# GITHUB_ACCOUNT -- The target Github account
# GITHUB_TOKEN -- The Github token that grants access to GITHUB_ACCOUNT for GITHUB_USERNAME
# REPO_NAME -- The Github repo to get the built documentation pages from

# remove the last build clone
set +e
rm -R ${REPO_NAME}
set -e

# clone the Github repo
git clone https://github.com/${GITHUB_ACCOUNT}/${REPO_NAME}.git

cd ${REPO_NAME}

# ensure environment
gem install s3_website

# deploy
s3_website push

# clean up
cd ..
rm -rf ${REPO_NAME}


