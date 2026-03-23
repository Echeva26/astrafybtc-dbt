# dbt + CI (Astrafy take-home)

Este repositorio implementa la parte de **dbt-core + GitHub Actions** del challenge.

## Objetivo implementado

- Modelo `staging` desde `bigquery-public-data.crypto_bitcoin_cash.transactions` filtrando ultimos 3 meses.
- Modelo `mart` con balance neto por direccion, excluyendo direcciones con al menos una transaccion coinbase.
- Workflow de GitHub Actions para ejecutar `dbt run` y `dbt test` en cada Pull Request.

## Estructura

- `models/staging/stg_bch_transactions.sql`
- `models/marts/fct_address_balances_excluding_coinbase.sql`
- `models/sources.yml`
- `.github/workflows/dbt-ci.yml`

## Requisitos

- Python 3.10+ (recomendado 3.11)
- `dbt-core` + `dbt-bigquery`
- Proyecto GCP, datasets `staging` y `mart`, y service account creados por Terraform (repo `Task_2_terraform`)

## Ejecucion local

1. Crear entorno e instalar dbt:

```bash
python -m venv .venv
source .venv/bin/activate
pip install dbt-bigquery
```

2. Crear perfil local `~/.dbt/profiles.yml`:

```yaml
astrafy_bch:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: service-account
      project: <GCP_PROJECT_ID>
      dataset: staging
      keyfile: <RUTA_AL_JSON_DEL_SERVICE_ACCOUNT>
      location: US
      threads: 4
```

3. Opcional: sobreescribir datasets por variables de entorno:

```bash
export DBT_STAGING_DATASET=staging
export DBT_MART_DATASET=mart
```

4. Ejecutar:

```bash
dbt deps
dbt run
dbt test
```

## CI en GitHub Actions

El workflow `.github/workflows/dbt-ci.yml` se dispara en eventos de PR (`opened`, `synchronize`, `reopened`, `ready_for_review`) y ejecuta:

- `dbt deps`
- `dbt run`
- `dbt test`

### Secrets requeridos

- `GCP_SERVICE_ACCOUNT_KEY`: contenido JSON del service account.
- `GCP_PROJECT_ID`: project id destino para materializar modelos.
- `DBT_STAGING_DATASET`: dataset staging (ej. `staging`).
- `DBT_MART_DATASET`: dataset mart (ej. `mart`).

## Nota sobre alcance de datos

Para cumplir el requerimiento de coste, el modelo `staging` filtra a 3 meses. El `mart` se calcula sobre ese `staging`.
