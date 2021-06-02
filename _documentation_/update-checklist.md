This is not intended to be an exhaustive list of things to check when updating, just guidance, should I be taken up and maintence of this pipeline falls to someone else.

When implementing an update that could reasonably change outputs (such as changing the Docker container)...
1. Re-generate truth files on SB
2. Test updated WDL against those truth files
3. Upload the SB truth files to BOTH testdata/ in this repository and gs://topmed_workflow_testing/UWGAC_WDL/

Any changes to default inputs in the LD Pruning task will need to be updated in the documentation, in the WDL tasks' input section, and in the WDL task's inline Python.