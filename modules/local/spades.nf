process SPADES {
    tag "$sample_id"
    label 'process_high'
    conda "${projectDir}/envs/pipa.yml"

    publishDir "${params.output_dir}/spades/${sample_id}", mode: 'copy',
               saveAs: { fn ->
                   fn.endsWith('.fasta') || fn.endsWith('.log') || fn.endsWith('.gfa') ? fn : null
               }

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}.scaffolds.fasta"), emit: scaffolds
    tuple val(sample_id), path("${sample_id}.contigs.fasta"),   emit: contigs,   optional: true
    tuple val(sample_id), path("${sample_id}.spades.log"),      emit: log
    tuple val(sample_id), path("${sample_id}.assembly.gfa"),    emit: gfa,       optional: true

    script:
    def single_end  = reads instanceof Path || reads.size() == 1
    def reads_args  = single_end ? "-s ${reads[0]}" : "-1 ${reads[0]} -2 ${reads[1]}"
    def mode_flag   = params.spades_mode == 'meta'    ? '--meta'
                    : params.spades_mode == 'plasmid' ? '--plasmid'
                    : params.spades_mode == 'rna'     ? '--rna'
                    : '--careful'
    def extra       = params.spades_extra_args ?: ''

    """
    spades.py \\
        ${reads_args} \\
        ${mode_flag} \\
        --threads ${task.cpus} \\
        --memory  ${(int)(task.memory.toGiga())} \\
        --outdir  spades_out \\
        ${extra} \\
        2>&1 | tee ${sample_id}.spades.log

    # Promote output files
    if [ -f spades_out/scaffolds.fasta ]; then
        cp spades_out/scaffolds.fasta ${sample_id}.scaffolds.fasta
    elif [ -f spades_out/contigs.fasta ]; then
        echo "No scaffolds.fasta produced; using contigs.fasta instead" >&2
        cp spades_out/contigs.fasta ${sample_id}.scaffolds.fasta
    else
        echo "ERROR: SPAdes did not produce assembly output for ${sample_id}" >&2
        cat ${sample_id}.spades.log >&2
        exit 1
    fi

    [ -f spades_out/contigs.fasta ]          && cp spades_out/contigs.fasta          ${sample_id}.contigs.fasta  || true
    [ -f spades_out/assembly_graph.fastg ]   && cp spades_out/assembly_graph.fastg   ${sample_id}.assembly.gfa   || true
    """
}
