##
## Activate the correct R version.
##
# This script is used by many Jenkins jobs that have to switch between two version of R when running a 'matrix' of builds
# There are two inputs, 'label' which indicates a platform (Linux, MacOS or Windows) and RVERS (e.g. 3.4).
#

## export the jenkins-defined environment variables
export label
export RVERS

if [ $label = osx ] || [ $label = osx-lion ] || [ $label = osx-leopard ] || [ $label = MacOS-10.11 ]
then
  echo "*** OSX condition matches in shell script ***"
 ## set the active version on OSx by switching the symlink
 ## to "Versions/Current"
 unlink /Library/Frameworks/R.framework/Versions/Current
 ln -s /Library/Frameworks/R.framework/Versions/$RVERS /Library/Frameworks/R.framework/Versions/Current
elif [ $label = ubuntu ] || [ $label = ubuntu-remote ]
then
  ## use update-alternatives for linux
  echo "*** ubuntu condition matches in shell script ***"
  sudo update-alternatives --set R /usr/local/R/R-$RVERS/bin/R
  ## the Rscript binary is also set because it is configured as a slave link to R
  ## the command for setting up a new version as an alternative is:
  ## sudo update-alternatives --install /usr/local/bin/R R /usr/local/R/R-<RVERS>/bin/R <somePriorityValue> --slave /usr/local/bin/Rscript Rscript /usr/local/R/R-<RVERS>/bin/Rscript
elif [ $label = windows-aws ]
then
  echo "*** windows condition matches in shell script ***"
  ## set the active R version
  # For this to work, set up the Windows slave to link RVERS to the specific installed versions, e.g.:
  # mklink /D "C:\Program Files\R\3.3" "C:\Program Files\R\R-3.3.3"
  # mklink /D "C:\Program Files\R\3.4" "C:\Program Files\R\R-3.4.2"
  # Then create a script C:/setRvers.bat
  # The script contains just these two lines:
  #   rm -rf C:\bin\R
  #   mklink /D C:\bin\R "C:\Program Files\R\%1"
  echo ""C:/setRvers.bat" $RVERS" | cmd /c
else
  echo "*** UNRECOGNIZED LABEL: $label ***"
  exit 1
fi
