## This build checking version $VERSION_TO_CHECK is downloadable from $RAN
## and installable to multiple platforms.

## First check to see if the new version is available
export ATTEMPTS=5
export FOUND=FALSE
while [ $ATTEMPTS -gt 0 ]
do
  if [ $( curl -v --silent ${RAN}/src/contrib/PACKAGES 2>&1 | grep "Package: synapser" -A 2 | grep "Version: ${VERSION_TO_CHECK}" | wc -c ) -eq 0 ]
  then
    sleep 60
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

if [ $label = windows-aws ]
then
  ## build x64 version
  PATH=C:\\Program\ Files\\R\\$RVERS\\bin\\x64
  R -e "try(remove.packages('PythonEmbedInR'), silent=T);\
  try(remove.packages('synapser'), silent=T);\
  install.packages('synapser', repos=c('http://cran.fhcrc.org', Sys.getenv('RAN')));\
  library('synapser')"

  ## build i386 version version
  PATH=C:\\Program\ Files\\R\\$RVERS\\bin\\i386
  R -e "try(remove.packages('PythonEmbedInR'), silent=T);\
  try(remove.packages('synapser'), silent=T);\
  install.packages('synapser', repos=c('http://cran.fhcrc.org', Sys.getenv('RAN')));\
  library('synapser')"
else
  R -e "try(remove.packages('PythonEmbedInR'), silent=T);\
  try(remove.packages('synapser'), silent=T);\
  install.packages('synapser', repos=c('http://cran.fhcrc.org', Sys.getenv('RAN')));\
  library('synapser')"
fi
  