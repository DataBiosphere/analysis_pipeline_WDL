# TOPMed Analysis Pipeline — WDL Version

[![WDL 1.0 shield](https://img.shields.io/badge/WDL-1.0-lightgrey.svg)](https://github.com/openwdl/wdl/blob/main/versions/1.0/SPEC.md)  
This is a work-in-progress project to implement some components of the University of Washington [TOPMed pipeline](https://github.com/UW-GAC/analysis_pipeline) into Workflow Description Lauange (WDL) in a way that closely mimics [the CWL version of the UW Pipeline](https://github.com/UW-GAC/analysis_pipeline_cwl). In other words, this is a WDL that mimics a CWL that mimics a Python pipeline. All three pipelines use the same underlying R scripts which do most of the heavy lifting, making their results directly comparable.

## Motivation
The original goal of this undertaking was to provide sample preparation options for a subset of users on Terra, as the existing sample preparation notebook did not run well on TOPMed Freeze 8 data due to a large increase in the number of variants. While we hope that this can eventually be used for that case, the scope has since widened for other forms of analysis, and as a case study of interoperability between CWL-based platforms and WDL-based platforms. For that reason, this pipeline is designed to be as close to the CWL version as possible.

## Features
* This pipeline is very similiar to the CWL version and the main differences between the two [are documented](https://github.com/DataBiosphere/analysis_pipeline_WDL/blob/main/documentation/cwl-vs-wdl.md)
* As it works in a Docker container, it does not have any external dependencies other than the usual setup required for [WDL](https://software.broadinstitute.org/wdl/documentation/quickstart) and [Cromwell](http://cromwell.readthedocs.io/en/develop/)
* Results the CWL pipeline and this WDL pipeline give across platforms are very similiar -- in our testing, output gds files end up with equivalent md5sums
* Contains a checker workflow for validating a set of known inputs and expected outputs

## Usage
Example files are provided in `testdata` and in `gs://topmed_workflow_testing/UWGAC_WDL/`.  

The original pipeline had arguments relating to runtime such as `ncores` and `cluster_type` that do not apply to WDL. Please familarize yourself with the [runtime attributes of WDL](https://cromwell.readthedocs.io/en/stable/RuntimeAttributes/) if you are unsure how your settings may transfer. For more information on specific runtime attributes for specific tasks, see [the further reading section](https://github.com/DataBiosphere/analysis_pipeline_WDL/main/README.md#further-reading).  
### Terra users
For Terra users, it is recommended to import via Dockstore. Importing `vcf-to-gds-terra.json` at the workflow field entry page will fill in test data and recommended runtime attributes. If you are using your own data, please be sure to increase your runtime attributes.  
### Local users
For local users, it is recommended to use either the latest build of Cromwell or the Dockstore CLI. Assuming you have cloned the repository and are in the working directory, the command would be:  
`dockstore workflow launch --local-entry vcf-to-gds-wf.wdl --json vcf-to-gds-local.json`  
Due to how Cromwell works, local runs may draw too much memory; [see here for more info and migitation strategies](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/1). This memory issue does **not** affect Terra users.  

## Further reading
* [checker workflow](https://github.com/DataBiosphere/analysis_pipeline_WDL/blob/main/documentation/checker.md)
* [ld-pruning-wf](https://github.com/DataBiosphere/analysis_pipeline_WDL/blob/main/documentation/ld-pruning-wf.md)
* [vcf-to-gds-wf](https://github.com/DataBiosphere/analysis_pipeline_WDL/blob/main/documentation/vcf-to-gds-wf.md)


------

#### Author
Ash O'Farrell (aofarrel@ucsc.edu)  
