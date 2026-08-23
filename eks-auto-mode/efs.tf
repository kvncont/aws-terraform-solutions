###########################
##### Amazon EFS
###########################

resource "aws_efs_file_system" "this" {
  creation_token = "efs-${local.project_name}"
  encrypted      = true

  tags = {
    Name = "efs-${local.project_name}"
  }
}

resource "aws_efs_mount_target" "this" {
  count = length(local.network_subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = local.network_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "this" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/eks"

    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "0700" #755
    }
  }

  tags = {
    Name = "efs-ap-${local.project_name}"
  }
}
