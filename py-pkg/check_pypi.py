# This script, when run from Jenkins, will check a particular Synapse Python client release version on a given pypi index.

# Required parameters:
# VERSION -- the version to check
# PYPI_INDEX -- either https://test.pypi.org/simple/ (for staging) or https://pypi.org/simple


export test_env=test_$BUILD_NUMBER
virtualenv $test_env

if [ $label = windows-aws ] 
then
	. $test_env/Scripts/activate
else
	. $test_env/bin/activate
fi

# installation
pip3 install --index-url $PYPI_INDEX --extra-index-url https://pypi.org/simple "synapseclient>=$VERSION*"

# check version
actual_version=$(synapse --version)

deactivate

if [ -z "$(echo "$actual_version" | grep -oF "$VERSION")" ]
then 
	exit 1
fi
