version 1.0

# [1] null_model_r
task null_model_r {
	input {
		# Inputs are in rough alphabetical order here for clarity's sake, but the
		# inline Python follows the original order of the CWL

		# required 
		String outcome
		File phenotype_file
		String family  # required in CWL but not in original pipeline

		# optional
		File? conditional_variant_file
		Array[String]? covars
		Array[File]? gds_files
		String? group_var
		Boolean? inverse_normal
		Int? n_pcs
		Boolean? norm_bygroup
		String? output_prefix
		File? pca_file
		File? relatedness_matrix_file
		String? rescale_variance
		Boolean? resid_covars
		File? sample_include_file
		
		# runtime attributes
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 3
	}

	# Estimate disk size required -- recall most inputs are duplicated
	Int phenotype_size = 2*ceil(size(phenotype_file, "GB"))
	Int conditional_size = 2*select_first([ceil(size(conditional_variant_file, "GB")), 0])
	Int gds_size = 2*ceil(size(select_first([gds_files, phenotype_file]), "GB"))
	Int pca_size = 2*select_first([ceil(size(pca_file, "GB")), 0])
	Int related_size = 2*select_first([ceil(size(relatedness_matrix_file, "GB")), 0])
	
	Int finalDiskSize = phenotype_size + conditional_size + gds_size + pca_size
		+ related_size + addldisk

	# Strictly speaking only needed for arrays, but we want to be consistent
	Boolean isdefined_conditvar = defined(conditional_variant_file)
	Boolean isdefined_covars = defined(covars)
	Boolean isdefined_gds = defined(gds_files)
	Boolean isdefined_group = defined(group_var)
	Boolean isdefined_inverse = defined(inverse_normal)
	Boolean isdefined_matrix = defined(relatedness_matrix_file)
	Boolean isdefined_npcs = defined(n_pcs)
	Boolean isdefined_norm = defined(norm_bygroup)
	Boolean isdefined_pca = defined(pca_file)
	Boolean isdefined_resid = defined(resid_covars)
	Boolean isdefined_sample = defined(sample_include_file)
	
	command <<<
		set -eux -o pipefail

		# params files output must have basenames, not full paths,
		# otherwise the next task cannot read from this task's params file
		# this also requires copying some things to the workdir

		echo "Symlinking phenotypic file input into workdir"
		ln -s ~{phenotype_file} .

		if ~{isdefined_conditvar}; then
			echo "Symlinking conditional variant file input into workdir"
			ln -s ~{conditional_variant_file} .
		fi

		if ~{isdefined_gds}; then
			echo "Symlinking GDS file inputs into workdir"
			GDS_FILESS=(~{sep=" " gds_files})
			for GDS_FILE in ${GDS_FILESS[@]};
			do
				ln -s ${GDS_FILE} .
			done
		fi
		
		if ~{isdefined_matrix}; then
			echo "Symlinking relatedness matrix file input into workdir"
			ln -s ~{relatedness_matrix_file} .
		fi
		if ~{isdefined_pca}; then
			echo "Symlinking PCA file input into workdir"
			ln -s ~{pca_file} .
		fi
		if ~{isdefined_sample}; then
			echo "Symlinking sample include file input into workdir"
			ln -s ~{sample_include_file} .
		fi


		echo "Generating config file"
		python << CODE
		import os
		def split_n_space(py_splitstring):
		# Return [file name with chr name replaced by space, chr name]
		# Ex: test_data_chrX.gdsreturns ["test_data_chr .gds", "X"]
			if(unicode(str(py_splitstring[1][1])).isnumeric()):
				# chr10 and above
				py_thisVcfWithSpace = "".join([
					py_splitstring[0],
					"chr ",
					py_splitstring[1][2:]])
				py_thisChr = py_splitstring[1][0:2]
			else:
				# chr9 and below + chrX
				py_thisVcfWithSpace = "".join([
					py_splitstring[0],
					"chr ",
					py_splitstring[1][1:]])
				py_thisChr = py_splitstring[1][0:1]
			return [py_thisVcfWithSpace, py_thisChr]

		f = open("null_model.config", "a")
		if "~{output_prefix}" != "":
			filename = "~{output_prefix}_null_model"
			f.write('out_prefix "' + filename + '"\n')
			phenotype_filename = "~{output_prefix}_phenotypes.RData"
			f.write('out_phenotype_file "' + phenotype_filename + '"\n')
		
		else:
			f.write('out_prefix "null_model"\n')
			f.write('out_phenotype_file "phenotypes.RData"\n')

		f.write('outcome ~{outcome}\n')
		base_pheno = os.path.basename("~{phenotype_file}")
		f.write('phenotype_file "%s"\n' % base_pheno)
		
		if "~{isdefined_gds}" == "true":
			py_gds_array = ['~{sep="','" gds_files}']
			py_gds_split = py_gds_array[0].split("chr")
			py_processed_gds = split_n_space(py_gds_split)[0]
			f.write('gds_file "' + os.path.basename(py_processed_gds) + '"\n')
		
		if "~{isdefined_pca}" == "true":
			base_pca = os.path.basename("~{pca_file}")
			f.write('pca_file "%s"\n' % base_pca)
		
		if "~{isdefined_matrix}" == "true":
			base_matrix = os.path.basename("~{relatedness_matrix_file}")
			f.write('relatedness_matrix_file "%s"\n' % base_matrix)
		
		if "~{family}" not in ['gaussian', 'poisson', 'binomial']:
			f.close()
			print("Invalid value for family. Please enter either gaussian, poisson, or binomial. These are case-sensitive.")
			exit(1)
		else:
			f.write('family ~{family}\n')
		
		if "~{isdefined_conditvar}" == "true":
			base_conditvar = os.path.basename("~{conditional_variant_file}")
			f.write('conditional_variant_file "%s"\n' % base_conditvar)
		
		if "~{isdefined_covars}" == "true":
			f.write('covars "~{sep=" " covars}"\n')
		
		if "~{isdefined_group}" == "true":
			f.write('group_var "~{group_var}"\n')
		
		if "~{isdefined_inverse}" == "true":
			f.write('inverse_normal ~{inverse_normal}\n')
		
		if "~{isdefined_npcs}" == "true":
			if int("~{n_pcs}") > 0:  # must be done this way or else syntax err when n_pcs not defined
				f.write('n_pcs ~{n_pcs}\n')

		if "~{rescale_variance}" != "":
			if "~{rescale_variance}" not in ['marginal', 'varcomp', 'none']:
				f.close()
				print("Invalid entry for rescale_variance. Options: ")
				exit(1)
			else:
				f.write('rescale_variance "~{rescale_variance}"\n')
		
		if "~{isdefined_resid}" == "true":
			f.write('reside_covars ~{resid_covars}\n')
		
		if "~{isdefined_sample}" == "true":
			base_sample = os.path.basename("~{sample_include_file}")
			f.write('sample_include_file "%s"\n' % base_sample)
		
		if "~{isdefined_norm}" == "true":
			f.write('norm_bygroup ~{norm_bygroup}\n')

		f.close()
		
		exit()
		CODE
		
		echo "Calling R script null_model.R"
		Rscript /usr/local/analysis_pipeline/R/null_model.R null_model.config
	>>>
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		# The CWL duplicates some outputs but the WDL returns each file just once
		# See this repo's _documentation_/for developers/cwl-vs-wdl.md for more info
		File config_file = "null_model.config"
		File null_model_phenotypes = glob("*phenotypes.RData")[0]
		Array[File] null_model_files = glob("${output_prefix}*null_model*RData")
		File null_model_params = glob("*.params")[0]
	}
}


# [2] null_model_report
task null_model_report {
	input {
		# these are in rough alphabetical order here
		# for clarity's sake, but the inline Python
		# follows the original order of the CWL

		# required
		String family
		File phenotype_file

		# passed in from previous
		File null_model_params
		Array[File]? null_model_files  # CWL treats as optional

		# optional
		File? conditional_variant_file
		Array[String]? covars
		Array[File]? gds_files
		String? group_var
		Boolean? inverse_normal
		Int? n_pcs
		Boolean? norm_bygroup
		String? output_prefix
		File? pca_file
		File? relatedness_matrix_file
		String? rescale_variance
		Boolean? resid_covars
		File? sample_include_file
		
		# report-specific variable
		Int n_categories_boxplot = 10

		# runtime attr
		Int addldisk = 1
		Int cpu = 2
		Int memory = 4
		Int preempt = 2

		# outcome is present in previous task but not this one
	}

	# Estimate disk size required -- recall most inputs are duplicated
	Int phenotype_size = 2*ceil(size(phenotype_file, "GB"))
	Int conditional_size = 2*select_first([ceil(size(conditional_variant_file, "GB")), 0])
	Int gds_size = 2*ceil(size(select_first([gds_files, phenotype_file]), "GB"))
	Int pca_size = 2*select_first([ceil(size(pca_file, "GB")), 0])
	Int related_size = 2*select_first([ceil(size(relatedness_matrix_file, "GB")), 0])
	
	Int finalDiskSize = phenotype_size + conditional_size + gds_size + pca_size
		+ related_size + addldisk

	# Strictly speaking only needed for arrays, but we want to be consistent
	Boolean isdefined_conditvar = defined(conditional_variant_file)
	Boolean isdefined_covars = defined(covars)
	Boolean isdefined_gds = defined(gds_files)
	Boolean isdefined_inverse = defined(inverse_normal)
	Boolean isdefined_matrix = defined(relatedness_matrix_file)
	Boolean isdefined_norm = defined(norm_bygroup)
	Boolean isdefined_null = defined(null_model_files)
	Boolean isdefined_pca = defined(pca_file)
	Boolean isdefined_resid = defined(resid_covars)
	Boolean isdefined_sample = defined(sample_include_file)
	
	command <<<
		set -eux -o pipefail

		echo "Symlinking params file into workdir"
		# workaround for rmd file being unable to find param file
		ln -s ~{null_model_params} .

		echo "Symlinking phenotypic file input into workdir"
		ln -s ~{phenotype_file} .

		if ~{isdefined_null}; then
			echo "Symlinking null model file input(s) into workdir"
			NULL_MODEL_FILESS=(~{sep=" " null_model_files})
			for NULL_MODE_FILE in ${NULL_MODEL_FILESS[@]};
			do
				ln -s ${NULL_MODE_FILE} .
			done
		fi

		if ~{isdefined_conditvar}; then
			echo "Symlinking conditional variant file input into workdir"
			ln -s ~{conditional_variant_file} .
		fi
		if ~{isdefined_gds}; then
			echo "Symlinking GDS file inputs into workdir"
			GDS_FILESS=(~{sep=" " gds_files})
			for GDS_FILE in ${GDS_FILESS[@]};
			do
				ln -s ${GDS_FILE} .
			done
		fi
		if ~{isdefined_matrix}; then
			echo "Symlinking relatedness matrix file input into workdir"
			ln -s ~{relatedness_matrix_file} .
		fi
		if ~{isdefined_pca}; then
			echo "Symlinking PCA file input into workdir"
			ln -s ~{pca_file} .
		fi
		if ~{isdefined_sample}; then
			echo "Symlinking sample include file input into workdir"
			ln -s ~{sample_include_file} .
		fi

		echo "Generating config file"
		python << CODE
		import os
		f = open("null_model_report.config", "a")
		if "~{family}" not in ['gaussian', 'poisson', 'binomial']:
			f.close()
			print("Invalid value for family. Please enter either gaussian, poisson, or binomial. These are case-sensitive.")
			exit(1)
		else:
			f.write('family ~{family}\n')
		if "~{isdefined_inverse}" == "true":
			f.write("inverse_normal ~{inverse_normal}\n")
		if "~{output_prefix}" != "":
			f.write('out_prefix "~{output_prefix}"\n')
		else:
			f.write('out_prefix "null_model"\n')
		f.write("n_categories_boxplot ~{n_categories_boxplot}\n")
		f.close

		CODE
		
		echo "Calling null_model_report.R"
		Rscript /usr/local/analysis_pipeline/R/null_model_report.R null_model_report.config
	>>>
	
	runtime {
		cpu: cpu
		docker: "uwgac/topmed-master:2.10.0"
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: "${memory} GB"
		preemptibles: "${preempt}"
	}
	output {
		File null_model_report_config = "null_model_report.config"
		Array[File] html_reports = glob("*.html")
		Array[File] rmd_files = glob("*.Rmd")
	}
}

workflow nullmodel {
	input {
		String family
		File phenotype_file
		String outcome

		File? conditional_variant_file
		Array[String]? covars
		Array[File]? gds_files
		String? group_var
		Boolean? inverse_normal
		Int? n_pcs
		Boolean? norm_bygroup
		String? output_prefix
		File? pca_file
		File? relatedness_matrix_file
		String? rescale_variance
		Boolean? resid_covars
		File? sample_include_file
	}
	
	call null_model_r {
		input:
			family = family,
			phenotype_file = phenotype_file,
			outcome = outcome,
			conditional_variant_file = conditional_variant_file,
			covars = covars,
			gds_files = gds_files,
			group_var = group_var,
			inverse_normal = inverse_normal,
			n_pcs = n_pcs,
			norm_bygroup = norm_bygroup,
			output_prefix = output_prefix,
			pca_file = pca_file,
			relatedness_matrix_file = relatedness_matrix_file,
			rescale_variance = rescale_variance,
			resid_covars = resid_covars,
			sample_include_file = sample_include_file
	}

	call null_model_report {
		input:
			family = family,
			inverse_normal = inverse_normal,
			null_model_params = null_model_r.null_model_params,
			phenotype_file = phenotype_file,
			sample_include_file = sample_include_file,
			pca_file = pca_file,
			relatedness_matrix_file = relatedness_matrix_file,
			null_model_files = null_model_r.null_model_files,
			output_prefix = output_prefix,
			conditional_variant_file = conditional_variant_file,
			gds_files = gds_files
	}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
