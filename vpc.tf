provider "aws" {
  profile = "promedusa"
  region = "ap-south-1"
}

resource "aws_vpc" "medusa_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "medusa_subnet" {
  vpc_id                  = aws_vpc.medusa_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
}

resource "aws_security_group" "medusa_sg" {
  vpc_id = aws_vpc.medusa_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "medusa_cluster" {
  name = "medusa-cluster"
}

resource "aws_ecs_task_definition" "medusa_task" {
  family                   = "medusa-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "aws_vpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = arn:aws:iam::872138406351:role/medusa

  container_definitions = jsonencode([
    {
      name      = "medusa",
      image     = "872138406351.dkr.ecr.ap-south-1.amazonaws.com/medusa:latest",
      memory    = 1024,
      cpu       = 512,
      essential = true,
      environment = [
        { name = "DATABASE_URL", value = "postgres://user:password@rds-endpoint/dbname" }
      ],
      portMappings = [
        { containerPort = 80, hostPort = 80, protocol = "tcp" }
      ]
    }
  ])
}

resource "aws_ecs_service" "medusa_service" {
  name            = "medusa-service"
  cluster         = aws_ecs_cluster.medusa_cluster.id
  task_definition = aws_ecs_task_definition.medusa_task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.medusa_subnet.id]
    security_groups = [aws_security_group.medusa_sg.id]
    assign_public_ip = true
  }
}

