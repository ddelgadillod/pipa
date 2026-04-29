# PIPA — Pipeline for Integrated Prokaryotic Assembly

**P**ipeline for **I**ntegrated **P**rokaryotic **A**ssembly — Nextflow DSL2 pipeline for high-throughput prokaryotic genome assembly from Illumina paired-end (or single-end) reads.  
Designed for **SLURM clusters** with **Mamba/Conda environments** — no Docker, no Apptainer required.

Designed for agronomic research contexts (plant pathogens, biocontrol agents, PGPR) at AGROSAVIA.

---

## Pipeline overview

```
Raw reads (FASTQ)
     │
     ├─► FastQC (raw)
     │
     ▼
  fastp ──► trimmed reads ──► FastQC (trimmed)
     │
     ├─► Mash ──► genome size estimate
     │
     ├─► [rasusa] ──► downsampled reads   (if --depth_cutoff)
     │
     ├─► [ConFindr] ──► contamination report   (if --run_confindr)
     │
     ▼
  SPAdes ──► scaffolds
     │
     ▼
  Filter contigs (min length)
     │
     ├─► QUAST ──── assembly stats
     │
     ├─► [CheckM2] ─ completeness / contamination   (if --run_checkm2)
     │
     └─► MultiQC ──► aggregated report
          └─► qc_summary.tsv  (PASS / WARN / FAIL per sample)
```

---

## Requirements

| Tool       | Version | Notes                        |
|------------|---------|------------------------------|
| Nextflow   | ≥ 23.04 | `conda install -c bioconda nextflow` |
| Mamba      | ≥ 1.5   | via Miniforge / Mambaforge   |

All bioinformatics tools are installed automatically into Conda environments the first time they are needed.

---

## Installation

### 1. Clone the repository

```bash
git clone <repo_url> pipa
cd pipa
```

### 2. Create the Conda environments

You can let Nextflow create them on the fly (recommended), or pre-build them manually:

```bash
# Main environment (FastQC, fastp, SPAdes, QUAST, Mash, ConFindr, rasusa…)
mamba env create -f envs/pipa.yml

# CheckM2 environment (isolated due to heavy ML dependencies)
mamba env create -f envs/checkm2.yml
```

### 3. Download the CheckM2 database (optional — skipped if `--run_checkm2 false`)

```bash
conda activate checkm2
checkm2 database --download --path /path/to/checkm2_db
```

### 4. Download the ConFindr database (optional — skipped if `--run_confindr false`)

```bash
conda activate pipa
confindr_download_databases -o /path/to/confindr_db
```

---

## Usage

### Quick start (local)

```bash
nextflow run main.nf \
    --input_dir   /path/to/reads \
    --output_dir  results \
    --fastq_pattern "*{_R,_}{1,2}*.fastq.gz" \
    -profile local
```

### On SLURM (recommended)

```bash
# Edit run_pipeline.sh to set INPUT_DIR / OUTPUT_DIR / SLURM_QUEUE
sbatch run_pipeline.sh

# Or pass as environment variables:
INPUT_DIR=/data/reads \
OUTPUT_DIR=/data/results \
SLURM_QUEUE=batch \
sbatch run_pipeline.sh
```

### Key parameters

| Parameter                     | Default                              | Description                                      |
|-------------------------------|--------------------------------------|--------------------------------------------------|
| `--input_dir`                 | **required**                         | Directory containing FASTQ files                 |
| `--output_dir`                | `results`                            | Output directory                                 |
| `--fastq_pattern`             | `*{_R,_}{1,2}*.fastq.gz`            | Glob pattern matching paired reads               |
| `--single_end`                | `false`                              | Set `true` for single-end reads                  |
| `--spades_mode`               | `careful`                            | `careful` \| `meta` \| `plasmid` \| `rna`        |
| `--depth_cutoff`              | _(none)_                             | Downsample to N× coverage before assembly        |
| `--min_contig_length`         | `500`                                | Filter contigs shorter than this (bp)            |
| `--run_confindr`              | `true`                               | Run ConFindr contamination check                 |
| `--run_checkm2`               | `true`                               | Run CheckM2 completeness/contamination check     |
| `--checkm2_db_path`           | _(auto-download)_                    | Path to pre-downloaded CheckM2 DIAMOND database  |
| `--confindr_db_path`          | _(bundled)_                          | Path to ConFindr rMLST database                  |
| `--prescreen_genome_size_check` | _(off)_                            | Abort if estimated genome > N bp                 |
| `--slurm_queue`               | `normal`                             | Default SLURM partition                          |
| `--slurm_account`             | _(none)_                             | SLURM account / project                          |
| `--max_cpus`                  | `16`                                 | Cap on CPUs per process                          |
| `--max_memory`                | `64.GB`                              | Cap on memory per process                        |

---

## Output structure

```
results/
├── assemblies/            # Filtered FASTA per sample  ← main deliverable
├── fastqc/                # FastQC HTML + zip (raw)
├── fastp/                 # Trimmed FASTQs + JSON/HTML reports
├── spades/                # SPAdes scaffolds + logs
├── quast/                 # QUAST reports per sample
├── checkm2/               # CheckM2 reports per sample
├── confindr/              # ConFindr reports per sample
├── multiqc/               # multiqc_report.html
├── qc_summary.tsv         # All samples: PASS / WARN / FAIL
├── qc_summary_flagged.tsv # Only flagged samples
└── pipeline_info/         # Nextflow report, timeline, trace, DAG
```

---

## QC thresholds

Edit `qc_conditions.yml` to adjust pass/warn/fail thresholds for:
- Assembly N50, total length, contig count
- CheckM2 completeness and contamination
- ConFindr contamination flag

---

## Profiles

| Profile   | Description                                      |
|-----------|--------------------------------------------------|
| `slurm`   | Submit all processes as SLURM jobs               |
| `local`   | Run everything locally (for testing)             |
| `test`    | Uses `test_input/`; disables CheckM2 / ConFindr  |

---

## Citation

If you use this pipeline, please cite the underlying tools:
- SPAdes: Bankevich et al., *J. Comput. Biol.* 2012
- QUAST: Gurevich et al., *Bioinformatics* 2013
- CheckM2: Chklovski et al., *Nat. Methods* 2023
- fastp: Chen et al., *Bioinformatics* 2018
- ConFindr: Robertson & Nash, *PeerJ* 2018
- Mash: Ondov et al., *Genome Biol.* 2016
- rasusa: Hall, *JOSS* 2022
