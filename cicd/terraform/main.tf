# VPC Network
resource "yandex_vpc_network" "main" {
  name = "${var.project_name}-${var.environment}-network"
}

# Subnets
resource "yandex_vpc_subnet" "public" {
  name           = "${var.project_name}-${var.environment}-public-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

resource "yandex_vpc_subnet" "private_app" {
  name           = "${var.project_name}-${var.environment}-private-app-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.2.0/24"]
}

resource "yandex_vpc_subnet" "private_db" {
  name           = "${var.project_name}-${var.environment}-private-db-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.3.0/24"]
}

# Security Groups
resource "yandex_vpc_security_group" "app_sg" {
  name       = "${var.project_name}-app-sg"
  network_id = yandex_vpc_network.main.id

  # SSH access
  rule {
    direction   = "ingress"
    description = "SSH access"
    v4_cidr_blocks = ["0.0.0.0/0"]
    protocol    = "TCP"
    port        = 22
  }

  # App port
  rule {
    direction   = "ingress"
    description = "App access"
    v4_cidr_blocks = ["0.0.0.0/0"]
    protocol    = "TCP"
    port        = 8000
  }

  # Outbound all
  rule {
    direction   = "egress"
    description = "Outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    protocol    = "ANY"
    from_port   = 0
    to_port     = 65535
  }
}

resource "yandex_vpc_security_group" "db_sg" {
  name       = "${var.project_name}-db-sg"
  network_id = yandex_vpc_network.main.id

  # PostgreSQL access from app
  rule {
    direction   = "ingress"
    description = "PostgreSQL access"
    security_group_id = yandex_vpc_security_group.app_sg.id
    protocol    = "TCP"
    port        = 5432
  }

  # SSH access from internal network
  rule {
    direction   = "ingress"
    description = "SSH access"
    v4_cidr_blocks = ["10.0.0.0/16"]
    protocol    = "TCP"
    port        = 22
  }

  # Outbound all
  rule {
    direction   = "egress"
    description = "Outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    protocol    = "ANY"
    from_port   = 0
    to_port     = 65535
  }
}

# Compute Instances
resource "yandex_compute_instance" "app" {
  name        = "${var.project_name}-app-${var.environment}"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = var.vm_resources_app.cores
    memory        = var.vm_resources_app.memory
    core_fraction = var.vm_resources_app.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = "fd89ovh4ticpo40dkbvd" # Ubuntu 22.04 (получить через yc compute image list)
      size     = 20
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_app.id
    security_group_ids = [yandex_vpc_security_group.app_sg.id]
    nat                = false
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    user-data = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - docker.io
        - docker-compose
      runcmd:
        - systemctl start docker
        - systemctl enable docker
        - usermod -aG docker ubuntu
    EOF
  }

  depends_on = [yandex_vpc_network.main]
}

resource "yandex_compute_instance" "db" {
  name        = "${var.project_name}-db-${var.environment}"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = var.vm_resources_db.cores
    memory        = var.vm_resources_db.memory
    core_fraction = var.vm_resources_db.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = "fd89ovh4ticpo40dkbvd" # Ubuntu 22.04
      size     = 50
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_db.id
    security_group_ids = [yandex_vpc_security_group.db_sg.id]
    nat                = false
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    user-data = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - postgresql
        - postgresql-contrib
      runcmd:
        - systemctl start postgresql
        - systemctl enable postgresql
        - sudo -u postgres psql -c "ALTER USER postgres PASSWORD '${var.db_password}';"
    EOF
  }

  depends_on = [yandex_vpc_network.main]
}

# Object Storage Bucket (S3-compatible)
resource "yandex_storage_bucket" "logs" {
  bucket = "${var.project_name}-${var.environment}-logs-${random_string.suffix.result}"
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "delete_old_versions"
    enabled = true
    noncurrent_version_expiration {
      days = 90
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Service Account for Object Storage access
resource "yandex_iam_service_account" "storage_sa" {
  name = "${var.project_name}-storage-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "storage_editor" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.storage_sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "storage_key" {
  service_account_id = yandex_iam_service_account.storage_sa.id
  description        = "Static access key for object storage"
}

# Static IP for NAT Gateway (if needed)
resource "yandex_vpc_address" "nat_ip" {
  name = "${var.project_name}-nat-ip"
  external_ipv4_address {
    zone_id = var.zone
  }
}

# NAT Gateway (for outbound internet access from private subnets)
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "${var.project_name}-nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "nat_route" {
  name       = "${var.project_name}-nat-route-table"
  network_id = yandex_vpc_network.main.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

# Associate route table with private subnets
resource "yandex_vpc_route_table_attachment" "app_route" {
  subnet_id      = yandex_vpc_subnet.private_app.id
  route_table_id = yandex_vpc_route_table.nat_route.id
}

resource "yandex_vpc_route_table_attachment" "db_route" {
  subnet_id      = yandex_vpc_subnet.private_db.id
  route_table_id = yandex_vpc_route_table.nat_route.id
}
