#/bin/bash
export KUBE_URL="https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/amd64/kubectl"
export AUTHENTICATOR_URL="https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-07-26/bin/linux/amd64/aws-iam-authenticator"
export HELM_URL="https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3"
export CODE_DIR="$CODEBUILD_SCR_DIR/kubernetes/$PROJECT_NAME"
export IMAGE_TAG=$CODEBUILD_RESOLVED_SOURCE_VERSION
export IMAGE_URI="$ECR_REPO:$IMAGE_TAG"

function build_push_ecr ()
{
  echo "Building docker image..."
  docker build -t $IMAGE_URI docker --build-arg IMAGE_TAG=$IMAGE_TAG > /dev/null
  echo "Docker image build!"

  echo "Pushing image with tag :$1 to repo $2..."
  docker push $IMAGE_URI
  echo "Image pushed to ECR!"
}

function tools_install () {

  echo "Downloading kubectl..."
  curl -o kubectl $KUBE_URL && chmod +x ./kubectl > /dev/null

  echo "Downloading helm..."
  curl $HELM_URL  > get_helm.sh
  chmod 700 get_helm.sh
  ./get_helm.sh

  mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl
  PATH=$PATH:$HOME/bin
  echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
  source ~/.bashrc
  echo "kubectl installed!"
}

function kube_deploy () {
  cd "$CODEBUILD_SCR_DIR/kubernetes/$PROJECT_NAME"

  helm upgrade "${PROJECT_NAME}_${DEPLOY_TYPE}" . --set \
    appName=$PROJECT_NAME \
    appVersion=$CODEBUILD_RESOLVED_SOURCE_VERSION \
    appEnvironment=$DEPLOY_TYPE \
    replicaCount=$REPLICA_COUNT 

  EXTERNAL_IP=$(kubectl get svc "${DEPLOY_TYPE}-lb" -o 'jsonpath={..status.loadBalancer.ingress[*].hostname}')
  while [ -z $EXTERNAL_IP ]
  do
    echo "Waiting for External IP to be allocated..."
    EXTERNAL_IP=$(kubectl get svc "${DEPLOY_TYPE}-lb" -o 'jsonpath={..status.loadBalancer.ingress[*].hostname}')
  done

  echo "Waiting for $EXTERNAL_IP to be up..."
  until $(curl --output /dev/null --silent --head --fail $1); do
    printf '.'
    sleep 5
  done

  if [ $DEPLOY_TYPE == 'green' ]; then
    helm uninstall "${RELEASE_NAME}_BLUE"
  fi
}

# Main operations
case "$1" in
        install)
            tools_install
            ;;         
        build)
            build_push_ecr
            ;;
        deploy)
            kube_deploy
            ;;
esac