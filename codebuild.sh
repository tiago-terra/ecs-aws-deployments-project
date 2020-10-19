#/bin/bash
# $1 - action - install/build/deploy

export IMAGE_TAG=$IMAGE_TAG
export KUBE_URL="https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/amd64/kubectl"
export AUTHENTICATOR_URL="https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-07-26/bin/linux/amd64/aws-iam-authenticator"

if [ -z $1 ];then echo "Argument missing!\nUsage: $0 \$action" && exit 255; fi

function build_push_ecr () {
  #Args - ECR REPO, IMAGE_TAG
  export IMAGE_URI="$1:$2"
  echo "Building docker image..."
  docker build -t $IMAGE_URI docker --build-arg IMAGE_TAG=$2
  echo "Pushing image with tag :$1 to repo $2..."
  docker push $IMAGE_URI  
  echo "Image pushed to ECR!"
}

function tools_install () {
  echo "Downloading kubectl..."
  curl -o kubectl $KUBE_URL && chmod +x ./kubectl
  mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
  PATH=$PATH:$HOME/bin
  echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
  source ~/.bashrc
  echo "kubectl installed!"
}

function kube_sub_vars () {
  # Args - deploy_type
  local SERVICE_FILE="service.yml"
  local DEPLOY_FILE="deployment.yml"
  local vars_string="\$ECR_REPO \$IMAGE_TAG \$TYPE" 

  for i in blue green rolling
    do
      sed "s|\${DEPLOY_TYPE}|$DEPLOY_TYPE|g;s|\${ECR_REPO}|$ECR_REPO|g;s|\${IMAGE_TAG}|$IMAGE_TAG|g" $DEPLOY_FILE > "${i}_$DEPLOY_FILE"
      sed "s|\${DEPLOY_TYPE}|$DEPLOY_TYPE|g" $SERVICE_FILE > "${i}_$SERVICE_FILE"
    done
}

function kube_deploy () {
  # $1 - manifest path

  cd $CODEBUILD_SRC_DIR/k8s
  kube_sub_vars $DEPLOY_TYPE

  echo "kubectl - applying "

  kubectl apply -f "${DEPLOY_TYPE}_deployment.yml" #&& kube_wait "${DEPLOY_TYPE}-app"
  kubectl apply -f "${DEPLOY_TYPE}_service.yml"

  if [ $DEPLOY_TYPE == 'green' ]; then
    kubectl delete -f blue-deployment
    kubectl delete service blue-lb
  fi

  echo "Cleaning k8s files..."
  rm -rf $DEPLOY_TYPE_*
  echo "k8s files cleaned!"
}

function kube_wait () {
    while [[ $(kubectl get pods -l app=$1 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; 
    do 
      echo "waiting for pod $1..." && sleep 1; 
    done
}

# Main operations
if [ $1 == 'install' ]; then tools_install; fi
if [ $1 == 'build' ] && [ $DEPLOY_TYPE != 'green' ]; then build_push_ecr $ECR_REPO $IMAGE_TAG; fi
if [ $1 == 'deploy' ]; then kube_deploy $CODEBUILD_SRC_DIR/k8s; fi