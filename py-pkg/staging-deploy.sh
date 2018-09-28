# This script, when run from Jenkins, updates the docs and releases the python package to test.pypi.org.

# Parameters
# GITHUB_USERNAME -- The Github user who is running this build
# GITHUB_ACCOUNT -- The target Github account
# GITHUB_TOKEN -- The Github token that grants access to GITHUB_ACCOUNT for GITHUB_USERNAME
# EMAIL -- The email of the user in GITHUB_USERNAME
# REPO_NAME -- The Github repo to get the Python code from
# GIT_BRANCH -- The release candidate branch
# TESTPYPI_USERNAME -- The test.pypi.org user
# TESTPYPI_PASSWORD -- The test.pypi.org user's password

# remove the last build clone
set +e
rm -R ${REPO_NAME}
set -e

# create .pypirc file
echo [distutils] > ~/.pypirc
echo index-servers=testpypi >> ~/.pypirc
echo >> ~/.pypirc
echo [testpypi] >> ~/.pypirc
echo repository: https://test.pypi.org/legacy >> ~/.pypirc
echo username:$TESTPYPI_USERNAME >> ~/.pypirc
echo password:$TESTPYPI_PASSWORD >> ~/.pypirc

# clone the Github repo
git clone https://github.com/${GITHUB_ACCOUNT}/${REPO_NAME}.git

cd ${REPO_NAME}
git config user.name "${GITHUB_USERNAME}"
git config user.email "${EMAIL}"

export VERSION=`echo $(echo ${GIT_BRANCH}.$BUILD_NUMBER | sed 's/origin\/v//g; s/-rc//g')`
git checkout ${GIT_BRANCH}

# generate docs
cd docs
make html
cd ..

# update docs
git add --all
git commit -m "update docs"
git push origin --all

# update version
sed -i "/\"latestVersion\":/c\  \"latestVersion\":\"$VERSION\"," synapseclient/synapsePythonClient

# create distribution
python3 setup.py sdist

# upload to testpypi 
twine upload --repository testpypi dist/*

# clean up
cd ..
rm -rf ${REPO_NAME}

