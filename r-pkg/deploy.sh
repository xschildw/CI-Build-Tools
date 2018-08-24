# This script, when run from Jenkins, takes as input the artifacts generated by an "*_artifacts" job and publishes the R packages
# ${GITHUB_ACCOUNT} 'ran' repository.  Users can then install the packages using the commmand:
# install.packages(<package-name>, repos="https://${GITHUB_ACCOUNT}.github.io/${REPO_NAME}")

# Params
# USERNAME -- Github user who is running this build
# GITHUB_TOKEN -- The Github token that grants access to GITHUB_ACCOUNT for USERNAME
# USER_EMAIL -- The email of the USERNAME above
# GITHUB_ACCOUNT -- The target Github account
# REPO_NAME -- The target RAN repository 

## unpack the artifact
rm -rf unpacked
mkdir unpacked
unzip *.zip -d unpacked

home=`pwd`

# remove the last build clone
set +e
rm -R ${REPO_NAME}
set -e

# clone/pull the github repo
git clone https://github.com/${GITHUB_ACCOUNT}/${REPO_NAME}.git
# https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/

cd ${REPO_NAME}
git remote rm origin

git remote add origin https://${USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_ACCOUNT}/${REPO_NAME}.git
git config user.name "${USERNAME}"
git config user.email "${USER_EMAIL}"
cd ..

# switch to R 3.4.  We assume we're running on unix so we do it like this:
sudo update-alternatives --set R /usr/local/R/R-3.4/bin/R

## the archive file has a single directory
## for each R version
for RVERS in `ls unpacked/`
do
  for f in `ls unpacked/$RVERS`
  do
    echo "deploying $RVERS/$f"
    R -e "root<-'"$home"/"$REPO_NAME"';\
    if (endsWith(tolower('"$f"'), '.tar.gz')) {;\
      writePackagesType<-'source';\
      contribUrlType<-'source';\
    } else if (endsWith(tolower('"$f"'), '.tgz')) {;\
      writePackagesType<-'mac.binary';\
      if ('"$RVERS"'=='3.3') {;\
          contribUrlType<-'mac.binary.mavericks';\
      } else if ('"$RVERS"'=='3.4' || '"$RVERS"'=='3.5') {;\
          contribUrlType<-'mac.binary.el-capitan';\
      } else {;\
          contribUrlType<-'mac.binary';\
      };\
    } else if (endsWith(tolower('"$f"'), '.zip')) {;\
      writePackagesType<-'win.binary';\
      contribUrlType<-'win.binary';\
    } else {;\
        stop('Unknown package type', call. = FALSE);\
    };\
    dest<-contrib.url(root,type=contribUrlType);\
    dest<-gsub('3.4', '"$RVERS"', dest, fixed=TRUE);\
    dir.create(dest, showWarnings=FALSE, recursive=TRUE);\
    file.rename('unpacked/"$RVERS"/"$f"', file.path(dest, '"$f"'));\
    tools:::write_PACKAGES(dest, type=writePackagesType, latestOnly=FALSE);\
    message(sprintf('Installed %s to %s', 'unpacked/"$RVERS"/"$f"', file.path(dest, '"$f"')))"
  done
done

cd ${REPO_NAME}

git add --all
git commit -m "publish to repo"
git push origin --all

cd ..
rm -rf ${REPO_NAME}
rm -rf unpacked

# wait for the artifacts to be available on ran/staging-ran
sleep 600
