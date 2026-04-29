nextflow.enable.dsl = 2

include { FASTQC            } from '../modules/local/fastqc'
include { FASTP             } from '../modules/local/fastp'
include { MASH_GENOME_SIZE  } from '../modules/local/mash_genome_size'
include { RASUSA_DOWNSAMPLE } from '../modules/local/rasusa_downsample'
include { KRAKEN2           } from '../modules/local/kraken2'
include { SPADES            } from '../modules/local/spades'
include { FILTER_CONTIGS    } from '../modules/local/filter_contigs'
include { QUAST             } from '../modules/local/quast'
include { CHECKM2           } from '../modules/local/checkm2'
include { PROKKA            } from '../modules/local/prokka'
include { BAKTA             } from '../modules/local/bakta'
include { PGAP_PREP         } from '../modules/local/pgap'
include { PGAP_RUN          } from '../modules/local/pgap'
include { MULTIQC           } from '../modules/local/multiqc'
include { QC_SUMMARY        } from '../modules/local/qc_summary'

workflow PROKARYOTE_ASSEMBLY {

    take:
    reads_ch  // [ sample_id, [read_files] ]

    main:

    // ── 1. FastQC on raw reads ─────────────────────────────────────────────
    FASTQC(reads_ch)

    // ── 2. Adapter trimming + per-read QC (fastp) ─────────────────────────
    FASTP(reads_ch)

    // ── 3. Genome size estimation (mash) ──────────────────────────────────
    MASH_GENOME_SIZE(FASTP.out.reads)

    // ── 4. Optional depth-based downsampling (rasusa) ─────────────────────
    if (params.depth_cutoff) {
        trimmed_with_size = FASTP.out.reads.join(
            MASH_GENOME_SIZE.out.genome_size
                .map { id, f -> [id, f.text.trim().toLong()] }
        )
        RASUSA_DOWNSAMPLE(trimmed_with_size)
        assembly_input_ch = RASUSA_DOWNSAMPLE.out.reads
    } else {
        assembly_input_ch = FASTP.out.reads
    }

    // ── 5. Taxonomic screening (Kraken2) — optional ───────────────────────
    if (params.run_kraken2) {
        if (!params.kraken2_db) {
            error "ERROR: --run_kraken2 is true but --kraken2_db is not set. " +
                  "Provide a Kraken2 database path or set --run_kraken2 false"
        }
        KRAKEN2(assembly_input_ch)
        kraken2_reports_ch = KRAKEN2.out.summary.map { id, f -> f }
    } else {
        kraken2_reports_ch = Channel.empty()
    }

    // ── 6. Assembly (SPAdes) ───────────────────────────────────────────────
    SPADES(assembly_input_ch)

    // ── 7. Filter contigs by minimum length ───────────────────────────────
    FILTER_CONTIGS(SPADES.out.scaffolds)

    // ── 8. Assembly statistics (QUAST) ────────────────────────────────────
    QUAST(FILTER_CONTIGS.out.fasta)

    // ── 9. Functional annotation ──────────────────────────────────────────
    def run_prokka = params.annotation_tool in ['prokka', 'both']
    def run_bakta  = params.annotation_tool in ['bakta',  'both']
    def run_pgap   = params.annotation_tool in ['pgap']

    if (run_prokka) {
        PROKKA(FILTER_CONTIGS.out.fasta)
    }

    if (run_bakta) {
        BAKTA(FILTER_CONTIGS.out.fasta)
    }

    if (run_pgap) {
        PGAP_PREP(FILTER_CONTIGS.out.fasta)
        if (params.pgap_container_runtime in ['singularity', 'docker']) {
            PGAP_RUN(PGAP_PREP.out.input_dir)
        }
    }

    // ── 9. Completeness / contamination (CheckM2) — optional ──────────────
    if (params.run_checkm2) {
        CHECKM2(FILTER_CONTIGS.out.fasta)
        checkm2_reports_ch = CHECKM2.out.report.map { id, r -> r }
    } else {
        checkm2_reports_ch = Channel.empty()
    }

    // ── 10. MultiQC aggregation ────────────────────────────────────────────
    multiqc_files = Channel.empty()
        .mix( FASTQC.out.zip.map  { id, zips -> zips }.flatten() )
        .mix( FASTP.out.json.map  { id, json -> json }           )
        .mix( QUAST.out.tsv.map   { id, tsv  -> tsv  }           )
        .mix( checkm2_reports_ch                                  )
        .collect()

    MULTIQC(multiqc_files)

    // ── 11. Cross-sample QC summary with pass/warn/fail ───────────────────
    QC_SUMMARY(
        QUAST.out.tsv.map            { id, f -> f }.collect(),
        checkm2_reports_ch.collect(),
        kraken2_reports_ch.collect(),
        FILTER_CONTIGS.out.stats.map { id, f -> f }.collect(),
        file(params.qc_conditions)
    )

    emit:
    assemblies   = FILTER_CONTIGS.out.fasta
    quast        = QUAST.out.results
    multiqc      = MULTIQC.out.report
    qc_summary   = QC_SUMMARY.out.tsv
}
