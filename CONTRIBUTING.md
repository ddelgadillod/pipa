# Guía de Contribución

## Estrategia de ramas (Git Flow simplificado)

```
main          ← producción, solo merges desde develop via PR aprobado
develop       ← integración, rama base para nuevas HUs
feature/HU-XX ← una rama por historia de usuario
hotfix/desc   ← correcciones urgentes sobre main
```

## Flujo de trabajo por HU

```bash
# 1. Crear rama desde develop
git checkout develop
git pull origin develop
git checkout -b feature/HU-17-mlst

# 2. Implementar y hacer commits atómicos
git add modules/local/mlst.nf
git commit -m "feat(HU-17): add MLST module with mlst tool"

# 3. Asegurarse que lint y dry-run pasan localmente
nextflow lint main.nf
nextflow run main.nf -profile test -stub

# 4. Abrir PR hacia develop
# - Llenar la plantilla de PR
# - Referenciar el issue: "Closes #17"
# - Esperar aprobación del reviewer
```

## Convención de commits

```
feat(HU-XX): descripción corta      ← nueva funcionalidad
fix(HU-XX): descripción del bug     ← corrección
refactor: descripción               ← sin cambio funcional
docs: actualización de docs
test: añadir o actualizar tests
chore: tareas de mantenimiento
```

## Versionado (SemVer)

| Release | Version | Criterio |
|---------|---------|----------|
| R1      | v1.0.0  | Core assembly funcional |
| R2      | v2.0.0  | QC biológico + SLURM    |
| R3      | v3.0.0  | Tipificación + AMR      |
| R4      | v4.0.0  | Anotación + CI completo |

Hotfixes → incrementan el parche: v1.0.1, v2.0.1, etc.

## Evaluación de una HU

Antes de cerrar un issue de HU, verificar:
- [ ] Todos los criterios de aceptación marcados
- [ ] `nextflow run -profile test -stub` pasa
- [ ] `nextflow lint` sin errores
- [ ] `CHANGELOG.md` actualizado
- [ ] Parámetros nuevos documentados en `README.md`
- [ ] Ambiente conda actualizado si aplica
