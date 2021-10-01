version 1.0

import "pc_variant_correlation.wdl" as pc_variant_correlation


# [1] find_unrelated -- outputs related and unrelated samples as RData files
task find_unrelated {
    input {
        File kinship_file

        # optional
        File? divergence_file
        File? sample_include_file
        String? out_prefix
        Float kinship_threshold = 0.044194174     # 2^(-9/2) (third-degree relatives and closer)
        Float divergence_threshold = 0.044194174  # 2^(-9/2)
        
        # runtime attributes
        Int addldisk = 5
        Int cpu = 2
        Int memory = 4
        Int preempt = 3
    }

    # Estimate disk size required
    Int kinship_size    = ceil(size(kinship_file, "GB"))
    Int final_disk_dize = kinship_size + addldisk

    # Are optional files definec?
    Boolean defDivergenceInclude = defined(divergence_file)
    Boolean defSampleInclude     = defined(sample_include_file)
    

    command <<<
        set -eux -o pipefail

        echo "Generating config file"
        # noquotes = argument has no quotes in the config file to match CWL config EXACTLY
        python << CODE
        import os

        f = open("find_unrelated.config", "a")

        f.write('kinship_file "~{kinship_file}"\n')

        if "~{defDivergenceInclude}" == "true":
            f.write('divergence_file "~{divergence_file}"\n')

        if ~{kinship_threshold} != 0.044194174:
            f.write("kinship_threshold ~{kinship_threshold}\n")

        if ~{divergence_threshold} != 0.044194174:
            f.write("divergence_threshold ~{divergence_threshold}\n")

        if "~{out_prefix}" != "":
                f.write('out_related_file "~{out_prefix}_related.RData"\n')
                f.write('out_unrelated_file "~{out_prefix}_unrelated.RData"\n')

        if "~{defSampleInclude}" == "true":
            f.write('sample_include_file "~{sample_include_file}"\n')

        f.close()

        CODE

        echo "Calling R script find_unrelated.R"
        R -q --vanilla --args find_unrelated.config < /usr/local/analysis_pipeline/R/find_unrelated.R
    >>>

    runtime {
        cpu: cpu
        docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
        disks: "local-disk " + final_disk_dize + " HDD"
        memory: "${memory} GB"
        preemptibles: "${preempt}"
    }
    output {
        File out_related_file   = if defined(out_prefix) then "~{out_prefix}_related.RData" else "related.RData"
        File out_unrelated_file = if defined(out_prefix) then "~{out_prefix}_unrelated.RData" else "unrelated.RData"
        File config_file        = "find_unrelated.config"
    }

}

# [2] pca_byrel -- calculates PC-Air PCs for unrelated samples 
##                 (then projects results onto relatives)
task pca_byrel {
    input {
        File gds_file
        File related_file
        File unrelated_file

        # optional
        File? sample_include_file
        File? variant_include_file

        Int n_pcs = 32
        String? out_prefix
        
        # runtime attributes
        Int addldisk = 5
        Int cpu = 4
        Int memory = 4
        Int preempt = 3
    }

    # Estimate disk size required
    Int gds_size        = ceil(size(gds_file, "GB"))
    Int final_disk_dize = gds_size + addldisk

    # Are optional files definec?
    Boolean defSampleInclude     = defined(sample_include_file)
    Boolean defVariantInclude    = defined(variant_include_file)
    

    command <<<
        set -eux -o pipefail

        echo "Generating config file"
        # noquotes = argument has no quotes in the config file to match CWL config EXACTLY
        python << CODE
        import os

        f = open("pca_byrel.config", "a")

        f.write('gds_file "~{gds_file}"\n')
        
        f.write('related_file "~{related_file}"\n')
        
        f.write('unrelated_file "~{unrelated_file}"\n')

        if "~{defVariantInclude}" == "true":
            f.write('variant_include_file "~{variant_include_file}"\n')     

        if ~{n_pcs} != "":
            f.write("n_pcs ~{n_pcs}\n")

        if "~{out_prefix}" != "":
                f.write('out_file "~{out_prefix}_pca.RData"\n')
                f.write('out_file_unrel "~{out_prefix}_pca_unrel.RData"\n')

        if "~{defSampleInclude}" == "true":
            f.write('sample_include_file "~{sample_include_file}"\n')

        f.close()

        CODE

        echo "Calling R script pca_byrel.R"
        R -q --vanilla --args pca_byrel.config < /usr/local/analysis_pipeline/R/pca_byrel.R
    >>>

    runtime {
        cpu: cpu
        docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
        disks: "local-disk " + final_disk_dize + " HDD"
        memory: "${memory} GB"
        preemptibles: "${preempt}"
    }
    output {
        File pcair_output           = if defined(out_prefix) then "~{out_prefix}_pca.RData" else "pca.RData"
        File pcair_output_unrelated = if defined(out_prefix) then "~{out_prefix}_pca_unrel.RData" else "pca_unrel.RData"
        File config_file            = "pca_byrel.config"
    }

}

# [3] pca_plots -- plots the PCs
task pca_plots {
    input {
        File pca_file

        # optional
        File? phenotype_file

        Int? n_pairs
        String? group
        String? out_prefix
        
        # runtime attributes
        Int addldisk = 5
        Int cpu = 2
        Int memory = 4
        Int preempt = 3
    }

    # Estimate disk size required
    Int pca_size        = ceil(size(pca_file, "GB"))
    Int final_disk_dize = pca_size + addldisk

    # Are optional files definec?
    Boolean defPhenotypeFile     = defined(phenotype_file)
    

    command <<<
        set -eux -o pipefail

        echo "Generating config file"
        
        python << CODE
        import os

        f = open("pca_plots.config", "a")

        f.write('pca_file "~{pca_file}"\n')
        
        if "~{n_pairs}" != "":
            f.write("n_pairs ~{n_pairs}\n")

        if "~{out_prefix}" != "":
                f.write('out_file_scree "~{out_prefix}_pca_scree.pdf"\n')
                f.write('out_file_pc12 "~{out_prefix}_pca_pc12.pdf"\n')
                f.write('out_file_parcoord "~{out_prefix}_pca_parcoord.pdf"\n')
                f.write('out_file_pairs "~{out_prefix}_pca_pairs.png"\n')

        if "~{group}" != "":
            f.write("group ~{group}\n")

        if "~{defPhenotypeFile}" == "true":
            f.write('phenotype_file "~{phenotype_file}"\n') 

        f.close()

        CODE

        echo "Calling R script pca_plots.R"
        R -q --vanilla --args pca_plots.config < /usr/local/analysis_pipeline/R/pca_plots.R 
    >>>

    runtime {
        cpu: cpu
        docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
        disks: "local-disk " + final_disk_dize + " HDD"
        memory: "${memory} GB"
        preemptibles: "${preempt}"
    }
    output {
        Array[File] pca_plots  = glob("*.p*")
        File config_file  = "pca_plots.config"
    }

}

# [4] variant_id_from_gds -- (optional) pull variant IDs from GDS file
task variant_id_from_gds {
    input {
        File gds_file
        String? out_file
        
        # runtime attributes
        Int addldisk = 5
        Int cpu = 2
        Int memory = 4
        Int preempt = 3
    }

    # Estimate disk size required
    Int gds_size        = ceil(size(gds_file, "GB"))
    Int final_disk_dize = gds_size + addldisk
    
    command <<<
        set -eux -o pipefail

        echo "Generating variant_id_from_gds.R w/ HereDoc"
        
        cat << 'EOF' > variant_id_from_gds.R
            library(argparser)
            library(SeqArray)

            argp <- arg_parser("variant_id_from_gds")
            argp <- add_argument(argp, "--gds_file", help="gds file")
            argp <- add_argument(argp, "--out_file", help="output file", default="variant_id.rds")
            argv <- parse_args(argp)

            gds <- seqOpen(argv$gds_file)
            var.id <- seqGetData(gds, "variant.id")
            saveRDS(var.id, file=argv$out_file)
            seqClose(gds)

        EOF

        echo "Set out_file if neccesary"
        if [[ -z "~{out_file}" ]]
        then
            Rscript variant_id_from_gds.R --gds_file ~{gds_file}
        else
            Rscript variant_id_from_gds.R --gds_file ~{gds_file} --out_file ~{out_file}
        fi
    >>>

    runtime {
        cpu: cpu
        docker: "uwgac/topmed-master@sha256:0bb7f98d6b9182d4e4a6b82c98c04a244d766707875ddfd8a48005a9f5c5481e"
        disks: "local-disk " + final_disk_dize + " HDD"
        memory: "${memory} GB"
        preemptibles: "${preempt}"
    }
    output {
        File output_file = glob("*.rds")[0]
    }

}


workflow pcair {
    input {
        File kinship_file
        File gds_file
        Array[File] gds_file_full

        String? out_prefix
        File? divergence_file
        File? sample_include_file
        File? variant_include_file
        File? phenotype_file
        Int? n_pairs
        Int? n_corr_vars
        Int? n_pcs
        Int? n_pcs_plot
        Int? n_perpage
        String? group = "NA"
        Boolean run_correlation = false
    }


    call find_unrelated {
        input:
            kinship_file=kinship_file,
            divergence_file=divergence_file,
            sample_include_file=sample_include_file,
            out_prefix = out_prefix
    }


    call pca_byrel {
        input:
            gds_file = gds_file,
            related_file = find_unrelated.out_related_file,
            unrelated_file = find_unrelated.out_unrelated_file,
            sample_include_file=sample_include_file,
            variant_include_file=variant_include_file,
            out_prefix = out_prefix
    }

    call pca_plots {
        input:
            pca_file = pca_byrel.pcair_output,
            phenotype_file = phenotype_file,
            out_prefix = out_prefix,
            n_pairs = n_pairs,
            group = group
    }

    if(run_correlation) {

        call variant_id_from_gds {
            input:
                gds_file = gds_file
        }

        call pc_variant_correlation.pc_variant_correlation as pc_variant_correlation_wf {
            input:
                out_prefix = out_prefix,
                gds_file_full = gds_file_full,
                variant_include_file = variant_id_from_gds.output_file,
                pca_file = pca_byrel.pcair_output_unrelated,
                n_corr_vars = n_corr_vars,
                n_pcs = n_pcs,
                n_pcs_plot = n_pcs_plot,
                n_perpage = n_perpage
        }
    }


    output {
        File out_unrelated_file = find_unrelated.out_unrelated_file
        File out_related_file = find_unrelated.out_related_file
        File pcair_output = pca_byrel.pcair_output
        Array[File] pcair_plots  = pca_plots.pca_plots
        Array[File]? pc_correlation_plots = pc_variant_correlation_wf.pc_correlation_plots
        Array[File]? pca_corr_gds = pc_variant_correlation_wf.pca_corr_gds
    }

    meta {
        author: "Julian Lucas"
        email: "juklucas@ucsc.edu"
    }
}