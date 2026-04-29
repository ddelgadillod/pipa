# Changelog

All notable changes to this project will be documented in this file.  
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

## [2.0.0] — R2: Calidad Biológica
### Added
- HU-11: Detección de contaminación con ConFindr (`modules/local/confindr.nf`)
- HU-12: Evaluación de completitud con CheckM2 en ambiente conda aislado (`envs/checkm2.yml`)
- HU-13: Resumen QC PASS/WARN/FAIL (`bin/qc_summary.py`, `qc_conditions.yml`)
- HU-14: Profile SLURM sin contenedores (`conf/slurm.config`)
- HU-15: Labels de recursos + retry automático en OOM (`conf/base.config`)
- HU-16: Reportes de traza, timeline y DAG en `pipeline_info/`

## [1.0.0] — R1: Core Assembly
### Added
- HU-01: Descubrimiento automático de muestras PE/SE con patrón glob
- HU-02: Validación de parámetros obligatorios al inicio del pipeline
- HU-03: FastQC en lecturas crudas
- HU-04: Trimming con fastp (PE/SE, auto-detect adaptadores)
- HU-05: Estimación de tamaño del genoma con Mash + prescreen opcional
- HU-06: Downsampling a profundidad objetivo con rasusa
- HU-07: Ensamblaje con SPAdes (modos: careful, meta, plasmid, rna)
- HU-08: Filtrado de contigs por longitud mínima con renombrado por muestra
- HU-09: Métricas de ensamblaje con QUAST
- HU-10: Reporte MultiQC agregado
