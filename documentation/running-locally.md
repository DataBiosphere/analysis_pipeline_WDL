# General advice for running on a local machine
**Please be aware that this method of running these workflows is not officially supported. This will likely only be useful to you if you are a developer looking for a quick way to run tests on downsampled data.**

Cromwell is unable to manage the local resources it uses in the same way that it can request cloud resources. This is a problem for scattered tasks, as by default, Cromwell run them all at once. This can result in tasks getting sigkilled, freezing up Docker completely, or both.

This means you have two options:  
A. Running only a handful (≈5) of downsampled files at a time  
B. Set up Cromwell to limit how many tasks it will attempt to run at the same time, allowing you to run on more files, albeit slower  

However, option A will still occasionally cause Docker to lock up, and depending on the resources your computer has option B may in theory still cause issues. For these reasons we do not consider these workflows to be officially supported in the local context.

### Prerequisites:
* [Install Docker](https://docs.docker.com/get-docker/)
* [Ensure Docker is allocated at least 4 GB of memory and 3 CPUs](https://docs.docker.com/docker-for-mac/#resources) (preferably more; I use 5 GB memory, 6 CPUs, and 1.5 GB swap)
* [Install the Dockstore CLI](https://dockstore.org/quick-start) or [standalone Cromwell](https://github.com/broadinstitute/cromwell/releases/tag/63)
* (Optional) [Install the gs:// plugin for the Dockstore CLI](https://github.com/dockstore/gs-plugin)

## A: Running on a limited number of files instead of setting up Cromwell
Launch command: `dockstore workflow launch --local-entry ld-pruning-wf.wdl --json ld-pruning-local.json`

The -local JSONs included in this repository have only a handful of files in them, and can be used to run locally in a way that is unlikely to cause lockups or sigkills. However, as the lockups will still happen from time to time, be aware of the symptoms:
* Within Cromwell, new tasks will move from status - to WaitingForReturnCode, but will then get stuck in WaitingForReturnCode
* Outside of Cromwell, you will not be able to run any Docker containers even if you control-C'ed out of your stalled workflow
These lockups can be fixed by restarting Docker, which is done most easily via the top bar option if you Docker Desktop installed.

Generally, sigkills will only happen if you are running on a larger number of input files. (For instance, when running on 5 files without setting up Cromwell, I generally get Docker lockups 10% of the time and sigkills do not happen. When running on 20 files, about 75% of scattered tasks gets sigkilled.) If your scattered tasks' `rc` file is 137, that means your tasks are getting sigkilled and you are running on too many files for your computer's resources to handle.

## B: Set up Cromwell's concurrent-job-limit
Launch command, but don't do it until you've done the setup below: `dockstore workflow launch --local-entry ld-pruning-wf.wdl --json ld-pruning-terra.json`

These instructions assume using the Dockstore CLI, but the configuration file for Cromwell is the same.

### Set up a Cromwell configuration file
1. Download [this template file](https://github.com/broadinstitute/cromwell/blob/develop/cromwell.example.backends/cromwell.examples.conf) and name it `.cromwell.conf`
2. Uncomment `#default = "LocalExample"` in the `backend` section in order to override the default local Cromwell setup with what is in the configuration file.
3. Under `LocalExample`, under `config`, uncomment the setting for `concurrent-job-limit` and set it to 1.  

Your configuration file should now look like this:
```
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
```
You may optionally edit `root = "cromwell-executions"` to something else if you wish to be certain that your configuration is getting used, as it will change the name of the executions folder.

### Have Dockstore use the Cromwell configuration file
Add the following line to `~/.dockstore/config`

`cromwell-vm-options: -Dconfig.file=<path-to-your-cromwell-config>`

You're now all set up.
