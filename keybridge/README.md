This is a Flask app for an ArgoCD project. We use a Jenkinsfile to accomplish the following:
 - checkout code from Github
 - build Docker image
 - push the build image to DockerHub
 - deploy the app to kubernetes cluster via ArgoCD
