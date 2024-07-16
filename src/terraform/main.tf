provider "aws" {
  region     = "us-east-1"
  access_key = var.TF_VAR_AWS_ACCESS_KEY
  secret_key = var.TF_VAR_AWS_SECRET_KEY
}

# VPC #
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "lanchonete-do-bairro-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  enable_vpn_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# DB SQL POSTGRES #
resource "aws_security_group" "postgres" {
  name        = "postgres-security-group"
  description = "Security group for Postgres database"

  ingress {
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5433
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgresql-instance1" {
  allocated_storage    = 5
  storage_type         = "gp2"
  instance_class       = "db.t3.micro"
  identifier           = "postgresql-instance1"
  engine               = "postgres"
  engine_version       = "16.2"
  parameter_group_name = "default.postgres16"

  db_name  = "db_lanchonete_do_bairro"
  username = var.TF_VAR_POSTGRES_USER
  password = var.TF_VAR_POSTGRES_PASSWORD

  port = 5433

  vpc_security_group_ids = [aws_security_group.postgres.id]
  publicly_accessible    = true
  skip_final_snapshot    = true
}

# COGNITO #
resource "aws_cognito_user_pool_domain" "user_pool_domain" {
  domain       = "lanchonete-do-bairro-domain"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

resource "aws_cognito_user_pool" "user_pool" {
  name                     = "lanchonete-do-bairro-pool"
  auto_verified_attributes = ["email"]
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = false
    required                 = true
    string_attribute_constraints {
      min_length = 0
      max_length = 255
    }
  }
  schema {
    name                     = "name"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = false
    required                 = true
    string_attribute_constraints {
      min_length = 0
      max_length = 255
    }
  }
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name = "lanchonete-do-bairro.api"

  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  generate_secret              = false
  supported_identity_providers = ["COGNITO"]
  explicit_auth_flows          = ["ALLOW_ADMIN_USER_PASSWORD_AUTH", "ALLOW_USER_PASSWORD_AUTH", "ALLOW_CUSTOM_AUTH", "ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}

# API GATEWAY #
resource "aws_api_gateway_rest_api" "rest_api" {
  name = "lanchonete_do_bairro_api_gateway"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name          = "CognitoAuthorizer"
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.user_pool.arn]
}

# API #
resource "aws_api_gateway_resource" "root_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "api"
}

# V1 #
resource "aws_api_gateway_resource" "v1_root_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.root_api_resource.id
  path_part   = "v1"
}

# CLIENTS #
resource "aws_api_gateway_resource" "clients_root_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.v1_root_api_resource.id
  path_part   = "clients"
}

# CLIENT - SIGN IN #
resource "aws_api_gateway_resource" "client_sign_in_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.clients_root_api_resource.id
  path_part   = "sign-in"
}

resource "aws_api_gateway_method" "client_sign_in_api_resource_mock_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.client_sign_in_api_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "client_sign_in_api_resource_mock_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.client_sign_in_api_resource.id
  http_method             = aws_api_gateway_method.client_sign_in_api_resource_mock_method.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://aa7b2f337f86d4a178733171e42972cf-1841160873.us-east-1.elb.amazonaws.com/api/v1/clients/sign-in"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = "{'statusCode': 200}"
  }
}

resource "aws_api_gateway_method_response" "client_sign_in_api_resource_mock_method_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.client_sign_in_api_resource.id
  http_method = aws_api_gateway_method.client_sign_in_api_resource_mock_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "client_sign_in_api_resource_mock_method_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.client_sign_in_api_resource.id
  http_method = aws_api_gateway_method.client_sign_in_api_resource_mock_method.http_method
  status_code = aws_api_gateway_method_response.client_sign_in_api_resource_mock_method_response.status_code
}

# CLIENT - SIGN UP #
resource "aws_api_gateway_resource" "client_sign_up_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.clients_root_api_resource.id
  path_part   = "sign-up"
}

resource "aws_api_gateway_method" "client_sign_up_api_resource_mock_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.client_sign_up_api_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "client_sign_up_api_resource_mock_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.client_sign_up_api_resource.id
  http_method             = aws_api_gateway_method.client_sign_up_api_resource_mock_method.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://aa7b2f337f86d4a178733171e42972cf-1841160873.us-east-1.elb.amazonaws.com/api/v1/clients/sign-up"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = "{'statusCode': 200}"
  }
}

resource "aws_api_gateway_method_response" "client_sign_up_api_resource_mock_method_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.client_sign_up_api_resource.id
  http_method = aws_api_gateway_method.client_sign_up_api_resource_mock_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "client_sign_up_api_resource_mock_method_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.client_sign_up_api_resource.id
  http_method = aws_api_gateway_method.client_sign_up_api_resource_mock_method.http_method
  status_code = aws_api_gateway_method_response.client_sign_up_api_resource_mock_method_response.status_code
}

# CLIENT - GET CLIENT BY ID #
resource "aws_api_gateway_resource" "clients_proxy_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.clients_root_api_resource.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "client_get_by_id_api_resource_mock_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.clients_proxy_api_resource.id
  http_method   = "ANY"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "client_get_by_id_api_resource_mock_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.clients_proxy_api_resource.id
  http_method             = aws_api_gateway_method.client_get_by_id_api_resource_mock_method.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://aa7b2f337f86d4a178733171e42972cf-1841160873.us-east-1.elb.amazonaws.com/{proxy}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = "{'statusCode': 200}"
  }

  cache_key_parameters = ["method.request.path.proxy"]
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

resource "aws_api_gateway_method_response" "client_get_by_id_api_resource_mock_method_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.clients_proxy_api_resource.id
  http_method = aws_api_gateway_method.client_get_by_id_api_resource_mock_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "client_get_by_id_api_resource_mock_method_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.clients_proxy_api_resource.id
  http_method = aws_api_gateway_method.client_get_by_id_api_resource_mock_method.http_method
  status_code = aws_api_gateway_method_response.client_get_by_id_api_resource_mock_method_response.status_code
}

# CATALOG #
resource "aws_api_gateway_resource" "catalog_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.v1_root_api_resource.id
  path_part   = "catalog"
}

resource "aws_api_gateway_resource" "catalog_proxy_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.catalog_api_resource.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "catalog_api_resource_mock_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.catalog_api_resource.id
  http_method   = "ANY"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "catalog_api_resource_mock_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.catalog_api_resource.id
  http_method             = aws_api_gateway_method.catalog_api_resource_mock_method.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://aa7b2f337f86d4a178733171e42972cf-1841160873.us-east-1.elb.amazonaws.com/{proxy}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = "{'statusCode': 200}"
  }

  cache_key_parameters = ["method.request.path.proxy"]
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

resource "aws_api_gateway_method_response" "catalog_api_resource_mock_method_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.catalog_api_resource.id
  http_method = aws_api_gateway_method.catalog_api_resource_mock_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "catalog_api_resource_mock_method_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.catalog_api_resource.id
  http_method = aws_api_gateway_method.catalog_api_resource_mock_method.http_method
  status_code = aws_api_gateway_method_response.catalog_api_resource_mock_method_response.status_code
}

# ORDERS #
resource "aws_api_gateway_resource" "orders_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.v1_root_api_resource.id
  path_part   = "orders"
}

resource "aws_api_gateway_resource" "orders_proxy_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.orders_api_resource.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "orders_api_resource_mock_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.orders_api_resource.id
  http_method   = "ANY"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "orders_api_resource_mock_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.orders_api_resource.id
  http_method             = aws_api_gateway_method.orders_api_resource_mock_method.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://aa7b2f337f86d4a178733171e42972cf-1841160873.us-east-1.elb.amazonaws.com/{proxy}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = "{'statusCode': 200}"
  }

  cache_key_parameters = ["method.request.path.proxy"]
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

resource "aws_api_gateway_method_response" "orders_api_resource_mock_method_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.orders_api_resource.id
  http_method = aws_api_gateway_method.orders_api_resource_mock_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "orders_api_resource_mock_method_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.orders_api_resource.id
  http_method = aws_api_gateway_method.orders_api_resource_mock_method.http_method
  status_code = aws_api_gateway_method_response.orders_api_resource_mock_method_response.status_code
}

# PAYMENTS #
resource "aws_api_gateway_resource" "payments_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.v1_root_api_resource.id
  path_part   = "payments"
}

resource "aws_api_gateway_resource" "payments_proxy_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.payments_api_resource.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "payments_api_resource_mock_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.payments_api_resource.id
  http_method   = "ANY"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "payments_api_resource_mock_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.payments_api_resource.id
  http_method             = aws_api_gateway_method.payments_api_resource_mock_method.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://aa7b2f337f86d4a178733171e42972cf-1841160873.us-east-1.elb.amazonaws.com/{proxy}"
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = "{'statusCode': 200}"
  }

  cache_key_parameters = ["method.request.path.proxy"]
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

resource "aws_api_gateway_method_response" "payments_api_resource_mock_method_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.payments_api_resource.id
  http_method = aws_api_gateway_method.payments_api_resource_mock_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "payments_api_resource_mock_method_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.payments_api_resource.id
  http_method = aws_api_gateway_method.payments_api_resource_mock_method.http_method
  status_code = aws_api_gateway_method_response.payments_api_resource_mock_method_response.status_code
}

# STAGE #
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.rest_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = "dev"
}

# EKS ROLES #
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com", "ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_iam_role" {
  name               = "eks-cluster-role-lanchonete-do-bairro"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_iam_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_iam_role.name
}

# EKS CLUSTER #
resource "aws_eks_cluster" "eks_cluster" {
  name     = "lanchonete-do-bairro-eks-cluster"
  role_arn = aws_iam_role.eks_iam_role.arn

  vpc_config {
    subnet_ids = module.vpc.public_subnets
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
}

data "aws_eks_cluster_auth" "default" {
  name = aws_eks_cluster.eks_cluster.name
}

resource "aws_eks_access_entry" "eks_lanchonete_do_bairro" {
  cluster_name      = aws_eks_cluster.eks_cluster.name
  principal_arn     = aws_iam_role.eks_iam_role.arn
  kubernetes_groups = ["group-1", "group-2"]
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "eks_access_policy_association" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.eks_iam_role.arn

  access_scope {
    type       = "namespace"
    namespaces = ["example-namespace"]
  }
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_iam_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_iam_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_iam_role.name
}

resource "aws_eks_node_group" "example" {
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "node_group_name"
  node_role_arn   = aws_iam_role.eks_iam_role.arn
  subnet_ids = module.vpc.private_subnets
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.default.token
}