## In brief
Some tasks currently have a workaround wherein symlinks are used. This is not a problem in and of itself, but I am documenting why it is necessary as this may help other people WDLize similar programs.

## Reason 1: Inputs go into different folders
_**Important note**: This describes a Cromwell execution on a local filesystem. The details of localizing files and what folders they go into changes on different backends. Some backends may not even need this workaround._

The second task of the ld-prune workflow generates chromosome-level, subset GDS files in a scattered task. The third task, which is not scattered, takes in those files as inputs in order to merge them into a single GDS file.

This situation, wherein a scattered task passes in inputs to a non-scattered task, passes in each instance of the scattered task's outputs into a new folder. Let's say my scattered task runs on 5 GDS files, generating 5 subset GDS files. My subsequent task is passed in those gds files like this:

<img width="623" alt="Screenshot 2021-04-09 at 3 34 00 PM" src="https://user-images.githubusercontent.com/27784612/114250466-a9331f80-9952-11eb-9e09-f114f9d89e4f.png">

That is to say, each GDS file now lives in its own folder within /inputs/. On both Terra and the local filesystem, this is preceeded by a folder name which includes random integers/characters, thereby preventing the full path from being predicted before runtime -- in other words, the full path cannot just be hardcoded.

This is problematic with how the R scripts use configuration files. These configuration files expect one line to represent a given pattern for an input file, such as 

> gds_file '1KG_phase3_subset_chr .gds'

where the space is filled in with expected chromosome numbers by the script itself at runtime.

We have two options when referring to files like these when making configuration files: Either we pass in the path, or just a filename. If we pass in the full path, the resulting configuration file will be invalid, because every gds file has a different path due to each gds file living in a separate folder. If we pass in a filename, the resulting configuration file will technically be valid, but it will fail because the files strictly speaking do not exist in the working directory, but rather in some subfolder of /inputs/.

However, if we copy or symlink each of those input files into the working directory, we can use the filename method, because now files are actually where the R script expects them.

```
BASH_FILES=(~{sep=" " gdss})
for BASH_FILE in ${BASH_FILES[@]};
do
	ln -s ${BASH_FILE}
done
```
Where gdss is the array of input files from the previous scattered task. 

## Reason 2: Parameter files passed between different Docker containers
More information: https://github.com/DataBiosphere/analysis_pipeline_WDL/blob/main/_documentation_/for%20developers/params-vs-config.md

The null model workflow generates a parameters file in its first task, which must use a general path, because the next tasks that same parameters file to generate its own output. If it used absolute paths, the path would point to the first task's inputs directory, which is not available in the second task. This is because, when running on Terra, each task is running inside of a Docker container. (The local version of Cromwell technically does not need Docker, but for Terra it is a hard requirement.) Files that are not explicitly passed in or out of that container cannot be accessed by other tasks. In other words, in the WDL context, each task has its own file system. Additionally, the input directory's name is not consistent across tasks even if they are based upon the same Docker image, nor can it be predicted before runtime.

Therefore, we must use relative paths in the params file, and we additionally must symlink files from the input directory to the working directory for these relative paths to function with the R scripts.