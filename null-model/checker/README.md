# Null Model Checker Workflow

This workflow runs the full null model workflow a total of ten times, each one with a unique configuration based on the example configuration files in the original repo's testdata folder.

Most checker workflows in this repository perform simple MD5sum checks against truth files derived from Seven Bridges, and this one is no exception. However, when a mismatch is detected, this checker workflow will continue and run an R script in attempt to see just how different the outputs really are. Note that this has been designed for, and tested with, only the null model output file -- the other outputs should always pass an MD5.

The R script uses `all.equal` to determine if the components of the two RData files in question are within an acceptable deviation from each other. This deviation can be set with the `tolerance` optional argument. Should it fall outside that threshold, the script will error out.

The R script occupies a Docker container unique to this checker workflow. The Dockerfile and R script are both in this folder for reference.