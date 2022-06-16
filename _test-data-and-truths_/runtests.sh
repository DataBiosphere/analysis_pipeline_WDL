#!/bin/bash
# run from the parent directory analysis_pipeline_wdl, not from the test data directory

ddoc vcf-to-gds/checker/vcf-to-gds-checker.wdl --json vcf-to-gds/checker/vcf-to-gds-checker.json
ddoc ld-pruning/checker/ld-pruning-checker.wdl --json ld-pruning/checker/ld-pruning-checker.json
ddoc king/checker/king-checker.wdl --json king/checker/king-checker.json
ddoc null-model/checker/null-model-checker.wdl --json null-model/checker/null-model-checker.json
ddoc assoc-aggregate/checker/assoc-aggregate-checker.wdl --json assoc-aggregate/checker/assoc-aggregate-checker.json