resource "aws_security_group" "jenkins" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins server"
  vpc_id      = "vpc-0b87b2b85f18eccc0"

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["106.219.120.205/32"]
  }

  ingress {
    description = "Jenkins from my IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SonarQube Lab"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["106.219.120.205/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sg"
  }
}

resource "aws_instance" "jenkins" {
  ami           = "ami-0b245cc5f82576748"
  instance_type = "m7i-flex.large"

  key_name = "dev1_ec2_key"

  subnet_id = "subnet-0c1351f3fec9d49b9"

  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.jenkins.id]

  iam_instance_profile = aws_iam_instance_profile.jenkins.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "jenkins-server"
  }
}

resource "aws_ecr_repository" "app" {
  name = "complete-devops-automation"

  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_iam_role" "jenkins_ecr" {
  name = "jenkins-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "jenkins_ecr" {
  name = "jenkins-ecr-policy"
  role = aws_iam_role.jenkins_ecr.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]

        Resource = aws_ecr_repository.app.arn
      },

      {
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          "arn:aws:s3:::anis-terraform-state-521464398227/jenkins-lab/terraform.tfstate",
          "arn:aws:s3:::anis-terraform-state-521464398227/jenkins-lab/terraform.tfstate.tflock"
        ]
      },
      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = "arn:aws:s3:::anis-terraform-state-521464398227"

        Condition = {
          StringLike = {
            "s3:prefix" = [
              "jenkins-lab/*"
            ]
          }
        }
      },

      {
        Effect = "Allow"

        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:GetInstanceProfile",
          "iam:ListRolePolicies"
        ]

        Resource = "*"
      },

      {
        Effect = "Allow"

        Action = [
          "sts:AssumeRole"
        ]

        Resource = aws_iam_role.terraform_deployment.arn
      }

    ]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "jenkins-ecr-profile"
  role = aws_iam_role.jenkins_ecr.name
}


resource "aws_iam_role" "terraform_deployment" {
  name = "terraform-deployment-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          AWS = aws_iam_role.jenkins_ecr.arn
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_deployment_admin" {
  role       = aws_iam_role.terraform_deployment.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

