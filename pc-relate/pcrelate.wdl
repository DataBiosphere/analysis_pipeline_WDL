version 1.0

task pcrelate_beta {
	input {
		File gds_file
		File pca_file
		Int n_pcs = 3
		String? out_prefix
		File? sample_include_file
		File? variant_include_file
		Int variant_block_size = 1024

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

	# Workaround for optional files
	Boolean defSampleInclude = defined(sample_include_file)
	Boolean defVariantInclude = defined(variant_include_file)
	
	command {
		set -eux -o pipefail
		python << CODE
		import os
		f = open("pcrelate_beta.config", "a")
		f.write('gds_file "~{gds_file}"\n')
		f.write('pca_file "~{pca_file}"\n')
		if "~{defVariantInclude}" == "true":
			f.write('variant_include_file "~{variant_include_file}"\n')
		if "~{out_prefix}" != "":
			f.write('out_prefix "~{out_prefix}"\n')
		# n_pcs has a default (not SB default!) in CWL ergo always is defined so we don't check here
		f.write("n_pcs ~{n_pcs}\n")
		if "~{defSampleInclude}" == "true":
			f.write('sample_include_file "~{sample_include_file}"\n')
		# this is another case where there is a default-valued variable doesn't need a check
		f.write("variant_block_size ~{variant_block_size}\n")
		f.close()
		CODE
		
		R -q --vanilla --args pcrelate_beta.config < /usr/local/analysis_pipeline/R/pcrelate_beta.R
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

		# With default settings, the CWL outputs [ 1 ]
		# With n_sample_blocks=5, CWL outputs [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 ]

		python << CODE
		import os
		blocks = []
		N = ~{n_sample_blocks}
		for i in range(1, N+1):
			for j in range(i, N+1):
				blocks.append([i,j])
		segments = []
		for k in range(1, len(blocks)+1):
			segments.append(str(k))

		f = open("segs.txt", "a")
		for number in segments:
			f.write(number)
			f.write('\n')
		f.close()
		CODE
	}
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
		disks: "local-disk " + addldisk + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		# read_int is extremely limited so we use read_lines instead
		Array[Int] segments = read_lines("segs.txt")
	}
}

task pcrelate {
	input {
		File gds_file
		File pca_file
		File beta_file
		Int n_pcs = 3
		String? out_prefix
		File? variant_include_file
		Int variant_block_size = 1024  # input in the CWL but goes unused
		File? sample_include_file
		Int n_sample_blocks = 1
		Int segment = 1
		Boolean ibd_probs = true
		
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
	
	# Workaround for optional files
	Boolean defSampleInclude = defined(sample_include_file)
	Boolean defVariantInclude = defined(variant_include_file)

	command {
		set -eux -o pipefail
		python << CODE
		import os
		f = open("pcrelate.config", "a")
		f.write('gds_file "~{gds_file}"\n')
		f.write('pca_file "~{pca_file}"\n')
		f.write('beta_file "~{beta_file}"\n')
		if "~{defVariantInclude}" == "true":
			f.write('variant_include_file "~{variant_include_file}"\n')
		if "~{out_prefix}" != "":
			f.write('out_prefix "~{out_prefix}"\n')
		# n_pcs has a default (not SB default!) in CWL ergo always is defined so we don't check here
		f.write("n_pcs ~{n_pcs}\n")
		if "~{defSampleInclude}" == "true":
			f.write('sample_include_file "~{sample_include_file}"\n')
		f.write("n_sample_blocks ~{n_sample_blocks}\n")
		f.write("ibd_probs ~{ibd_probs}\n")
		f.close()
		CODE

		R -q --vanilla --args pcrelate.config --segment ~{segment} < /usr/local/analysis_pipeline/R/pcrelate.R

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
		# but it also is a not-optional input elsewhere -- double check!
		File block = glob("*.RData")[0]
	}
}

task pcrelate_correct {
	input {
		Array[File] pcrelate_block_files
		Int n_sample_blocks = 1
		Float sparse_threshold = 0.02209709

		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}
	# Estimate disk size required
	Int block_size = ceil(size(pcrelate_block_files, "GB"))
	Int finalDiskSize = 2*block_size + addldisk

	command <<<
		set -eux -o pipefail

		BASH_FILES=(~{sep=" " pcrelate_block_files})
		for BASH_FILE in ${BASH_FILES[@]};
		do
			ln -s ${BASH_FILE} .
		done

		python << CODE
		import os
		f = open("pcrelate_correct.config", "a")
		one_file = ["~{sep="," pcrelate_block_files}"][0]
		prefix = os.path.basename(one_file).split("_block_")[0]
		f.write("pcrelate_prefix \"%s\"\n" % prefix)
		f.write("n_sample_blocks ~{n_sample_blocks}\n")
		f.write("sparse_threshold ~{sparse_threshold}\n")
		CODE

		R -q --vanilla --args pcrelate_correct.config < /usr/local/analysis_pipeline/R/pcrelate_correct.R

	>>>
	
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
		File pcrelate_output = glob("*_pcrelate.RData")[0]
		File pcrelate_matrix = glob("*_pcrelate_Matrix.RData")[0]
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

		python << CODE
		import os
		f = open("kinship_plots.config", "a")
		f.write('kinship_file "~{kinship_file}"\n')
		if "~{kinship_method}" not in ['pcrelate', 'king_ibdseg', 'king_robust']:
			f.close()
			print("Invalid kinship method. Must be pcrelate, king_robust, or king_ibdseg")
			exit(1)
		elif "~{kinship_method}" == "king_robust":
			f.write('kinship_method "king"\n')
		else:
			f.write('kinship_method "~{kinship_method}"\n')

		if "~{kinship_plot_threshold}" is not "":
			f.write('kinship_threshold "~{kinship_plot_threshold}"\n')

		f.write('out_file_all "~{out_prefix_final}_all.pdf"\n')
		f.write('out_file_cross "~{out_prefix_final}_cross_group.pdf"\n')
		f.write('out_file_study "~{out_prefix_final}_within_group.pdf"\n')

		if "~{phenotype_file}" is not "":
			f.write('phenotype_file "~{phenotype_file}"\n')
		
		if "~{group}" is not "":
			f.write('study "~{group}"\n')

		if "~{sample_include_file}" is not "":
			f.write('sample_include_file "~{sample_include_file}"\n')

		CODE

		R -q --vanilla --args kinship_plots.config < /usr/local/analysis_pipeline/R/kinship_plots.R
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
