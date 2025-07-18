version 1.0

import "../structs/Structs.wdl"
import "../tasks/QC.wdl" as QC

workflow GetReadQC {

    meta {
        description: "Run multiqc on an array of input fastqs and output a multiqc report."
    }

    parameter_meta {
        reads_files: "Array of Fastq files."
        nanopore: "flag specifying if input is from nanopore [default: false]"
    }

    input {
        Array[File] reads_files
        Boolean nanopore = false
    }

    scatter(f in reads_files) {
        call QC.FastQC {
            input:
                reads = f,
                nanopore = nanopore
        }
    }

    call QC.MultiQC {
        input:
            input_files = FastQC.fastqc_data
    }

    output {
        Array[File] fastqc_data = FastQC.fastqc_data
        Array[File] fastqc_reports = FastQC.fastqc_report
        File multiqc_data = MultiQC.multiqc_data
        File multiqc_report = MultiQC.multiqc_report
    }
}