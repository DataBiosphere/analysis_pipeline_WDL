sessionInfo()

loadRData <- function(fileName){
    load(fileName)
    get(ls()[ls() != "fileName"])
}

options <- commandArgs(trailingOnly = TRUE)
print(options)

test <- loadRData(options[1])
truth <- loadRData(options[2])
toler <- as.numeric(options[3])

# check to make sure we didn't accidentally load the same file twice
# files should not be equivalent, as they failed an MD5
stopifnot(isFALSE(identical(test, truth)))

# actual check for them being "close enough"
stopifnot(isTRUE(all.equal(test, truth, tolerance=toler)))

print("Outputs are not identical, but are mostly equivalent.")