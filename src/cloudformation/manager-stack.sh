PS3="O que deseja fazer com a sua stack: "

items=("Criar Stack" "Excluir Stack" "Criar VPC" "Excluir VPC" "Criar DB" "Excluir DB" "Criar Cognito" "Excluir Cognito" "Criar API Gateway" "Excluir API Gateway" "Criar EKS" "Excluir EKS")

echo ">>>>> Obtendo definição dos atributos interno do script <<<<<"
AWS_REGION=us-east-1
VPC_STACK_NAME=lanchonete-do-bairro-vpc
DB_SQL_STACK_NAME=lanchonete-do-bairro-postgresql-instance1
DB_NOSQL_STACK_NAME=lanchonete-do-bairro-mongodb
COGNITO_STACK_NAME=lanchonete-do-bairro-cognito
API_GATEWAY_STACK_NAME=lanchonete-do-bairro-api-gateway
EKS_STACK_NAME=lanchonete-do-bairro-eks-cluster
AWS_ARN_ACCOUNT=$(aws sts get-caller-identity --query "Account" --output text)
wait

function createEKS {
  aws cloudformation create-stack \
    --region $AWS_REGION \
    --stack-name $EKS_STACK_NAME \
    --capabilities CAPABILITY_NAMED_IAM \
    --template-body file://eks-stack.yaml

  verifyStatus $EKS_STACK_NAME
  wait
  settingKubeConfig
  wait
}

function createCOGNITO {
  aws cloudformation create-stack \
    --region $AWS_REGION \
    --stack-name $COGNITO_STACK_NAME \
    --template-body file://cognito-stack.yaml

  verifyStatus $COGNITO_STACK_NAME
  wait
}

function createAPIGATEWAY {
  aws cloudformation create-stack \
    --region $AWS_REGION \
    --stack-name $API_GATEWAY_STACK_NAME \
    --template-body file://api-gateway-stack.yaml

  verifyStatus $API_GATEWAY_STACK_NAME
  wait
}

function createVPC {
  aws cloudformation create-stack \
    --region $AWS_REGION \
    --stack-name $VPC_STACK_NAME \
    --template-body file://vpc-stack.yaml

  verifyStatus $VPC_STACK_NAME
  wait
}

function createDB {
  aws cloudformation create-stack \
    --region $AWS_REGION \
    --stack-name $DB_SQL_STACK_NAME \
    --template-body file://db-sql-stack.yaml

  verifyStatus $DB_SQL_STACK_NAME
  wait
}

function deleteStack {
  aws cloudformation delete-stack \
      --region $AWS_REGION \
      --stack-name $1

  verifyStatus $1
  wait
}

function verifyStatus {
  started_date=$(date '+%H:%M:%S')
  start=`date +%s`
  while true; do
    if [[ $(aws cloudformation describe-stacks --region $AWS_REGION --stack-name $1 --query "Stacks[*].StackStatus" --output text) == CREATE_IN_PROGRESS ]]
    then
      echo -e "Stack status : CREATE IN PROGRESS"
      sleep 10
    elif [[ $(aws cloudformation describe-stacks --region $AWS_REGION --stack-name $1 --query "Stacks[*].StackStatus" --output text) == DELETE_IN_PROGRESS ]]
    then
      echo -e "Stack status : DELETE IN PROGRESS"
      sleep 10
    elif [[ $(aws cloudformation describe-stacks --region $AWS_REGION --stack-name $1 --query "Stacks[*].StackStatus" --output text) == CREATE_COMPLETE ]]
    then
      echo -e "Stack status : SUCCESSFULLY CREATED"
      end=`date +%s`
      runtime=$((end-start))
      finished_date=$(date '+%H:%M:%S')
      echo "started at :" $started_date
      echo "finished at :" $finished_date
      hours=$((runtime / 3600)); minutes=$(( (runtime % 3600) / 60 )); seconds=$(( (runtime % 3600) % 60 )); echo "Total time : $hours h $minutes min $seconds sec"
      break
    else
      echo -e "Stack status : $(aws cloudformation describe-stacks --region $AWS_REGION --stack-name $1 --query "Stacks[*].StackStatus" --output text) n"
      break
    fi
  done
}

function settingKubeConfig {
  aws eks --region $AWS_REGION update-kubeconfig --name $EKS_STACK_NAME
  wait
}

function deleteKubeCtlConfig {
  kubectl config unset users.arn:aws:eks:$AWS_REGION:$AWS_ARN_ACCOUNT:cluster/$EKS_STACK_NAME
  kubectl config unset clusters.arn:aws:eks:$AWS_REGION:$AWS_ARN_ACCOUNT:cluster/$EKS_STACK_NAME
  kubectl config unset contexts.arn:aws:eks:$AWS_REGION:$AWS_ARN_ACCOUNT:cluster/$EKS_STACK_NAME
  kubectl config delete-context arn:aws:eks:$AWS_REGION:$AWS_ARN_ACCOUNT:cluster/$EKS_STACK_NAME
  kubectl config delete-cluster arn:aws:eks:$AWS_REGION:$AWS_ARN_ACCOUNT:cluster/$EKS_STACK_NAME
  wait
}

function createStacks {
  echo "Creating :" $VPC_STACK_NAME
  createVPC
  echo "Creating :" $DB_SQL_STACK_NAME
  createDB
  echo "Creating :" $COGNITO_STACK_NAME
  createCOGNITO
  echo "Creating :" $API_GATEWAY_STACK_NAME
  createAPIGATEWAY
  echo "Creating :" $EKS_STACK_NAME
  createEKS
  settingKubeConfig
}

function deleteStacks {
  echo "Deleting :" $DB_SQL_STACK_NAME
  deleteStack $DB_SQL_STACK_NAME
  echo "Deleting :" $API_GATEWAY_STACK_NAME
  deleteStack $API_GATEWAY_STACK_NAME
  echo "Deleting :" $COGNITO_STACK_NAME
  deleteStack $COGNITO_STACK_NAME
  echo "Deleting :" $EKS_STACK_NAME
  deleteStack $EKS_STACK_NAME
  echo "Deleting :" $VPC_STACK_NAME
  deleteStack $VPC_STACK_NAME
  deleteKubeCtlConfig
}

select item in "${items[@]}" Quit
do
    case $REPLY in
        1) createStacks;;
        2) deleteStacks;;
        3) createVPC;;
        4) deleteStack $VPC_STACK_NAME;;
        5) createDB;;
        6) deleteStack $DB_SQL_STACK_NAME;;
        7) createCOGNITO;;
        8) deleteStack $COGNITO_STACK_NAME;;
        9) createAPIGATEWAY;;
        10) deleteStack $API_GATEWAY_STACK_NAME;;
        11) createEKS;;
        12) deleteStack $EKS_STACK_NAME;;
        $((${#items[@]}+1))) echo "We're done!"; break;;
        *) echo "Ooops - unknown choice $REPLY";;
    esac
done