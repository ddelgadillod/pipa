process RASUSA_DOWNSAMPLE {
    tag "$sample_id"
    label 'process_low'
    conda "${projectDir}/envs/pipa.yml"

    publishDir "${params.output_dir}/downsampled", mode: 'copy'

    input:
    tuple val(sample_id), path(reads), val(genome_size)

    output:
    tuple val(sample_id), path("${sample_id}*.downsampled.fastq.gz"), emit: reads

    script:
    def single_end = reads instanceof Path || reads.size() == 1

    if (single_end) {
        """
        rasusa reads \\
            --input ${reads[0]} \\
            --coverage ${params.depth_cutoff} \\
            --genome-size ${genome_size} \\
            --output ${sample_id}.downsampled.fastq.gz \\
            --seed 42
        """
    } else {
        """
        rasusa reads \\
            --input ${reads[0]} ${reads[1]} \\
            --coverage ${params.depth_cutoff} \\
            --genome-size ${genome_size} \\
            --output ${sample_id}_R1.downsampled.fastq.gz ${sample_id}_R2.downsampled.fastq.gz \\
            --seed 42
        """
    }
}
