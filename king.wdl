version 1.0

# king.wdl -- This workflow uses the KING --ibdseg method to estimate kinship coefficients, and returns results for pairs of related samples. These kinship estimates can be used as measures of kinship in PC-AiR.

# [1] gds2bed -- convert gds file to bed file

task gds2bed {
	input {
		File gds_file

		# optional
		String? bed_file
		File? sample_include_file
		File? variant_include_file
		
		# runtime attributes
		Int addldisk = 5
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	# Estimate disk size required
	Int gds_size = ceil(size(gds_file, "GB"))
	Int final_disk_dize = gds_size + addldisk

	# Workaround for optional files
	Boolean defSampleInclude = defined(sample_include_file)
	Boolean defVariantInclude = defined(variant_include_file)
	
	command {
		set -eux -o pipefail

		echo "Generating config file"
		# noquotes = argument has no quotes in the config file to match CWL config EXACTLY
		python << CODE
		import os

		f = open("gds2bed.config", "a")
		f.write('gds_file "~{gds_file}"\n')

		if "~{defVariantInclude}" == "true":
			f.write('variant_include_file "~{variant_include_file}"\n')

		if "~{bed_file}" == "true":
				f.write('bed_file "~{bed_file}"\n')
			else:
				f.write('bed_file "~{basename(gds_file, ".gds")}"\n')

		if "~{defSampleInclude}" == "true":
			f.write('sample_include_file "~{sample_include_file}"\n')

		f.close()
		CODE

		echo "Calling R script gds2bed.R"
		Rscript /usr/local/analysis_pipeline/R/gds2bed.R gds2bed.config
	}

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + final_disk_dize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File processed_bed = glob("*.bed")[0]
		File config_file = "gds2bed.config"
	}

}

workflow king {
	input {
		File gds_file
		String? bed_file
		File? sample_include_file
		File? variant_include_file
	}
	call gds2bed{
		input:
			gds_file = gds_file,
			bed_file = bed_file,
			sample_include_file = sample_include_file,
			variant_include_file = variant_include_file
	}

	output {
		File processed_bed = gds2bed.processed_bed
	}
}
