PS3="O que deseja fazer com a sua stack: "

items=("Criar Stack" "Excluir Stack" "Criar VPC" "Excluir VPC" "Criar EKS" "Excluir EKS")

echo ">>>>> Obtendo definição dos atributos interno do script <<<<<"
EKS_AWS_REGION=us-east-1
VPC_STACK_NAME=lanchonete-do-bairro-eks-vpc
EKS_STACK_NAME=lanchonete-do-bairro-eks-cluster
AWS_ARN_ACCOUNT=$(aws sts get-caller-identity --query "Account" --output text)
wait

function testing {
  echo $AWS_ARN_ACCOUNT
}

function createVPC {
  aws cloudformation create-stack \
    --region $EKS_AWS_REGION \
    --stack-name $VPC_STACK_NAME \
    --template-body file://eks-vpc-stack.yaml

  verifyStatus $VPC_STACK_NAME
  wait
}

function createEKS {
  aws cloudformation create-stack \
    --region $EKS_AWS_REGION \
    --stack-name $EKS_STACK_NAME \
    --capabilities CAPABILITY_NAMED_IAM \
    --template-body file://eks-stack.yaml

  verifyStatus $EKS_STACK_NAME
  wait
  settingKubeConfig
  wait
}

function deleteStack {
  aws cloudformation delete-stack \
      --region $EKS_AWS_REGION \
      --stack-name $1

  verifyStatus $1
  wait
}

function verifyStatus {
  started_date=$(date '+%H:%M:%S')
  start=`date +%s`
  while true; do
    if [[ $(aws cloudformation describe-stacks --region $EKS_AWS_REGION --stack-name $1 --query "Stacks[*].StackStatus" --output text) == CREATE_IN_PROGRESS ]]
    then
      echo -e "Stack status : CREATE IN PROGRESS"
      sleep 10
    elif [[ $(aws cloudformation describe-stacks --region $EKS_AWS_REGION --stack-name $1 --query "Stacks[*].StackStatus" --output text) == DELETE_IN_PROGRESS ]]
    then
      echo -e "Stack status : DELETE IN PROGRESS"
      sleep 10
    elif [[ $(aws cloudformation describe-stacks --region $EKS_AWS_REGION --stack-name $1 --query "Stacks[*].StackStatus" --output text) == CREATE_COMPLETE ]]
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
      echo -e "Stack status : $(aws cloudformation describe-stacks --region $EKS_AWS_REGION --stack-name $1 --query "Stacks[*].StackStatus" --output text) n"
      break
    fi
  done
}

function settingKubeConfig {
  aws eks --region $EKS_AWS_REGION update-kubeconfig --name $EKS_STACK_NAME
  wait
}

function deleteKubeCtlConfig {
  kubectl config unset users.arn:aws:eks:$EKS_AWS_REGION:$AWS_ARN_ACCOUNT:cluster/$EKS_STACK_NAME
  kubectl config unset clusters.arn:aws:eks:$EKS_AWS_REGION:$AWS_ARN_ACCOUNT:cluster/$EKS_STACK_NAME
  kubectl config unset contexts.arn:aws:eks:$EKS_AWS_REGION:$AWS_ARN_ACCOUNT:cluster/$EKS_STACK_NAME
  kubectl config delete-context arn:aws:eks:$EKS_AWS_REGION:$AWS_ARN_ACCOUNT:cluster/$EKS_STACK_NAME
  kubectl config delete-cluster arn:aws:eks:$EKS_AWS_REGION:$AWS_ARN_ACCOUNT:cluster/$EKS_STACK_NAME
  wait
}

function createStacks {
  createVPC
  createEKS
  settingKubeConfig
}

function deleteStacks {
  deleteStack $EKS_STACK_NAME
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
        5) createEKS;;
        6) deleteStack $EKS_STACK_NAME;;
        $((${#items[@]}+1))) echo "We're done!"; break;;
        *) echo "Ooops - unknown choice $REPLY";;
    esac
done