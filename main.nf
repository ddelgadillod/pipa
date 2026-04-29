#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { PIPA } from './workflows/pipa'

// ─── Input validation ──────────────────────────────────────────────────────────
def validateParams() {
    def errors = []
    if (!params.input_dir)    errors << "Missing required parameter: --input_dir"
    if (!params.output_dir)   errors << "Missing required parameter: --output_dir"
    if (!params.fastq_pattern) errors << "Missing required parameter: --fastq_pattern"
    if (params.spades_mode && !['careful', 'meta', 'plasmid', 'rna'].contains(params.spades_mode))
        errors << "Invalid --spades_mode: '${params.spades_mode}'. Choose from: careful, meta, plasmid, rna"
    if (errors) {
        errors.each { log.error it }
        exit 1
    }
}

// ─── Workflow entry ────────────────────────────────────────────────────────────
workflow {

    validateParams()

    log.info """
    ╔═══════════════════════════════════════════════════════════╗
    ║    PIPA — Pipeline for Integrated Prokaryotic Assembly    ║
    ╠═══════════════════════════════════════════════════════════╣
    ║  input_dir   : ${params.input_dir}
    ║  output_dir  : ${params.output_dir}
    ║  fastq_pattern: ${params.fastq_pattern}
    ║  single_end  : ${params.single_end}
    ║  spades_mode : ${params.spades_mode}
    ║  depth_cutoff: ${params.depth_cutoff ?: 'no downsampling'}
    ║  run_kraken2 : ${params.run_kraken2}
    ║  run_checkm2 : ${params.run_checkm2}
    ╚═══════════════════════════════════════════════════════════╝
    """.stripIndent()

    if (params.single_end) {
        reads_ch = Channel
            .fromPath("${params.input_dir}/${params.fastq_pattern}", checkIfExists: true)
            .map { file -> tuple(file.simpleName, [file]) }
    } else {
        reads_ch = Channel
            .fromFilePairs("${params.input_dir}/${params.fastq_pattern}", checkIfExists: true)
    }

    reads_ch.ifEmpty { error "No reads found matching: ${params.input_dir}/${params.fastq_pattern}" }

    PIPA(reads_ch)
}
