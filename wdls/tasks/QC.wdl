version 1.0

import "../structs/Structs.wdl"

task FastQC {
    meta {
        description: "Use FastQC to generate QC reports for a given input file of reads."
    }

    parameter_meta {
        reads: "Single file containing our reads. should be fastq.gz or bam"
        nanopore: "flag specifying if input is from nanopore [default: false]"
        runtime_attr_override: "Override the default runtime attributes."
    }

    input {
        File reads
        Boolean nanopore = false
        RuntimeAttr? runtime_attr_override
    }

    Int disk_size = 365 + ceil(size(reads, "GB"))
    String ext = sub(basename(reads), ".*\\.", "")
    String filename = sub(basename(reads), ext, "")

    command <<<
        set -euo pipefail

        NPROCS=$(cat /proc/cpuinfo | grep '^processor' | tail -n1 | awk '{print $NF+1}')

        if ~{nanopore}; then
            echo "Beginning execution of FastQC in Nanopore mode!"
            fastqc \
                --threads "$NPROCS"\
                --memory 15900 \
                --quiet \
                --nano \
                ~{reads}
            echo "Finished!"
        else
            echo "Beginning execution of FastQC."
            fastqc \
                --threads "$NPROCS"\
                --memory 15900 \
                --quiet \
                ~{reads}
            echo "Finished!"
        fi
    >>>

    output {
        File fastqc_data = "~{filename}_fastqc.zip"
        File fastqc_report = "~{filename}_fastqc.html"
    }

    #########################
    # BEGONE PREEMPTION
    RuntimeAttr default_attr = object {
        cpu_cores:          4,
        mem_gb:             16,
        disk_gb:            disk_size,
        boot_disk_gb:       50,
        preemptible_tries:  0,
        max_retries:        1,
        docker:             "mjfos2r/fastqc:latest"
    }
    RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])
    runtime {
        cpu:                    select_first([runtime_attr.cpu_cores,         default_attr.cpu_cores])
        memory:                 select_first([runtime_attr.mem_gb,            default_attr.mem_gb]) + " GiB"
        disks: "local-disk " +  select_first([runtime_attr.disk_gb,           default_attr.disk_gb]) + " SSD"
        bootDiskSizeGb:         select_first([runtime_attr.boot_disk_gb,      default_attr.boot_disk_gb])
        preemptible:            select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
        maxRetries:             select_first([runtime_attr.max_retries,       default_attr.max_retries])
        docker:                 select_first([runtime_attr.docker,            default_attr.docker])
    }
}

task MultiQC {
    meta {
        description: "Use multiqc to generate a single interactive report for an array of files."
    }

    parameter_meta {
        input_files: "Array of files to create a report for."
        runtime_attr_override: "Override the default runtime attributes."
    }

    input {
        Array[File] input_files
        RuntimeAttr? runtime_attr_override
    }

    Int disk_size = 365 + ceil(size(input_files, "GB"))

    command <<<
        set -euo pipefail

        NPROCS=$(cat /proc/cpuinfo | grep '^processor' | tail -n1 | awk '{print $NF+1}')

        mkdir input_data multiqc_out
        cp ~{sep=" " input_files} input_data/

        multiqc \
            --outdir multiqc_out \
            --zip-data-dir \
            --interactive \
            input_data

        echo "Finished!"
    >>>

    output {
        File multiqc_data = "multiqc_data.zip"
        File multiqc_report = "multiqc_report.html"
    }

    #########################
    # BEGONE PREEMPTION
    RuntimeAttr default_attr = object {
        cpu_cores:          8,
        mem_gb:             64,
        disk_gb:            disk_size,
        boot_disk_gb:       50,
        preemptible_tries:  0,
        max_retries:        1,
        docker:             "mjfos2r/fastqc:latest"
    }
    RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])
    runtime {
        cpu:                    select_first([runtime_attr.cpu_cores,         default_attr.cpu_cores])
        memory:                 select_first([runtime_attr.mem_gb,            default_attr.mem_gb]) + " GiB"
        disks: "local-disk " +  select_first([runtime_attr.disk_gb,           default_attr.disk_gb]) + " SSD"
        bootDiskSizeGb:         select_first([runtime_attr.boot_disk_gb,      default_attr.boot_disk_gb])
        preemptible:            select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
        maxRetries:             select_first([runtime_attr.max_retries,       default_attr.max_retries])
        docker:                 select_first([runtime_attr.docker,            default_attr.docker])
    }
}

task AIO_QC {
    meta {
        description: "Use FastQC to generate QC reports for an array of fastq.gz files and multiqc to compile the results into a single report."
    }

    parameter_meta {
        fastq_files: "Array of Fastq files."
        nanopore: "flag specifying if input is from nanopore [default: false]"
        runtime_attr_override: "Override the default runtime attributes."
    }

    input {
        Array[File] fastq_files
        Boolean nanopore = false
        RuntimeAttr? runtime_attr_override
    }

    Int disk_size = 365 + 2 * ceil(size(fastq_files, "GB"))

    command <<<
        set -euo pipefail

        NPROCS=$(cat /proc/cpuinfo | grep '^processor' | tail -n1 | awk '{print $NF+1}')

        mkdir -p fastqc_out multiqc_out
        if ~{nanopore}; then
            echo "Beginning execution of FastQC in Nanopore mode!"
            fastqc \
                --outdir fastqc_out \
                --threads "$NPROCS"\
                --memory 7900 \
                --quiet \
                --nano \
                ~{sep=" " fastq_files}
            echo "Finished!"
        else
            echo "Beginning execution of FastQC."
            fastqc \
                --outdir fastqc_out \
                --threads "$NPROCS"\
                --memory 7900 \
                --quiet \
                ~{sep=" " fastq_files}
            echo "Finished!"
        fi

        echo "Running MultiQC on our generated results!"
        multiqc \
            --outdir multiqc_out \
            --zip-data-dir \
            --interactive \
            fastqc_out
        echo "Finished!"

        echo "packaging up results for output."
        echo "compressing fastqc output..."
        tar -zcf fastqc_out.tar.gz fastqc_out/
        echo "compressing multiqc output..."
        tar -zcf multiqc_out.tar.gz multiqc_out/

    >>>

    output {
        Array[File] fastqc_reports = glob("fastqc_out/*.html")
        File multiqc_report_html = "multiqc_out/multiqc_report.html"
        File fastqc_data = "fastqc_out.tar.gz"
        File multiqc_data = "multiqc_out.tar.gz"
    }

    #########################
    # BEGONE PREEMPTION
    RuntimeAttr default_attr = object {
        cpu_cores:          8,
        mem_gb:             64,
        disk_gb:            disk_size,
        boot_disk_gb:       50,
        preemptible_tries:  0,
        max_retries:        1,
        docker:             "mjfos2r/fastqc:latest"
    }
    RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])
    runtime {
        cpu:                    select_first([runtime_attr.cpu_cores,         default_attr.cpu_cores])
        memory:                 select_first([runtime_attr.mem_gb,            default_attr.mem_gb]) + " GiB"
        disks: "local-disk " +  select_first([runtime_attr.disk_gb,           default_attr.disk_gb]) + " SSD"
        bootDiskSizeGb:         select_first([runtime_attr.boot_disk_gb,      default_attr.boot_disk_gb])
        preemptible:            select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
        maxRetries:             select_first([runtime_attr.max_retries,       default_attr.max_retries])
        docker:                 select_first([runtime_attr.docker,            default_attr.docker])
    }
}