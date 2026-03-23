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

### Formato exacto de `GCP_SERVICE_ACCOUNT_KEY`

Debes pegar el **JSON completo** de la clave del service account, por ejemplo:

```json
{
  "type": "service_account",
  "project_id": "...",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "...",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "..."
}
```

### Troubleshooting del error de auth vacio

Si en logs ves variables vacias (`GCP_*` y `DBT_*`), GitHub no esta inyectando secrets al workflow. Las causas mas comunes:

- El PR viene desde un **fork** (por seguridad, secrets no se exponen en `pull_request`).
- El secret se creo en otro repo/organization distinto.
- Se uso un Environment con reglas y el job no esta apuntando a ese environment.

Para validar rapido:

1. Haz un branch en el **mismo repo** (no fork) y abre PR.
2. O ejecuta manualmente el workflow con `workflow_dispatch` desde la pestaña Actions.
3. Revisa que los 4 secrets esten en `Settings > Secrets and variables > Actions`.

## Nota sobre alcance de datos

Para cumplir el requerimiento de coste, el modelo `staging` filtra 3 meses. El `mart` se calcula sobre ese `staging`.

## Nota tecnica sobre schemas en dbt

Este repo incluye `macros/generate_schema_name.sql` para evitar que dbt concatene `target.dataset + "_" + schema`.
Asi, los modelos se materializan exactamente en los datasets `staging` y `mart` ya creados por Terraform, sin intentar crear datasets nuevos.
