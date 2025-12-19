apiVersion: skaffold/v4beta1
kind: Config
metadata:
  name: ${APP_NAME}
build:
  artifacts:
    - image: ${IMAGE_NAME}
      context: .
  googleCloudBuild:
    projectId: ${PROJECT_ID}
    gradleImage: gradle:8.4.0-jdk17
    mavenImage: maven:3.9.5-eclipse-temurin-17
    kanikoImage: gcr.io/kaniko-project/executor:v1.17.0
manifests:
  rawYaml:
    - deploy.yaml
deploy:
  cloudrun: {}
