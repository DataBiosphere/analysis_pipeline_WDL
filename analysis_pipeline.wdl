version 1.0

import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/v1.0.1/vcf-to-gds-wf.wdl" as megastepA
import "https://raw.githubusercontent.com/DataBiosphere/analysis_pipeline_WDL/implement-ld-pruning/ld-pruning-wf.wdl" as megastepB

workflow analysis_pipeline_WDL {
	input {
		# workflow A
		Array[File] vcf_files
		Array[String] format = ["GT"]
		Boolean check_gds = false
	}

	scatter(vcf_file in vcf_files) {
		call megastepA.vcf2gds {
			input:
				vcf = vcf_file,
				format = format
		}
	}
	
	call megastepA.unique_variant_id {
		input:
			gdss = vcf2gds.gds_output
	}
	
	if(check_gds) {
		scatter(gds in unique_variant_id.unique_variant_id_gds_per_chr) {
			call megastepA.check_gds {
				input:
					gds = gds,
					vcfs = vcf_files
			}
		}
	}

	scatter(gds in unique_variant_id.unique_variant_id_gds_per_chr) {
		call megastepB.ld_pruning {
			input:
				gds = gds
		}
	}

	scatter(gds_n_varinc in zip(unique_variant_id.unique_variant_id_gds_per_chr, ld_pruning.ld_pruning_output)) {
		call megastepB.subset_gds {
			input:
				gds_n_varinc = gds_n_varinc
		}
	}

}