## This build checking version $VERSION_TO_CHECK is downloadable from $RAN
## and installable to multiple platforms.

## First check to see if the new version is available
export ATTEMPTS=7
export FOUND=FALSE
while [ $ATTEMPTS -gt 0 ]
do
  if [ $( curl -v --silent ${RAN}/src/contrib/PACKAGES 2>&1 | grep "Package: synapser" -A 2 | grep "Version: ${VERSION_TO_CHECK}" | wc -c ) -eq 0 ]
  then
    sleep 120
    ATTEMPTS=$(( $ATTEMPTS - 1 ))
  else
    FOUND=TRUE
    ATTEMPTS=0
  fi
done

if [ $FOUND == "FALSE" ]
then 
  echo "Version ${VERSION_TO_CHECK} not found."
  exit 1
fi

##
## Activate the correct R version.
##
curl -s https://raw.githubusercontent.com/Sage-Bionetworks/CI-Build-Tools/master/r-pkg/switch-r-version.sh \
 | bash -s arg1 arg2

echo "try(remove.packages('PythonEmbedInR'), silent=T)" > test.R
echo "try(remove.packages('synapser'), silent=T)" >> test.R
echo "install.packages('synapser', repos=c('http://cran.fhcrc.org', Sys.getenv('RAN')))" >> test.R
echo "library('synapser')" >> test.R

if [ $label = windows-aws ]
then
  oldPath=$PATH
  
  ## build x64 version
  PATH=C:\\Program\ Files\\R\\$RVERS\\bin\\x64
  R --vanilla < test.R

  ## build i386 version version
  PATH=C:\\Program\ Files\\R\\$RVERS\\bin\\i386
  R --vanilla < test.R

  PATH=$oldPath
else
  R --vanilla < test.R
fi

rm test.R
  