process FASTP {
    tag "$sample_id"
    label 'process_low'
    conda "${projectDir}/envs/pipa.yml"

    publishDir "${params.output_dir}/fastp", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}*.trimmed.fastq.gz"), emit: reads
    tuple val(sample_id), path("${sample_id}.fastp.json"),        emit: json
    tuple val(sample_id), path("${sample_id}.fastp.html"),        emit: html
    tuple val(sample_id), path("${sample_id}.fastp.log"),         emit: log

    script:
    def single_end   = reads instanceof Path || reads.size() == 1
    def adapter_opt  = params.adapter_file
                       ? "--adapter_fasta ${params.adapter_file}"
                       : (single_end ? "" : "--detect_adapter_for_pe")

    if (single_end) {
        """
        fastp \\
            --in1  ${reads[0]} \\
            --out1 ${sample_id}.trimmed.fastq.gz \\
            ${adapter_opt} \\
            --qualified_quality_phred ${params.min_base_quality} \\
            --length_required         ${params.min_read_length} \\
            --json  ${sample_id}.fastp.json \\
            --html  ${sample_id}.fastp.html \\
            --thread ${task.cpus} \\
            2> ${sample_id}.fastp.log
        """
    } else {
        """
        fastp \\
            --in1  ${reads[0]} \\
            --in2  ${reads[1]} \\
            --out1 ${sample_id}_R1.trimmed.fastq.gz \\
            --out2 ${sample_id}_R2.trimmed.fastq.gz \\
            ${adapter_opt} \\
            --qualified_quality_phred ${params.min_base_quality} \\
            --length_required         ${params.min_read_length} \\
            --correction \\
            --json  ${sample_id}.fastp.json \\
            --html  ${sample_id}.fastp.html \\
            --thread ${task.cpus} \\
            2> ${sample_id}.fastp.log
        """
    }
}
