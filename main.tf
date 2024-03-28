module "tagger2" {
  source              = "app.terraform.io/thehartford/tagging/aws"
  version             = ">=2.0.0, <3.0.0"
  #source = "git::https://github.thehartford.com/HIG/terraform-aws-tagging?ref=dbms"

  app_id              = var.app_id
  app_name            = var.app_name
  app_tier            = "DB" 
  data_classification = var.data_classification  
  db_nodes            = var.db_nodes 
  environment         = var.mssql_environment
  environment_type    = var.planit_env
  owner_email         = var.email
  patch_group         = var.patch_group  
  pipeline            = var.pipeline_url
  repository          = var.gh_repository_url
  resource            = "EBS"
  schedule            = "None"
  service_tier        = var.service_tier
}

module "tagger3" {
  source              = "app.terraform.io/thehartford/tagging/aws"
  version             = ">=2.0.0, <3.0.0"
  #source = "git::https://github.thehartford.com/HIG/terraform-aws-tagging?ref=dbms"

  app_id              = var.app_id
  app_name            = var.app_name
  app_tier            = "DB" 
  backup_group        = var.ec2_backup_required == true ? local.ec2_backup_group[var.planit_env] : "ec2-nobackup"
  data_classification = var.data_classification  
  db_nodes            = var.db_nodes 
  environment         = var.mssql_environment
  environment_type    = var.planit_env
  owner_email         = var.email
  patch_group         = var.patch_group  
  pipeline            = var.pipeline_url
  repository          = var.gh_repository_url
  resource            = "DBMS"
  schedule            = "None"
  service_tier        = var.service_tier
}
  
resource "aws_network_interface" "sql_nic" {
  subnet_id          = length(local.temp_subnet_id_list) > 0 ? local.temp_subnet_id_list[0] : null
  security_groups    = var.vpc_security_group_ids
  private_ips_count  = var.secondary_ips
}

module "server" {
  source                            = "app.terraform.io/thehartford/ec2-instance/aws"
  version                           = ">=4.0.0, <=4.3.1"
  #source = "git::https://github.thehartford.com/HIG/terraform-aws-ec2-instance.git?ref=cpuoptionsfix"
  
  account_id                        = var.account_id
  ami_id                            = var.ami_id
  app_id                            = var.app_id
  app_name                          = var.app_name
  app_tier                          = var.app_tier 
  availability_zone                 = var.az
  backup_required                   = var.ec2_backup_required
  create_kms_key                    = var.create_kms_key
  #cpu_core_count                   = local.cpu_core_count
  #cpu_threads_per_core             = var.cpu_threads_per_core
  cpu_options                       = {
                                        core_count              = local.cpu_core_count
                                        threads_per_core        = var.cpu_threads_per_core
                                      }
  cw_mem_utilization_high_threshold = var.cw_mem_utilization_high_threshold
  data_classification               = var.data_classification
  db_nodes                          = var.db_nodes
  create_recoveralarm               = var.create_recoveralarm ##New Input in v4.2.
  ebs_optimized                     = true
  email                             = var.email
  employee_id                       = var.employee_id
  env                               = var.mssql_environment
  gh_repository_url                 = var.gh_repository_url
  hibernation                       = var.hibernation
  iam_instance_profile              = var.iam_instance_profile
  instance_type                     = var.instance_type
  key_name                          = var.key_name
  kms_key_id                        = var.kms_key_id
  network_interface                 = [
    {
      device_index                  = 0
      network_interface_id          = aws_network_interface.sql_nic.id
      delete_on_termination         = false
    }
  ]
  os                                = var.os
  patch_group                       = var.patch_group
  planit_env                        = var.planit_env
  pipeline_url                      = var.pipeline_url
  server_resource_code              = lower(var.mssql_installtype)
  service_tier                      = var.service_tier
  subnet_id                         = null
  subnet_type                       = var.subnet_type
  termination_protection            = var.termination_protection
  timeouts                          = var.timeouts
  vpc_security_group_ids            = var.vpc_security_group_ids
  vm_count_start_index              = var.vm_count_start_index
  vm_names_override                 = var.vm_names_override
  vm_friendly_names_override        = var.vm_friendly_names_override
  root_block_device = [
    {
      delete_on_termination = true
      encrypted             = true
      volume_type           = var.root_volume_type
      volume_size           = var.root_system_gb
      iops                  = var.root_system_iops
      throughput            = var.root_system_throughput
    }
  ]

  tags  = merge(var.tags, local.tf_versions_map, module.tagger3.tags,{
    "mssql_collation"    = var.mssql_collation
    "mssql_environment"  = var.mssql_environment
    "mssql_version"      = var.mssql_version
    "mssql_instancename" = var.mssql_instancename
    "mssql_installtype"  = var.mssql_installtype
    "mssql_adou"         = var.mssql_adou
    "mssql_datavolumes"  = var.data_volumes
    "backup_s3bucket"    = var.backup_s3bucket
    "backup_s3bucketkms" = var.backup_s3bucketkms
    "BackupDBGroup"      = local.db_backup_group
   ## "BackupGroup"        = local.ec2_backup_group
  })

  volume_tags = {
      "Name"                = "${module.server.hostname_list[0]}-SysVol"
      "VolumeType"          = "OS"
      "PatchGroup"         = var.patch_group
      "Backup"              = "true"
      "Hostname"            = module.server.hostname_list[0]
      "BackupGroup"         = local.ebs_backup_group
    }

}

resource "aws_ebs_volume" "Backup" {
  availability_zone = var.az
  type              = var.dbvol_backup_volume_type
  size              = var.dbvol_backup_gb
  tags              = merge(
    module.tagger2.tags,
    {
      "Name"                = "${module.server.hostname_list[0]}-Backup-/dev/xvdj"
      "VolumeType"          = "Backup"
      "Hostname"            = module.server.hostname_list[0]
      "Backup"              = "false"
      "BackupGroup"         = "ebs-nobackup"
    },
  )
  encrypted         = true
  kms_key_id        = module.server.kms_key_id
  iops              = var.dbvol_backup_iops
  throughput        = var.dbvol_backup_throughput
  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "30m"
  }
}

resource "aws_volume_attachment" "ebs_att_Backup" {
  device_name                     = "/dev/xvdj"
  volume_id                       = aws_ebs_volume.Backup.id
  instance_id                     = module.server.list_id[0]
  stop_instance_before_detaching  = true
}

resource "aws_ebs_volume" "DBSystem" {
  availability_zone = var.az
  type              = var.dbvol_system_volume_type
  size              = var.dbvol_system_gb
  tags              = merge(
    module.tagger2.tags,
    {
      "Name"                = "${module.server.hostname_list[0]}-DBSystem-/dev/xvdf"
      "VolumeType"          = "DBSystem"
      "Hostname"            = module.server.hostname_list[0]
      "Backup"              = "true"
      "BackupGroup"         = local.ebs_backup_group
    },
  )
  encrypted         = true
  kms_key_id        = module.server.kms_key_id
  iops              = var.dbvol_system_iops
  throughput        = var.dbvol_system_throughput
  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "30m"
  }
}

resource "aws_volume_attachment" "ebs_att_DBSystem" {
  device_name                    = "/dev/xvdf"
  volume_id                      = aws_ebs_volume.DBSystem.id
  instance_id                    = module.server.list_id[0]
  stop_instance_before_detaching = true
}

resource "aws_ebs_volume" "DBLog" {
  availability_zone = var.az
  type              = var.dbvol_log_volume_type
  size              = var.dbvol_log_gb
  tags              = merge(
    module.tagger2.tags,
    {
      "Name"                = "${module.server.hostname_list[0]}-DBLog-/dev/xvdh"
      "VolumeType"          = "DBLog"
      "Hostname"            = module.server.hostname_list[0]
      "Backup"              = "false"
      "BackupGroup"         = "ebs-nobackup"
    },
  )
  encrypted         = true
  kms_key_id        = module.server.kms_key_id
  iops              = var.dbvol_log_iops
  throughput        = var.dbvol_log_throughput
  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "30m"
  }
}

resource "aws_volume_attachment" "ebs_att_DBLog" {
  device_name = "/dev/xvdh"
  volume_id   = aws_ebs_volume.DBLog.id
  instance_id = module.server.list_id[0]
  stop_instance_before_detaching = true
}

resource "aws_ebs_volume" "Data" {
  availability_zone = var.az
  type              = var.dbvol_data_volume_type
  size              = coalesce(var.dbvol_data_gb1,var.dbvol_data_gb)
  tags              = merge(
    module.tagger2.tags,
    {
      "Name"                = "${module.server.hostname_list[0]}-Data-/dev/xvdg"
      "VolumeType"          = "Data"
      "Hostname"            = module.server.hostname_list[0]
      "Backup"              = "false"
      "BackupGroup"         = "ebs-nobackup"
    },
  )
  encrypted         = true
  kms_key_id        = module.server.kms_key_id
  iops              = var.dbvol_data_iops
  throughput        = var.dbvol_data_throughput
  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "30m"
  }
}

resource "aws_volume_attachment" "ebs_att_Data" {
  device_name                     = "/dev/xvdg"
  volume_id                       = aws_ebs_volume.Data.id
  instance_id                     = module.server.list_id[0]
  stop_instance_before_detaching  = true
}

resource "aws_ebs_volume" "Data2" {
  count = local.create_4ebs
  availability_zone = var.az
  type              = var.dbvol_data_volume_type
  size              = coalesce(var.dbvol_data_gb2,var.dbvol_data_gb)
  tags              = merge(
    module.tagger2.tags,
    {
      "Name"                = "${module.server.hostname_list[0]}-Data2-/dev/xvdk"
      "VolumeType"          = "Data2"
      "Hostname"            = module.server.hostname_list[0]
      "Backup"              = "false"
      "BackupGroup"         = "ebs-nobackup"
    },
  )
  encrypted         = true
  kms_key_id        = module.server.kms_key_id
  iops              = var.dbvol_data_iops
  throughput        = var.dbvol_data_throughput
  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "30m"
  }
}

resource "aws_volume_attachment" "ebs_att_Data2" {
  count = local.create_4ebs
  device_name                     = "/dev/xvdk"
  volume_id                       = aws_ebs_volume.Data2[count.index].id
  instance_id                     = module.server.list_id[0]
  stop_instance_before_detaching  = true
}

resource "aws_ebs_volume" "Data3" {
  count = local.create_4ebs
  availability_zone = var.az
  type              = var.dbvol_data_volume_type
  size              = coalesce(var.dbvol_data_gb3,var.dbvol_data_gb)
  tags              = merge(
    module.tagger2.tags,
    {
      "Name"                = "${module.server.hostname_list[0]}-Data3-/dev/xvdl"
      "VolumeType"          = "Data3"
      "Hostname"            = module.server.hostname_list[0]
      "Backup"              = "false"
      "BackupGroup"         = "ebs-nobackup"
    },
  )
  encrypted         = true
  kms_key_id        = module.server.kms_key_id
  iops              = var.dbvol_data_iops
  throughput        = var.dbvol_data_throughput
  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "30m"
  }
}

resource "aws_volume_attachment" "ebs_att_Data3" {
  count = local.create_4ebs
  device_name                     = "/dev/xvdl"
  volume_id                       = aws_ebs_volume.Data3[count.index].id
  instance_id                     = module.server.list_id[0]
  stop_instance_before_detaching  = true
}

resource "aws_ebs_volume" "Data4" {
  count = local.create_4ebs
  availability_zone = var.az
  type              = var.dbvol_data_volume_type
  size              = coalesce(var.dbvol_data_gb4,var.dbvol_data_gb)
  tags              = merge(
    module.tagger2.tags,
    {
      "Name"                = "${module.server.hostname_list[0]}-Data4-/dev/xvdm"
      "VolumeType"          = "Data4"
      "Hostname"            = module.server.hostname_list[0]
      "Backup"              = "false"
      "BackupGroup"         = "ebs-nobackup"
    },
  )
  encrypted         = true
  kms_key_id        = module.server.kms_key_id
  iops              = var.dbvol_data_iops
  throughput        = var.dbvol_data_throughput
  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "30m"
  }
}

resource "aws_volume_attachment" "ebs_att_Data4" {
  count = local.create_4ebs
  device_name                     = "/dev/xvdm"
  volume_id                       = aws_ebs_volume.Data4[count.index].id
  instance_id                     = module.server.list_id[0]
  stop_instance_before_detaching  = true
}
  
resource "aws_ebs_volume" "Data5" {
  count = local.create_6ebs
  availability_zone = var.az
  type              = var.dbvol_data_volume_type
  size              = coalesce(var.dbvol_data_gb5,var.dbvol_data_gb)
  tags              = merge(
    module.tagger2.tags,
    {
      "Name"                = "${module.server.hostname_list[0]}-Data5-/dev/xvdq"
      "VolumeType"          = "Data5"
      "Hostname"            = module.server.hostname_list[0]
      "Backup"              = "false"
      "BackupGroup"         = "ebs-nobackup"
    },
  )
  encrypted         = true
  kms_key_id        = module.server.kms_key_id
  iops              = var.dbvol_data_iops
  throughput        = var.dbvol_data_throughput
  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "30m"
  }
}

resource "aws_volume_attachment" "ebs_att_Data5" {
  count = local.create_6ebs
  device_name                     = "/dev/xvdq"
  volume_id                       = aws_ebs_volume.Data5[count.index].id
  instance_id                     = module.server.list_id[0]
  stop_instance_before_detaching  = true
}

resource "aws_ebs_volume" "Data6" {
  count = local.create_6ebs
  availability_zone = var.az
  type              = var.dbvol_data_volume_type
  size              = coalesce(var.dbvol_data_gb6,var.dbvol_data_gb)
  tags              = merge(
    module.tagger2.tags,
    {
      "Name"                = "${module.server.hostname_list[0]}-Data6-/dev/xvdr"
      "VolumeType"          = "Data6"
      "Hostname"            = module.server.hostname_list[0]
      "Backup"              = "false"
      "BackupGroup"         = "ebs-nobackup"
    },
  )
  encrypted         = true
  kms_key_id        = module.server.kms_key_id
  iops              = var.dbvol_data_iops
  throughput        = var.dbvol_data_throughput
  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "30m"
  }
}

resource "aws_volume_attachment" "ebs_att_Data6" {
  count = local.create_6ebs
  device_name                     = "/dev/xvdr"
  volume_id                       = aws_ebs_volume.Data6[count.index].id
  instance_id                     = module.server.list_id[0]
  stop_instance_before_detaching  = true
}

resource "aws_ebs_volume" "DBTemp" {
  availability_zone = var.az
  type              = var.dbvol_tempdb_volume_type
  size              = var.dbvol_tempdb_gb
  tags              = merge(
    module.tagger2.tags,
    {
      "Name"                = "${module.server.hostname_list[0]}-DBTemp-/dev/xvdi"
      "VolumeType"          = "DBTemp"
      "Hostname"            = module.server.hostname_list[0]
      "Backup"              = "false"
      "BackupGroup"         = "ebs-nobackup"
    },
  )
  encrypted         = true
  kms_key_id        = module.server.kms_key_id
  iops              = var.dbvol_tempdb_iops
  throughput        = var.dbvol_tempdb_throughput
  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "30m"
  }
}

resource "aws_volume_attachment" "ebs_att_DBTemp" {
  device_name                     = "/dev/xvdi"
  volume_id                       = aws_ebs_volume.DBTemp.id
  instance_id                     = module.server.list_id[0]
  stop_instance_before_detaching  = true
}

resource "aws_ebs_volume" "DBTemp2" {
  count = local.create_4ebs
  availability_zone = var.az
  type              = var.dbvol_tempdb_volume_type
  size              = var.dbvol_tempdb_gb
  tags              = merge(
    module.tagger2.tags,
    {
      "Name"                = "${module.server.hostname_list[0]}-DBTemp2-/dev/xvdn"
      "VolumeType"          = "DBTemp2"
      "Hostname"            = module.server.hostname_list[0]
      "Backup"              = "false"
      "BackupGroup"         = "ebs-nobackup"
    },
  )
  encrypted         = true
  kms_key_id        = module.server.kms_key_id
  iops              = var.dbvol_tempdb_iops
  throughput        = var.dbvol_tempdb_throughput
  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "30m"
  }
}

resource "aws_volume_attachment" "ebs_att_DBTemp2" {
  count = local.create_4ebs
  device_name                     = "/dev/xvdn"
  volume_id                       = aws_ebs_volume.DBTemp2[count.index].id
  instance_id                     = module.server.list_id[0]
  stop_instance_before_detaching  = true
}

resource "aws_ebs_volume" "DBTemp3" {
  count = local.create_4ebs
  availability_zone = var.az
  type              = var.dbvol_tempdb_volume_type
  size              = var.dbvol_tempdb_gb
  tags              = merge(
    module.tagger2.tags,
    {
      "Name"                = "${module.server.hostname_list[0]}-DBTemp3-/dev/xvdo"
      "VolumeType"          = "DBTemp3"
      "Hostname"            = module.server.hostname_list[0]
      "Backup"              = "false"
      "BackupGroup"         = "ebs-nobackup"
    },
  )
  encrypted         = true
  kms_key_id        = module.server.kms_key_id
  iops              = var.dbvol_tempdb_iops
  throughput        = var.dbvol_tempdb_throughput
  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "30m"
  }
}

resource "aws_volume_attachment" "ebs_att_DBTemp3" {
  count = local.create_4ebs
  device_name                     = "/dev/xvdo"
  volume_id                       = aws_ebs_volume.DBTemp3[count.index].id
  instance_id                     = module.server.list_id[0]
  stop_instance_before_detaching  = true
}

resource "aws_ebs_volume" "DBTemp4" {
  count = local.create_4ebs
  availability_zone = var.az
  type              = var.dbvol_tempdb_volume_type
  size              = var.dbvol_tempdb_gb
  tags              = merge(
    module.tagger2.tags,
    {
      "Name"                = "${module.server.hostname_list[0]}-DBTemp4-/dev/xvdp"
      "VolumeType"          = "DBTemp4"
      "Hostname"            = module.server.hostname_list[0]
      "Backup"              = "false"
      "BackupGroup"         = "ebs-nobackup"
    },
  )
  encrypted         = true
  kms_key_id        = module.server.kms_key_id
  iops              = var.dbvol_tempdb_iops
  throughput        = var.dbvol_tempdb_throughput
  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "30m"
  }
}

resource "aws_volume_attachment" "ebs_att_DBTemp4" {
  count = local.create_4ebs
  device_name                     = "/dev/xvdp"
  volume_id                       = aws_ebs_volume.DBTemp4[count.index].id
  instance_id                     = module.server.list_id[0]
  stop_instance_before_detaching  = true
}