database_name           = "wordpress_db"   # DB name
database_user           = "admin"          # DB Username
shared_credentials_file = "~/.aws"         # Access key and Secret key File Location #AWS Configure
region                  = "af-south-1"     # Cape Town Region

## Avaibility Zone & CIDR ##
AZ1          = "af-south-1a" # EC2
AZ2          = "af-south-1b" # RDS 
AZ3          = "af-south-1c" # RDS
VPC_cidr     = "10.0.0.0/16"     # VPC CIDR
subnet1_cidr = "10.0.1.0/24"     # Public Subnet for EC2
subnet2_cidr = "10.0.2.0/24"     # Private Subnet for RDS
subnet3_cidr = "10.0.3.0/24"     # Private Subnet for RDS


PUBLIC_KEY_PATH  = "./mykey-pair.pub" // Key Name for EC2
PRIV_KEY_PATH    = "./mykey-pair"
instance_type    = "t3.micro"    # Type of Instance
instance_class   = "db.t3.micro" # Type of RDS Instance
root_volume_size = 22            # Volume Size
