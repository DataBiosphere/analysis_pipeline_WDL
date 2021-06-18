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
		File? relatedness_matrix_file
		String? rescale_variance
		Boolean? resid_covars
		File? sample_include_file_typical
		File? sample_include_file_unrelated
	}

	##############################
	#          base case         #
	##############################
	call nullmodel.null_model_r as basecase__nullmodelr {
		input:
			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			#group_var = 
			#inverse_normal = 
			n_pcs = 4,
			#norm_bygroup
			#String outcome = 
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			sample_include_file = sample_include_file_unrelated
	}
	call nullmodel.null_model_report as basecase__nullmodelreport {
		input:
			null_model_files = null_model_r.null_model_files,
			null_model_params = null_model_r.null_model_params,

			#conditional_variant_file = 
			covars = ["sex", "Population"],
			family = "gaussian",
			#gds_files =
			#group_var = 
			#inverse_normal = 
			n_pcs = 4,
			#norm_bygroup
			#String outcome = 
			output_prefix = output_prefix,
			pca_file = pca_file,
			phenotype_file = phenotype_file,
			relatedness_matrix_file = relatedness_matrix_file,
			#rescale_variance = 
			#resid_covars = 
			sample_include_file = sample_include_file_unrelated
	}

	##############################
	#           binary           #
	##############################

	##############################
	#        conditional         #
	##############################

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
