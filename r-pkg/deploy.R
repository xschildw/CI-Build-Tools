#'
#' Deploy new versions of a package.
#'
#' @param origin_dir Root directory that contains previous versions
#' @param artifacts_dir Directory that contains the artifacts to be deployed
#' @param folder_pattern Pattern to find artifact folders
#' @param rversion_pattern Pattern to mask remove non-R-version on folder name
#'
jenkins_deploy <- function(origin_dir,
                           artifacts_dir,
                           folder_pattern = 'label=.*-RVERS-.*',
                           rversion_pattern = 'label=.*-RVERS-') {
    for (folder in list.files(artifacts_dir, pattern = folder_pattern)) {
        full_path <- paste(artifacts_dir, folder, sep = "/")
        message(sprintf('Processing folder %s', full_path))
        artifacts <- list.files(full_path)
        for (artifact in artifacts) {
            message(sprintf('Processing artifact %s', artifact))
            deploy_artifact(artifact,
                            paste(full_path, artifact, sep = "/"),
                            origin_dir,
                            gsub(rversion_pattern, '', folder))
        }
    }
}

#'
#' Deploy a single artifact file
#'
#' @param artifact_file The artifact file to be deployed
#' @param artifact_file_path The path to the artifact file to be deployed
#' @param origin_dir Root directory that contains previous versions
#' @param rversion The R version that this artifact was built for
#' @param latestOnly Set to TRUE to skip deploying older versions
#'
deploy_artifact <- function(artifact_file,
                            artifact_file_path,
                            origin_dir,
                            rversion,
                            latestOnly = FALSE) {
    LINUX_SUFFIX <- '.tar.gz'
    MAC_SUFFIX <- '.tgz'
    WINDOWS_SUFFIX <- '.zip'
    if (endsWith(tolower(artifact_file), LINUX_SUFFIX)) {
        writePackagesType <- 'source'
        contribUrlType <- 'source'
    } else if (endsWith(tolower(artifact_file), MAC_SUFFIX)) {
        writePackagesType <- 'mac.binary'
        contribUrlType <- 'mac.binary.el-capitan'
    } else if (endsWith(tolower(artifact_file), WINDOWS_SUFFIX)) {
        writePackagesType <- 'win.binary'
        contribUrlType <- 'win.binary'
    } else {
        stop('Unknown package type', call. = FALSE)
    }
    dest <- contrib.url(origin_dir, type=contribUrlType)
    current_rversion <- substr(getRversion(), 1, 3)
    dest <- gsub(current_rversion, rversion, dest, fixed = TRUE)
    dir.create(dest, showWarnings = FALSE, recursive = TRUE)
    installTo <- file.path(dest, artifact_file)
    file.rename(artifact_file_path, installTo)
    tools:::write_PACKAGES(dest, type=writePackagesType, latestOnly = latestOnly)
    message(sprintf('Installed %s to %s', artifact_file_path, installTo))
}

