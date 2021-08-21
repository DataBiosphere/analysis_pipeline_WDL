version 1.0

# king.wdl -- This workflow uses the KING --ibdseg method to estimate kinship coefficients,
# and returns results for pairs of related samples. These kinship estimates can be used as
#  measures of kinship in PC-AiR.

# [1] gds2bed -- convert gds file to bed file

task gds2bed {
	input {
		File gds_file

		# optional
		String? bed_file # provides the file name for the processed bed file, if not
		# provided, the file name of the input gds file is used
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

		# check for empty string
		if "~{bed_file}" != "":
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
		File processed_bim = glob("*.bim")[0]
		File processed_fam = glob("*.fam")[0]
		File config_file = "gds2bed.config"
	}

}

# [2] plink_make_bed -- process bed file through plink

# This task skips the seven bridges-specific inheritance of metadata 

task plink_make_bed {
	input {
		File bedfile
		File bimfile
		File famfile
		
		# runtime attributes
		Int addldisk = 5
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	# Estimate disk size required
	Int bed_size = ceil(size(bedfile, "GB"))
	Int final_disk_dize = bed_size + addldisk

	
	command {
		set -eux -o pipefail

		echo "Generating bash executable file"
		python << CODE
		import os

		f = open("plink_cmd.sh", "a")

		f.write('#!/bin/bash\n')
		f.write('plink --make-bed --bfile ' + '.'.join("~{bimfile}".split('.')[:-1]) \
		+ ' --bed ' + "~{bedfile}" + ' --fam ' + "~{famfile}" + ' --out ' \
		+ os.path.basename('.'.join(("~{bedfile}").split('.')[:-1])) + '_recode\n')
	
		CODE

		echo "Calling command through executable bash file for plink"
		chmod u+x plink_cmd.sh
		./plink_cmd.sh

	}

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + final_disk_dize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File bed_file = glob("*_recode.bed")[0]
		File bim_file = glob("*.bim")[0]
		File fam_file = glob("*.fam")[0]
	}

}

# [3] king_ibdseg -- Use KING --ibdseg method to estimate kinship coefficients,
# and returns results for pairs of related samples.

task king_ibdseg {
	input {
		File bed_file
		File bim_file
		File fam_file
		String? out_prefix
		
		# runtime attributes
		Int addldisk = 5
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	# Estimate disk size required
	Int bed_size = ceil(size(bed_file, "GB"))
	Int final_disk_dize = bed_size + addldisk

	
	command {
		set -eux -o pipefail

		echo "Generating bash executable file"
		python << CODE
		import os

		# king --ibdseg -b "~{bed_file}" --cpus "~{cpu}" --prefix "~{out_prefix}"
		g = open("king_ibdseg_cmd.sh", "a")

		g.write('#!/bin/bash\n')

		if "~{out_prefix}" != "":
			g.write('king --ibdseg -b ' + "~{bed_file}" + ' --bim ' + "~{bim_file}" \
			+ ' --fam ' + "~{fam_file}"  + ' --cpus ' + "~{cpu}" + ' --prefix ' \
			+ "~{out_prefix}" + '\n')
		else:
			g.write('king --ibdseg -b ' + "~{bed_file}" + ' --bim ' + "~{bim_file}" \
			+ ' --fam ' + "~{fam_file}"  + ' --cpus ' + "~{cpu}" + ' --prefix king_ibdseg\n')

		CODE
		echo "Calling command through executable bash file for king"
		chmod u+x king_ibdseg_cmd.sh
		./king_ibdseg_cmd.sh

	}

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + final_disk_dize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File king_ibdseg_output = glob("*.seg")[0]
	}

}

# [4] king_to_matrix -- Format initial kinship estimates from KING as a matrix

# This task skips the seven bridges-specific inheritance of metadata 

task king_to_matrix {
	input {
		File king_file
		File? sample_include_file

		# optional
		Float? sparse_threshold = 0.02209709
		String? out_prefix
		String? kinship_method
		
		# runtime attributes
		Int addldisk = 5
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	# Estimate disk size required
	Int king_size = ceil(size(king_file, "GB"))
	Int final_disk_dize = king_size + addldisk

	# Workaround for optional files
	Boolean defSampleInclude = defined(sample_include_file)
	
	command {
		set -eux -o pipefail

		echo "Generating config file"
		# noquotes = argument has no quotes in the config file to match CWL config EXACTLY
		python << CODE
		import os

		f = open("king_to_matrix.config", "a")
		f.write('king_file "~{king_file}"\n')

		if "~{defSampleInclude}" == "true":
			f.write('sample_include_file ""~{sample_include_file}""\n')

		#f.write('sample_include_file "~{sample_include_file}"\n')

		if "~{sparse_threshold}" != "":
			f.write('sparse_threshold "~{sparse_threshold}"\n')
		else:
			f.write('sparse_threshold NA\n')

		# check for empty string
		if "~{out_prefix}" != "":
			f.write('out_prefix "' + "~{out_prefix}" + '"\n')
		else:
			f.write('out_prefix "' + "~{basename(king_file, ".seg")}" + '_king_ibdseg_Matrix"\n')

		if "~{kinship_method}" != "":
			f.write('kinship_method "~{kinship_method}"\n')

		if "~{kinship_method}" not in ['king_ibdseg', 'king_robust']:
			f.write('kinship_method "king_ibdseg"\n')
		else:
			f.write('kinship_method "~{kinship_method}"\n')


		f.close()
		CODE

		echo "Calling R script king_to_matrix.R"
		Rscript /usr/local/analysis_pipeline/R/king_to_matrix.R king_to_matrix.config
	}

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + final_disk_dize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File king_matrix = glob("*.RData")[0]
		File config_file = "king_to_matrix.config"
	}

}

# [5] kinship_plots -- Make hexbin plots of the initial kinship estimates from KING

task kinship_plots {
	input {
		File kinship_file
		String? kinship_method

		# optional
		Float? kinship_plot_threshold = 0.04419417382
		File? phenotype_file
		String? group
		File? sample_include_file
		String? out_prefix = "kinship"
		
		# runtime attributes
		Int addldisk = 5
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	# Estimate disk size required
	Int kinship_size = ceil(size(kinship_file, "GB"))
	Int final_disk_dize = kinship_size + addldisk

	# Workaround for optional files
	Boolean defPhenotypeFile = defined(phenotype_file)
	Boolean defSampleInclude = defined(sample_include_file)

	
	command {
		set -eux -o pipefail

		echo "Generating config file"
		# noquotes = argument has no quotes in the config file to match CWL config EXACTLY
		python << CODE
		import os

		f = open("kinship_plots.config", "a")
		f.write('kinship_file "~{kinship_file}"\n')

		if "~{kinship_method}" != "":
			if "~{kinship_method}" == "king_robust":
				f.write('kinship_method king\n')
			else:
				f.write('kinship_method "~{kinship_method}"\n')
		else:
			f.write('kinship_method "king_ibdseg"\n')

		# check for empty string
		if "~{kinship_plot_threshold}" != "":
				f.write('kinship_plot_threshold "~{kinship_plot_threshold}"\n')		

		if "~{out_prefix}" != "":
			f.write('out_file_all "' + "~{out_prefix}" + '_all.pdf"\n')
			f.write('out_file_cross "' + "~{out_prefix}" + '_cross_group.pdf"\n')
			f.write('out_file_study "' + "~{out_prefix}" + '_within_group.pdf"\n')

		if "~{defPhenotypeFile}" == "true":
			f.write('phenotype_file ""~{phenotype_file}""\n')

		if "~{group}" != "":
			f.write('study ""~{group}""\n')		

		if "~{defSampleInclude}" == "true":
			f.write('sample_include_file ""~{sample_include_file}""\n')


		f.close()
		CODE

		echo "Calling R script kinship_plots.R"
		Rscript /usr/local/analysis_pipeline/R/kinship_plots.R kinship_plots.config
	}

	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + final_disk_dize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File kinship_plots = glob("*.pdf")[0]
		File config_file = "kinship_plots.config"
	}

}

workflow king {
	input {
		File gds_file
		File? sample_include_file
		File? variant_include_file
		String? out_prefix
		File? phenotype_file
		Float? kinship_plot_threshold
		String? group
		Float? sparse_threshold
	}
	call gds2bed{
		input:
			gds_file = gds_file,
			sample_include_file = sample_include_file,
			variant_include_file = variant_include_file
	}
	call plink_make_bed{
		input:
			bedfile = gds2bed.processed_bed,
			bimfile = gds2bed.processed_bim,
			famfile = gds2bed.processed_fam
	}
	call king_ibdseg{
		input:
			bed_file = plink_make_bed.bed_file,
			bim_file = plink_make_bed.bim_file,
			fam_file = plink_make_bed.fam_file,
			out_prefix = out_prefix
	}
	call king_to_matrix{
		input:
			king_file = king_ibdseg.king_ibdseg_output,
			sample_include_file = sample_include_file,
			sparse_threshold = sparse_threshold,
			out_prefix = out_prefix
	}	
	call kinship_plots{
		input:
			kinship_file = king_ibdseg.king_ibdseg_output,
			phenotype_file = phenotype_file,
			sample_include_file = sample_include_file
	}

	output {
		File king_ibdseg_matrix = king_to_matrix.king_matrix
		File king_ibdseg_plots = kinship_plots.kinship_plots
		File king_ibdseg_output = king_ibdseg.king_ibdseg_output
	}
}
