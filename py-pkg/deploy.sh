# This script, when run from Jenkins, releases the python package to PYPI_REPO.

# Parameters
# GITHUB_USERNAME -- The Github user who is running this build
# GITHUB_ACCOUNT -- The target Github account
# GITHUB_TOKEN -- The Github token that grants access to GITHUB_ACCOUNT for GITHUB_USERNAME
# EMAIL -- The email of the user in GITHUB_USERNAME
# REPO_NAME -- The Github repo to get the Python code from
# GIT_BRANCH -- The release candidate branch
# PYPI_NAME -- Either testpypi or pypi
# PYPI_REPO -- Either https://test.pypi.org/legacy or https://upload.pypi.org/legacy/
# PYPI_USERNAME -- The PYPI_REPO user
# PYPI_PASSWORD -- The PYPI_REPO user's password
# EXTENDED_VERSION_NUMBER -- Either `.$BUILD_NUMBER` for staging or leave out for prod

# remove the last build clone
set +e
rm -R ${REPO_NAME}
set -e

# create .pypirc file
echo [distutils] > ~/.pypirc
echo index-servers=$PYPI_NAME >> ~/.pypirc
echo >> ~/.pypirc
echo [$PYPI_NAME] >> ~/.pypirc
echo repository: $PYPI_REPO >> ~/.pypirc
echo username:$PYPI_USERNAME >> ~/.pypirc
echo password:$PYPI_PASSWORD >> ~/.pypirc

# clone the Github repo
git clone https://github.com/${GITHUB_ACCOUNT}/${REPO_NAME}.git

cd ${REPO_NAME}
git config user.name "${GITHUB_USERNAME}"
git config user.email "${EMAIL}"

export VERSION=`echo $(echo ${GIT_BRANCH}${EXTENDED_VERSION_NUMBER} | sed 's/v//g; s/-rc//g')`
git checkout ${GIT_BRANCH}

# update version
sed "s|\"latestVersion\":.*$|\"latestVersion\":\"$VERSION\",|g" synapseclient/synapsePythonClient > temp
rm synapseclient/synapsePythonClient
mv temp synapseclient/synapsePythonClient

# ensure environment
python3 -m pip install twine==1.11.0 setuptools==38.6.0

# install synapseclient
python3 setup.py install

# create distribution
python3 setup.py sdist

# upload to PYPI_REPO
twine upload --repository $PYPI_NAME dist/*

# clean up
cd ..
rm -rf ${REPO_NAME}


