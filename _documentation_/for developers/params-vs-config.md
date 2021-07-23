# Params vs Configs, or, why Null Model Quadruples Its Inputs

Most pipelines in this repo use a .config file to point requisite inputs to the Rscript. The first task of the null model workflow, null_model_r, works like this. It generates a .config file which is used by null_model.R via the following call:  
`Rscript /usr/local/analysis_pipeline/R/null_model.R null_model.config`  

But one of the first things null_model.R does is generate a params file based upon the null_model.config file that it just recieved. This params file is not exactly the same as the config file it is passed in and has some formatting differences, but it can effectively act as a copy of the important information in this task's config file. This params file is among the outputs of this task, and it is passed in as an input into the next task, null_model_report.

This is because null_model_report essentially needs two configs.

First of all null_model_report generates a .config file which only contains the distribution family, the outprefix, and n_catagories_boxplot. If it were like most other tasks in this repo, the config file would also contain phenotype_file or other inputs, but it does not. Instead, null_model_report uses the previous tasks' params file for most of its inputs. It is this param file from the first task that is used to generated an Rmd (R markdown) file in the second task.

Additionally, the null_model_report task uses a full copy of all files passed into the null_model_r. For instance, if you place 23 chromosome level GDS files into null_model_r, then they will also be passed into null_model_report.

All of this is the case in both the CWL and the WDL.

Because the params file is based upon the first task's config file, and the second task cannot reach into the file system of the first task, this means the first task's config file must use relative paths. Currently, GCS limitations on softlinking means that relative paths only work when using the [Twice Localized Workaround](https://github.com/DataBiosphere/analysis_pipeline_WDL/issues/2) in both tasks of the WDL. This means that the amount of disk space required is four times the size of your inputs -- a 3 GB phenotype_file will be duplicated once in the first task, and once more in the second task, resulting in the overall pipeline requiring 12 GB of space for just that file.