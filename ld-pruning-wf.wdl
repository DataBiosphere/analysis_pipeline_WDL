version 1.0

# [1] ld_pruning -- ld prunes a GDS file
task ld_pruning {
	input {
		File gds
		String genome_build = hg38  # can also be hg18 or hg19
		Float ld_r_threshold = 0.32  # (r^2 = 0.1)
		Float ld_win_size = 10
		Float maf_threshold = 0.01
		Float missing_threshold = 0.01
		
		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	command {
		set -eux -o pipefail

		echo "Generating config file"
		python << CODE
		import os
		f = open("ld_pruning.config", "a")
		f.write("gds_file ~{gds}\n")

		# other stuff goes here

		f.close()
		exit()
		CODE

		echo "Calling R script ld_pruning.R"
		Rscript /usr/local/analysis_pipeline/R/ld_pruning.R ld_pruning.config
	}
	
	# Estimate disk size required

	# should include sample file...
	Int gds_size = ceil(size(gds, "GB"))
	Int finalDiskSize = 2*gds_size + addldisk
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File ld_pruning_output = glob("*.RData") # RData file with variant.id of pruned variants
		File config_file = "ld_pruning.config"
	}
}

workflow b_ldpruning {
	input {
		Array[File] gds_files
	}

	scatter(gds_file in gds_files) {
		call ld_pruning {
			input:
				gds = gds_file
		}
	}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
