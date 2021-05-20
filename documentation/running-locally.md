# General advice for running on a local machine
**Please be aware that this method of running these workflows is not officially supported. This will likely only be useful to you if you are a developer looking for a quick way to run tests on downsampled data.**

Cromwell is unable to manage the local resources it uses in the same way that it can request cloud resources. This is a problem for scattered tasks, as by default, Cromwell run them all at once. This can result in tasks getting sigkilled, freezing up Docker completely (a restart of Docker Desktop or your system will fix this), or both.

This means you have two options:
1. Stick with running on downsampled data and only on a handful of files at a time; 5 of the downsampled test files is my rule of thumb for a 16 GB computer 
2. Set up Cromwell to limit how many tasks it will attempt to run at the same time, allowing you to run on more files, albeit slower

However, #1 will still occasionally cause Docker to lock up, and depending on the resources your computer has #2 may in theory still cause issues. For these reasons we do not consider these workflows to be officially supported in the local context.

The following setup is what I use, and leverages the Dockstore CLI's gs plugin in order to pull files located in Google Cloud buckets, but [Cromwell's jar file](https://github.com/broadinstitute/cromwell/tags) can be used instead if you prefer.

### Ensure Docker is allocated at least 4 GB of memory
https://docs.docker.com/docker-for-mac/#resources

### Install the Dockstore CLI
https://dockstore.org/quick-start

### Install the gs:// plugin for the Dockstore CLI
https://github.com/dockstore/gs-plugin

### Set up a Cromwell configuration file
1. Download the template file and name it '''.cromwell.conf'''
2. Uncomment '''#default = "LocalExample"''' in the '''backend''' section in order to override the default local Cromwell setup with what is in the configuration file's LocalExample setup.
3. Under '''LocalExample''', under '''config''', uncomment the setting for '''concurrent-job-limit''' and set it to 1.
Your configuration file should now look like this:
[...]
backend {
  # Override the default backend.
  default = "LocalExample"

  # The list of providers.
  providers {
	  [...]
	  # Define a new backend provider.
	  LocalExample {
	  	  # The actor that runs the backend. In this case, it's the Shared File System (SFS) ConfigBackend.
	  	  actor-factory = "cromwell.backend.impl.sfs.config.ConfigBackendLifecycleActorFactory"
	  	  
		  # The backend custom configuration.
	        config {
	  	  	  # Optional limits on the number of concurrent jobs
	  	  	  concurrent-job-limit = 1
[...]

You may optionally edit '''root = "cromwell-executions"''' to something else if you wish to be certain that your configuration is getting used, as it will change the name of the executions folder.

### Have Dockstore use the Cromwell configuration file
Add the following line to ~/.dockstore/config
cromwell-vm-options: -Dconfig.file=<path-to-your-cromwell-config>


With this setup, while in the workflow folder as your working directory, you can launch your workflow like so:
 dockstore workflow launch --local-entry ld-pruning-wf.wdl --json ld-pruning-terra.json
