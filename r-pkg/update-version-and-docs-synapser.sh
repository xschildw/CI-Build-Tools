# This script is used for synapser_staging_artifact. 
# It checkout REPO_NAME repository, changes the version, update the docs, and push the changes back to the repository.

# Params
# USERNAME -- Github user who is running this build
# GITHUB_TOKEN -- The Github token that grants access to GITHUB_ACCOUNT for USERNAME
# USER_EMAIL -- The email of the USERNAME above
# GITHUB_ACCOUNT -- The target Github account
# REPO_NAME -- The repository to update
# BRANCH -- The branch to push update to
# USE_STAGING_RAN -- Set to True to download dependency (PythonEmbedInR) from staging RAN

# remove the last build clone
set +e
rm -R ${REPO_NAME}
set -e

# clone/pull the github repo
git clone https://github.com/${GITHUB_ACCOUNT}/${REPO_NAME}.git
# https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/

cd ${REPO_NAME}

git remote add upstream https://${USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_ACCOUNT}/${REPO_NAME}.git
git config user.name "${USERNAME}"
git config user.email "${USER_EMAIL}"

git fetch upstream
git checkout -b ${BRANCH} upstream/${BRANCH}

# replace DESCRIPTION with $VERSION
VERSION_LINE=`grep Version DESCRIPTION`
sed "s|$VERSION_LINE|Version: $VERSION|g" DESCRIPTION > DESCRIPTION.temp

# replace DESCRIPTION with $DATE
DATE=`date +%Y-%m-%d`
DATE_LINE=`grep Date DESCRIPTION.temp`
sed "s|$DATE_LINE|Date: $DATE|g" DESCRIPTION.temp > DESCRIPTION2.temp

rm DESCRIPTION
mv DESCRIPTION2.temp DESCRIPTION
rm DESCRIPTION.temp

# replace man/synapser-package.Rd with $VERSION
VERSION_LINE=`grep Version man/synapser-package.Rd`
sed "s|$VERSION_LINE|Version: $VERSION|g" man/synapser-package.Rd > man/synapser-package.Rd.temp

# replace man/synapser-package.Rd with $DATE
DATE=`date +%Y-%m-%d`
DATE_LINE=`grep Date man/synapser-package.Rd.temp`
sed "s|$DATE_LINE|Date: $DATE|g" man/synapser-package.Rd.temp > man/synapser-package.Rd2.temp

rm man/synapser-package.Rd
mv man/synapser-package.Rd2.temp man/synapser-package.Rd
rm man/synapser-package.Rd.temp

# add a directory that we can write to
set +e
rm -rf ../RLIB
set -e
mkdir -p ../RLIB

if [ ${USE_STAGING_RAN} ]
then
	RAN=https://sage-bionetworks.github.io/staging-ran
else
	RAN=https://sage-bionetworks.github.io/ran
fi

R -e ".libPaths('../RLIB');\
install.packages(c('fs', 'pack', 'R6', 'testthat', 'knitr', 'rmarkdown', 'PythonEmbedInR', 'devtools'),\
 repos=c('http://cran.fhcrc.org', '${RAN}'))"

# need to build the package to be able to build docs
## build the package, including the vignettes
R CMD build ./ --no-build-vignettes

## now install it, creating the deployable archive as a side effect
R CMD INSTALL ./ --library=../RLIB

# clean up the docs folder before building a new site
set +e
rm -rf docs/
set -e

R -e ".libPaths('../RLIB');\
library(rmarkdown);\
if (pandoc_available())\
  cat('pandoc', as.character(pandoc_version()), 'is available.');\
devtools::install_github('r-lib/pkgdown', ref = '@88de0954f7fce7635f850dfc895a5c24c4c222c1');\
pkgdown::build_site()"

## clean up the temporary R library dir
rm -rf ../RLIB

git add --all
git commit -m "Version $VERSION is succesfully built on $DATE"
git push upstream ${BRANCH}

git tag $VERSION
git push upstream $VERSION

cd ..
rm -rf ${REPO_NAME}

