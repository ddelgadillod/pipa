#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# run_pipeline.sh  —  Wrapper para el pipeline de ensamblaje procariota
#
# Por defecto corre en modo LOCAL (sin SLURM).
# Agrega --hpc para enviar jobs al clúster SLURM.
#
# Uso básico (local):
#   bash run_pipeline.sh --input_dir /data/reads --output_dir results
#
# Uso en clúster:
#   bash run_pipeline.sh --input_dir /data/reads --output_dir results --hpc
#
# Con sbatch (recomendado en HPC para el proceso orquestador):
#   sbatch run_pipeline.sh --input_dir /data/reads --output_dir results --hpc
# ─────────────────────────────────────────────────────────────────────────────

#SBATCH --job-name=prokaryote_asm
#SBATCH --output=logs/nextflow_%j.out
#SBATCH --error=logs/nextflow_%j.err
#SBATCH --time=48:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=2
#SBATCH --nodes=1

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
INPUT_DIR=""
OUTPUT_DIR="results"
FASTQ_PATTERN="*{_R,_}{1,2}*.fastq.gz"
SINGLE_END="false"
SPADES_MODE="careful"
DEPTH_CUTOFF=""
RUN_KRAKEN2="true"
RUN_CHECKM2="true"
KRAKEN2_DB=""
CHECKM2_DB=""
ANNOTATION_TOOL="none"
BAKTA_DB=""
ANNOTATION_GENUS=""
ANNOTATION_SPECIES=""
SLURM_QUEUE="normal"
SLURM_ACCOUNT=""
MAX_CPUS="16"
MAX_MEMORY="64.GB"
HPC_MODE="false"
EXTRA_NXF_ARGS=()

# ─── Parse arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --hpc)             HPC_MODE="true";                   shift ;;
        --input_dir)       INPUT_DIR="$2";                    shift 2 ;;
        --output_dir)      OUTPUT_DIR="$2";                   shift 2 ;;
        --fastq_pattern)   FASTQ_PATTERN="$2";                shift 2 ;;
        --single_end)      SINGLE_END="true";                 shift ;;
        --spades_mode)     SPADES_MODE="$2";                  shift 2 ;;
        --depth_cutoff)    DEPTH_CUTOFF="$2";                 shift 2 ;;
        --run_kraken2)     RUN_KRAKEN2="$2";                  shift 2 ;;
        --run_checkm2)     RUN_CHECKM2="$2";                  shift 2 ;;
        --kraken2_db)      KRAKEN2_DB="$2";                   shift 2 ;;
        --checkm2_db)      CHECKM2_DB="$2";                   shift 2 ;;
        --annotation_tool) ANNOTATION_TOOL="$2";              shift 2 ;;
        --bakta_db)        BAKTA_DB="$2";                     shift 2 ;;
        --annotation_genus)   ANNOTATION_GENUS="$2";          shift 2 ;;
        --annotation_species) ANNOTATION_SPECIES="$2";        shift 2 ;;
        --slurm_queue)     SLURM_QUEUE="$2";                  shift 2 ;;
        --slurm_account)   SLURM_ACCOUNT="$2";                shift 2 ;;
        --max_cpus)        MAX_CPUS="$2";                     shift 2 ;;
        --max_memory)      MAX_MEMORY="$2";                   shift 2 ;;
        *)                 EXTRA_NXF_ARGS+=("$1");            shift ;;
    esac
done

# ─── Validate ─────────────────────────────────────────────────────────────────
if [ -z "$INPUT_DIR" ]; then
    echo "ERROR: --input_dir es obligatorio." >&2
    echo "Uso: bash run_pipeline.sh --input_dir /ruta/reads [--hpc] [opciones]" >&2
    exit 1
fi

# ─── Determine profile ────────────────────────────────────────────────────────
if [ "$HPC_MODE" = "true" ]; then
    NXF_PROFILE="slurm"
    MODE_LABEL="SLURM (HPC)"
else
    NXF_PROFILE="local"
    MODE_LABEL="Local"
fi

# ─── Build optional NXF args ──────────────────────────────────────────────────
NXF_OPTS=()
[ -n "$DEPTH_CUTOFF"       ] && NXF_OPTS+=(--depth_cutoff       "$DEPTH_CUTOFF")
[ -n "$KRAKEN2_DB"         ] && NXF_OPTS+=(--kraken2_db         "$KRAKEN2_DB")
[ -n "$CHECKM2_DB"         ] && NXF_OPTS+=(--checkm2_db_path    "$CHECKM2_DB")
[ -n "$BAKTA_DB"           ] && NXF_OPTS+=(--bakta_db           "$BAKTA_DB")
[ -n "$ANNOTATION_GENUS"   ] && NXF_OPTS+=(--annotation_genus   "$ANNOTATION_GENUS")
[ -n "$ANNOTATION_SPECIES" ] && NXF_OPTS+=(--annotation_species "$ANNOTATION_SPECIES")
[ -n "$SLURM_ACCOUNT"      ] && NXF_OPTS+=(--slurm_account      "$SLURM_ACCOUNT")
[ "$SINGLE_END" = "true"   ] && NXF_OPTS+=(--single_end)

# ─── Environment ─────────────────────────────────────────────────────────────
source ~/.bashrc 2>/dev/null || true
mkdir -p logs

# ─── Summary ─────────────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════"
echo "  PIPA — Pipeline for Integrated Prokaryotic Assembly"
echo "  Modo de ejecucion : ${MODE_LABEL}"
echo "  Input dir         : ${INPUT_DIR}"
echo "  Output dir        : ${OUTPUT_DIR}"
echo "  SPAdes mode       : ${SPADES_MODE}"
echo "  Annotation        : ${ANNOTATION_TOOL}"
echo "  Kraken2           : ${RUN_KRAKEN2}"
echo "  CheckM2           : ${RUN_CHECKM2}"
echo "  Inicio            : $(date)"
echo "════════════════════════════════════════════════"

# ─── Run ─────────────────────────────────────────────────────────────────────
nextflow run "$(dirname "$0")/main.nf" \
    --input_dir       "$INPUT_DIR"       \
    --output_dir      "$OUTPUT_DIR"      \
    --fastq_pattern   "$FASTQ_PATTERN"   \
    --spades_mode     "$SPADES_MODE"     \
    --run_kraken2     "$RUN_KRAKEN2"     \
    --run_checkm2     "$RUN_CHECKM2"     \
    --annotation_tool "$ANNOTATION_TOOL" \
    --slurm_queue     "$SLURM_QUEUE"     \
    --max_cpus        "$MAX_CPUS"        \
    --max_memory      "$MAX_MEMORY"      \
    -profile          "$NXF_PROFILE"     \
    -resume           \
    "${NXF_OPTS[@]}"  \
    "${EXTRA_NXF_ARGS[@]}"

echo "════════════════════════════════════════════════"
echo "  Finalizado: $(date)"
echo "════════════════════════════════════════════════"
