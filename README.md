# TOPMed Analysis Pipeline -- WDL Version

[![WDL 1.0 shield](https://img.shields.io/badge/WDL-1.0-lightgrey.svg)](https://github.com/openwdl/wdl/blob/main/versions/1.0/SPEC.md) ![help wanted](https://img.shields.io/badge/help-wanted-red)  
This is a project to implement some components of the [UWGAC TOPMed pipeline](https://github.com/UW-GAC/analysis_pipeline) into Workflow Description Langauge whilst also mimicing the [CWL version of the UW pipeline](https://github.com/UW-GAC/analysis_pipeline_cwl) as possible. In other words, this is a WDL that mimics a CWL that mimics a Python pipeline. All three pipelines, however, use the same underlying R scripts which do most of the heavy lifting, making their results directly comparable.

Example files are provided in `testdata`. Please note some of them vary slightly compared to the test files in the original repository.

## Features
* This pipeline is very similiar to the CWL version and the main differences between the two [are documented](https://github.com/aofarrel/analysis_pipeline_WDL/blob/master/cwl-vs-wdl.md).
* For local runs, it does not have any external dependencies other than the usual setup required for [WDL](https://software.broadinstitute.org/wdl/documentation/quickstart). Terra users need even less -- just the Google Chrome web browser.
* Shares a Docker container with the CWL and Python versions of the pipeline, meaning the R scripts that do the actual heavy lifting are identical provided the same container tag is being used.

## Execution
This pipeline runs best on Terra. Due to how Cromwell works outside of cloud environments, local runs may draw too much memory; [see here for more info + migitation strategies](https://github.com/aofarrel/analysis_pipeline_WDL/issues/15).
### Runtime Attributes
The original pipeline had arguments relating to runtime such as `ncores` and `cluster_type` that do not apply to WDL. Please familarize yourself with the [runtime attributes of WDL](https://cromwell.readthedocs.io/en/stable/RuntimeAttributes/) if you are unsure how your settings may transfer.
### Components
* [vcf-to-gds-wf](https://github.com/aofarrel/analysis_pipeline_WDL/blob/master/README_vcf-to-gds-wf.md)

------

### Author
Ash O'Farrell (aofarrel@ucsc.edu)  
