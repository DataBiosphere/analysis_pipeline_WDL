library(argparser)
sessionInfo()

argp <- arg_parser("Check if null model outputs vary")
argp <- add_argument(argp, "config", help="path to config file")
argv <- parse_args(argp)
config <- readConfig(argv$config)

required <- c("test_file",
              "truth_file")
optional <- c("tolerance"=1.5e-8)
config <- setConfigDefaults(config, required, optional)
print(config)

# get the number of threads available
# this should speed up matrix calculations if we are running parallel MKL
countThreads()

test <- config["test_file"]
truth <- config["truth_file"]
toler <- config["tolerance"]

stopifnot(isTRUE(all.equal(test, truth, tolerance=toler)))