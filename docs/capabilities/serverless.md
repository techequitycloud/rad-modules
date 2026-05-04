# Serverless

Serverless coverage is concentrated in two places: a Cloud Run + Cloud Service Mesh lab, and the Cloud Build pipelines that deliver every module.

## Cloud Run on Cloud Service Mesh

`scripts/gcp-cr-mesh/gcp-cr-mesh.sh` is an interactive lab automating the steps from <https://cloud.google.com/service-mesh/docs/configure-cloud-service-mesh-for-cloud-run>: enabling APIs (`run`, `dns`, `networkservices`, `networksecurity`, `trafficdirector`), creating the `Mesh` resource, deploying a Cloud Run destination service with `--no-allow-unauthenticated`, fronting it with a serverless NEG + global `INTERNAL_SELF_MANAGED` backend service + `HTTPRoute`, and invoking it from a mesh-enrolled `fortio` Cloud Run client.

The same Cloud Service Mesh that backs `modules/Bank_GKE/` and `modules/MC_Bank_GKE/` extends to Cloud Run via the serverless NEG. See [service-mesh](./service-mesh.md).

The script supports **preview / create / delete** modes, so the same flow tears down all the serverless resources at the end without manual cleanup.

## Serverless build & delivery

`rad-ui/automation/cloudbuild_deployment_{create,destroy,purge,update}.yaml` are Cloud Build pipelines — Google's serverless CI/CD platform. There are no self-hosted build runners; every module deployment runs in an ephemeral, fully managed builder. See [cicd](../practices/cicd.md).

## What is not here

Cloud Functions modules, Eventarc triggers, Pub/Sub processing pipelines, and Workflows orchestrations are not currently included. Natural additions to the `scripts/` catalog or as new entries under `modules/`.
