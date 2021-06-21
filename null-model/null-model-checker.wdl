version 1.0

# Caveat programmator: This runs the null model workflow NINE times.
# It is currently configured to only run locally at the moment, and
# does not have any truth files for the time being.

import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/implement-null-model/null-model/null-model-wf.wdl" as nullmodel

workflow checker_ldprune {
	input {

		# commented out variables, included here for clarity,
		# change depending on specific run and are set manually elsewhere
		
		File? conditional_variant_file
		#Array[String]? covars
		#String family
		Array[File]? gds_files
		String? group_var
		Boolean? inverse_normal
		#Int? n_pcs  
		Boolean? norm_bygroup
		#String outcome
		String? output_prefix
		File? pca_file
		File phenotype_file
		File? phenotype_file_alternative
		File? relatedness_matrix_file
		String? rescale_variance
		Boolean? resid_covars
		File? sample_include_file_typical
		File? sample_include_file_unrelated
	}

	##############################
	#        SB WS Example       #
	##############################
	call nullmodel.null_model_r as aaa__nullmodelr {
		input:
			#conditional_variant_file = 
			covars = ["sex", "age", "study", "PC1", "PC2", "PC3", "PC4", "PC5"],
			family = "gaussian",
			#gds_files =
			group_var = "study",
			inverse_normal = "False",
			n_pcs = 4,
			#norm_bygroup
			outcome = "height",
			output_prefix = "Null_model_mixed",
			#pca_file = 
			phenotype_file = phenotype_file_alternative,
			relatedness_matrix_file = ,
			#rescale_variance = 
			#resid_covars = 
			#sample_include_file = 
	}
	call nullmodel.null_model_report as aaa__nullmodelreport {
		input:
			null_model_files = basecase__nullmodelr.null_model_files,
			null_model_params = basecase__nullmodelr.null_model_params,

			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			#group_var = 
			#inverse_normal = 
			n_pcs = 4,
			#norm_bygroup
			outcome = "outcome",
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			sample_include_file = sample_include_file_unrelated
	}

#	##############################
#	#          base case         #
#	##############################
#	
#	# Error in scan(file = file, what = what, sep = sep, quote = quote, dec = dec,  : 
#	# line 7 did not have 2 elements
#	# Calls: readConfig -> read.table -> scan
#	# Execution halted

#	call nullmodel.null_model_r as basecase__nullmodelr {
#		input:
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup
#			outcome = "outcome",
#			output_prefix = output_prefix,
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			sample_include_file = sample_include_file_unrelated
#	}
#	call nullmodel.null_model_report as basecase__nullmodelreport {
#		input:
#			null_model_files = basecase__nullmodelr.null_model_files,
#			null_model_params = basecase__nullmodelr.null_model_params,

#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup
#			outcome = "outcome",
#			output_prefix = output_prefix,
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			sample_include_file = sample_include_file_unrelated
#	}

#	##############################
#	#           binary           #
#	##############################

#	# Error in scan(file = file, what = what, sep = sep, quote = quote, dec = dec,  : 
#  	# line 7 did not have 2 elements
#	# Calls: readConfig -> read.table -> scan
#	# Execution halted

#	call nullmodel.null_model_r as binary__nullmodelr {
#		input:
#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup
#			outcome = "outcome",
#			output_prefix = output_prefix,
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			#sample_include_file = 
#	}
#	call nullmodel.null_model_report as binary__nullmodelreport {
#		input:
#			null_model_files = basecase__nullmodelr.null_model_files,
#			null_model_params = basecase__nullmodelr.null_model_params,

#			#conditional_variant_file = 
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			#gds_files =
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup
#			outcome = "outcome",
#			output_prefix = output_prefix,
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			#sample_include_file = 
#	}
#	##############################
#	#        conditional         #
#	##############################
#	call nullmodel.null_model_r as conditional__nullmodelr {
#		input:
#			conditional_variant_file = conditional_variant_file,
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			gds_files = gds_files,
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup = 
#			#outcome = 
#			output_prefix = output_prefix,
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			sample_include_file = sample_include_file_typical
#	}
#	call nullmodel.null_model_report as conditional__nullmodelreport {
#		input:
#			null_model_files = basecase__nullmodelr.null_model_files,
#			null_model_params = basecase__nullmodelr.null_model_params,

#			conditional_variant_file = conditional_variant_file,
#			covars = ["sex", "Population"],
#			family = "gaussian",
#			gds_files = gds_files,
#			#group_var = 
#			#inverse_normal = 
#			n_pcs = 4,
#			#norm_bygroup = 
#			#outcome = 
#			output_prefix = output_prefix,
#			pca_file = pca_file,
#			phenotype_file = phenotype_file,
#			relatedness_matrix_file = relatedness_matrix_file,
#			#rescale_variance = 
#			#resid_covars = 
#			sample_include_file = sample_include_file_typical
#	}
	##############################
	#            grm             #
	##############################

	##############################
	#           group            #
	##############################

	##############################
	#        norm bygroup        #
	##############################

	##############################
	#        no transform        #
	##############################

	##############################
	#        unrel binary        #
	##############################

	##############################
	#          unrelated         #
	##############################

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
	}
}
