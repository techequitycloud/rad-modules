# [START cloudbuild_quickstart_build]
steps:
- name: gcr.io/google.com/cloudsdktool/cloud-sdk:slim
  entrypoint: gcloud
  args: 
    [
      'deploy', 'releases', 'create', 'release-$_RELEASE_TIMESTAMP','--delivery-pipeline', '${PIPELINE_NAME}','--region', '${APP_REGION}','--images', 'app=wordpress:${IMAGE_VERSION}'
    ]
serviceAccount: 'projects/${PROJECT_ID}/serviceAccounts/cloudbuild-sa@${PROJECT_ID}.iam.gserviceaccount.com'
options:
  logging: CLOUD_LOGGING_ONLY
# [END cloudbuild_quickstart_build]
