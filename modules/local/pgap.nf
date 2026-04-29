// ─────────────────────────────────────────────────────────────────────────────
// PGAP_PREP — Prepares inputs for NCBI PGAP + runs if Singularity is available
//
// PGAP REQUIRES a container runtime (Docker, Singularity, Podman).
// This module has two modes, controlled by params.pgap_container_runtime:
//
//   'singularity'  → runs PGAP end-to-end via Singularity (recommended on HPC)
//   'docker'       → runs PGAP via Docker (if available)
//   'prep_only'    → only generates input files; user runs PGAP manually
//
// To enable Singularity on SLURM:
//   Ask your sysadmin: "module load singularity" or "module load apptainer"
//   Then set: params.pgap_container_runtime = 'singularity'
// ─────────────────────────────────────────────────────────────────────────────

process PGAP_PREP {
    tag "$sample_id"
    label 'process_low'
    conda "${projectDir}/envs/pipa.yml"

    publishDir "${params.output_dir}/annotation/pgap_inputs/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)

    output:
    tuple val(sample_id), path("${sample_id}_pgap_inputs/"),     emit: input_dir
    tuple val(sample_id), path("${sample_id}_pgap_inputs/input.yaml"),  emit: input_yaml
    tuple val(sample_id), path("${sample_id}_pgap_inputs/submol.yaml"), emit: submol_yaml
    tuple val(sample_id), path("${sample_id}_pgap_inputs/${sample_id}.fasta"), emit: fasta

    script:
    def genus_species = params.annotation_genus && params.annotation_species
                        ? "${params.annotation_genus} ${params.annotation_species}"
                        : (params.annotation_genus ?: "Unknown")
    def strain        = params.annotation_strain ?: sample_id
    def locus_prefix  = params.locus_tag_prefix  ?: sample_id.take(9).toUpperCase().replaceAll(/[^A-Z0-9]/, '')
    def topology      = params.genome_topology   ?: "linear"
    def org_name      = "${genus_species} ${strain}"

    """
    mkdir -p ${sample_id}_pgap_inputs

    # ── 1. Copy / clean FASTA ─────────────────────────────────────────────
    # PGAP requires FASTA headers without spaces; replace spaces with underscores
    sed 's/ /_/g' ${assembly} > ${sample_id}_pgap_inputs/${sample_id}.fasta

    # ── 2. Generate submol.yaml ───────────────────────────────────────────
    cat > ${sample_id}_pgap_inputs/submol.yaml <<SUBMOL
topology: ${topology}
organism:
  genus_species: '${genus_species}'
  strain: '${strain}'
contact_info:
  last_name: '${params.contact_last_name  ?: 'Unknown'}'
  first_name: '${params.contact_first_name ?: 'Unknown'}'
  email: '${params.contact_email          ?: 'unknown@example.com'}'
  organization: '${params.organization    ?: 'Unknown'}'
  department: '${params.department        ?: 'Bioinformatics'}'
  street: '.'
  city: '.'
  postal_code: '.'
  country: '.'
authors:
  - author:
      first_name: '${params.contact_first_name ?: 'Unknown'}'
      last_name: '${params.contact_last_name   ?: 'Unknown'}'
locus_tag_prefix: '${locus_prefix}'
SUBMOL

    # ── 3. Generate input.yaml ────────────────────────────────────────────
    cat > ${sample_id}_pgap_inputs/input.yaml <<INPUTYML
fasta:
  class: File
  location: ${sample_id}.fasta
submol:
  class: File
  location: submol.yaml
INPUTYML

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  PGAP input files prepared for: ${sample_id}"
    echo "  Organism: ${org_name}"
    echo "  Location: \$(pwd)/${sample_id}_pgap_inputs/"
    echo ""
    echo "  To run PGAP you need a container runtime."
    echo "  Option A — Singularity (recommended on HPC):"
    echo "    module load singularity"
    echo "    ./pgap.py -r -o pgap_out \\\\   # pgap.py from ncbi/pgap GitHub"
    echo "      --container-runtime singularity \\\\"
    echo "      \$(pwd)/${sample_id}_pgap_inputs/input.yaml"
    echo ""
    echo "  Option B — Docker (if available):"
    echo "    ./pgap.py -r -o pgap_out \\\\"
    echo "      \$(pwd)/${sample_id}_pgap_inputs/input.yaml"
    echo ""
    echo "  Resources required: 32 GB RAM, ~30 GB disk (DB)"
    echo "═══════════════════════════════════════════════════════════"
    """
}


// ─────────────────────────────────────────────────────────────────────────────
// PGAP_RUN — Runs PGAP via Singularity (requires singularity in PATH)
// Only invoked when params.pgap_container_runtime == 'singularity'
// ─────────────────────────────────────────────────────────────────────────────

process PGAP_RUN {
    tag "$sample_id"
    label 'process_high'
    // No conda directive — PGAP runs inside Singularity container

    publishDir "${params.output_dir}/annotation/pgap/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(input_dir)

    output:
    tuple val(sample_id), path("${sample_id}_pgap_out/"),               emit: results
    tuple val(sample_id), path("${sample_id}_pgap_out/annot.gff"),      emit: gff,  optional: true
    tuple val(sample_id), path("${sample_id}_pgap_out/annot.gbk"),      emit: gbk,  optional: true
    tuple val(sample_id), path("${sample_id}_pgap_out/annot.faa"),      emit: faa,  optional: true

    script:
    def pgap_py    = params.pgap_py_path ?: "pgap.py"
    def runtime    = params.pgap_container_runtime ?: "singularity"
    def extra_args = params.pgap_extra_args ?: "--ignore-all-errors"

    """
    # Verify Singularity is available
    if ! command -v singularity &>/dev/null && ! command -v apptainer &>/dev/null; then
        echo "ERROR: singularity / apptainer not found in PATH." >&2
        echo "Ask your sysadmin to run: module load singularity" >&2
        echo "Or set params.pgap_container_runtime = 'prep_only' to skip this step." >&2
        exit 1
    fi

    RUNTIME_CMD=\$(command -v singularity || command -v apptainer)

    ${pgap_py} \\
        --container-runtime \${RUNTIME_CMD} \\
        --report-usage-false \\
        --output ${sample_id}_pgap_out \\
        ${extra_args} \\
        ${input_dir}/input.yaml \\
        2>&1

    echo "PGAP annotation complete for ${sample_id}" >&2
    """
}
