version 1.0

task pcrelate_beta {
	input {
		File gds_file
		File pca_file
		Int n_pcs = 3
		String? out_prefix
		File? sample_include_file
		File? variant_include_file
		Int? variant_block_size

		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	# Estimate disk size required
	Int gds_size = ceil(size(gds_file, "GB"))
	Int pca_size = ceil(size(pca_file, "GB"))
	Int smpl_size = select_first([ceil(size(sample_include_file, "GB")), 0])
	Int vrinc_size = select_first([ceil(size(variant_include_file, "GB")), 0])
	Int finalDiskSize = gds_size + pca_size + smpl_size + vrinc_size + addldisk
	
	command {
		set -eux -o pipefail

		touch "first.RData"
	}
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	
	output {
		# CWL seems to have inconsistency where this is marked an optional ouput
		# but it also is a not-optional input into pcrelate -- double check!
		File beta = glob("*.RData")[0]
	}
}

task sample_blocks_to_segments {
	input {
		Int? n_sample_blocks = 1
		
		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	
	command {
		set -eux -o pipefail

		touch segs.txt
	}
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + addldisk + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		# not valid in WDL -- read_int can only read one integer
		Array[Int] segments = read_int("segs.txt")
	}
}

task pcrelate {
	input {
		File gds_file
		File pca_file
		File beta_file
		Int? n_pcs
		String? out_prefix
		File? variant_include_file
		Int? variant_block_size = 1024
		File? sample_include_file
		Int? n_sample_blocks = 1
		Int? segment = 1
		Boolean? ibd_probs = true
		
		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	# Estimate disk size required
	Int gds_size = ceil(size(gds_file, "GB"))
	Int pca_size = ceil(size(pca_file, "GB"))
	Int beta_size = ceil(size(beta_file, "GB"))
	Int smpl_size = select_first([ceil(size(sample_include_file, "GB")), 0])
	Int vrinc_size = select_first([ceil(size(variant_include_file, "GB")), 0])
	Int finalDiskSize = gds_size + pca_size + beta_size + smpl_size + vrinc_size + addldisk
	
	command {
		set -eux -o pipefail

		touch "blah.RData"

	}
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		# CWL seems to have inconsistency where this is marked an optional output
		# but it also is a not-optional input into pcrelate -- double check!
		File block = glob("*.RData")

	}
}

task pcrelate_correct {
	input {
		Array[File] pcrelate_block_files
		Int? n_sample_blocks
		Float? sparse_threshold

		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	# Estimate disk size required
	Int block_size = ceil(size(pcrelate_block_files, "GB"))
	Int finalDiskSize = 2*block_size + addldisk

	command {
		set -eux -o pipefail

		touch asdf_pcrelate.RData
		touch asdf_pcrelate_Matrix.RData
	}
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		# CWL seems to have inconsistency where this is marked an optional output
		# but it also is a not-optional input into kinship_plots -- double check!
		File pcrelate_output = glob("*_pcrelate.RData")
		File pcrelate_matrix = glob("*_pcrelate_Matrix.RData")
	}
}

task kinship_plots {
	input {
		File kinship_file
		String? kinship_method = "pcrelate"  # hardcoded on CWL?
		Float? kinship_plot_threshold
		File? phenotype_file
		String? group
		File? sample_include_file
		String out_prefix_initial = ""
		Boolean? run_plots
		
		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	String out_prefix_final = out_prefix_initial + "_pcrelate"
	
	command {
		set -eux -o pipefail

		touch cool.pdf

	}
	
	# Estimate disk size required
	Int kin_size = ceil(size(kinship_file, "GB"))
	Int phen_size = select_first([ceil(size(phenotype_file, "GB")), 0])
	Int smpl_size = select_first([ceil(size(sample_include_file, "GB")), 0])
	Int finalDiskSize = kin_size + phen_size + smpl_size + addldisk
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		Array[File] kinship_plots = glob("*.pdf")
	}
}

workflow pcrel {
	input {
		File pca_file
		File gds_file
		File? sample_include_file
		Int? n_pcs # sb visual default is 3, check if gets passed in as such
		File? variant_include_file
		Int? variant_block_size
		String? out_prefix
		Int? n_sample_blocks # sb default 1
		File? phenotype_file
		Float? kinship_plot_threshold
		String? group
		Float? sparse_threshold
		Boolean? ibd_probs
	}

	call pcrelate_beta {
		input:
			gds_file = gds_file,
			pca_file = pca_file,
			n_pcs = n_pcs,
			out_prefix = out_prefix,
			sample_include_file = sample_include_file,
			variant_include_file = variant_include_file,
			variant_block_size = variant_block_size
	}

	call sample_blocks_to_segments {
		input:
			n_sample_blocks = n_sample_blocks
	}

	scatter(seg in sample_blocks_to_segments.segments) {
		call pcrelate {
			input:
				gds_file = gds_file,
				pca_file = pca_file,
				beta_file =pcrelate_beta.beta,
				n_pcs = n_pcs,
				out_prefix = out_prefix,
				variant_include_file = variant_include_file,
				variant_block_size = variant_block_size,
				sample_include_file = sample_include_file,
				n_sample_blocks = n_sample_blocks,
				segment = seg,
				ibd_probs = ibd_probs
				
		}
	}

	call pcrelate_correct {
		input:
			n_sample_blocks = n_sample_blocks,
			pcrelate_block_files = pcrelate.block,
			sparse_threshold = sparse_threshold
	}

	call kinship_plots {
		input:
			kinship_file = pcrelate_correct.pcrelate_output,
			kinship_plot_threshold = kinship_plot_threshold,
			phenotype_file = phenotype_file,
			group = group,
			sample_include_file = sample_include_file,
			out_prefix_initial = out_prefix,
			run_plots = ibd_probs
	}
	

	output {
		Array[File]? pcrelate_plots = kinship_plots.kinship_plots
		File? pcrelate_output = pcrelate_correct.pcrelate_output
		File? pcrelate_matrix = pcrelate_correct.pcrelate_matrix
	}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
