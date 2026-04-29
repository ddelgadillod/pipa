process MASH_GENOME_SIZE {
    tag "$sample_id"
    label 'process_low'
    conda "${projectDir}/envs/pipa.yml"

    // Not published — intermediate result
    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}.genome_size.txt"), emit: genome_size

    script:
    def max_size = params.prescreen_genome_size_check ?: 0
    """
    # Sketch with the first read file (or the only one for SE)
    mash sketch \\
        -o sketch_${sample_id} \\
        -k 32 \\
        -r \\
        ${reads[0]} \\
        2> mash_stats.out || true

    # Parse estimated genome size
    GENOME_SIZE=\$(grep -i 'Estimated genome size' mash_stats.out \\
                  | awk '{print int(\$NF)}' || echo "")

    # Fallback if mash could not estimate
    if [ -z "\$GENOME_SIZE" ] || [ "\$GENOME_SIZE" -le 0 ]; then
        echo "WARNING: Could not estimate genome size for ${sample_id}; defaulting to 5 Mb" >&2
        GENOME_SIZE=5000000
    fi

    echo "  [mash] ${sample_id}: estimated genome size = \$GENOME_SIZE bp" >&2

    # Optional upper-bound prescreen
    if [ "${max_size}" -gt 0 ] && [ "\$GENOME_SIZE" -gt "${max_size}" ]; then
        echo "ERROR: Estimated genome size (\$GENOME_SIZE bp) exceeds limit (${max_size} bp)" >&2
        exit 1
    fi

    echo "\$GENOME_SIZE" > ${sample_id}.genome_size.txt
    """
}
