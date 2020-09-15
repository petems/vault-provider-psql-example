// Ensure VAULT_ADDR and VAULT_TOKEN env vars are set
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "2.13.0"
    }
    postgresql = {
      source  = "hashicorp/postgresql"
      version = "1.7.1"
    }
  }
  required_version = "0.12.24"
}

provider "postgresql" {
  host            = "localhost"
  port            = 5432
  database        = "postgres"
  username        = "postgres"
  password        = "password"
  sslmode         = "disable"
  connect_timeout = 15
}

resource "postgresql_database" "vaultdb2" {
  name              = "vaultdb2"
  owner             = "postgres"
  connection_limit  = -1
  allow_connections = true
}

resource "postgresql_role" "vaultdb2_users" {
  name     = "vaultdb2_users"
  login    = false
}

## TODO - Figure out how to turn this into terraform resources
resource "null_resource" "db_revoke_all" {
  provisioner "local-exec" {

    command = <<END
psql --command="
REVOKE ALL ON DATABASE vaultdb2 FROM public;
GRANT CONNECT ON DATABASE vaultdb2 TO vaultdb2_users;
"
END

    environment = {
      PGHOST = "localhost"
      PGPORT = "5432"
      PGUSER = "postgres"
      PGPASSWORD = "password"
      PGDATABASE = "postgres"
    }
  }

  depends_on = [
    "postgresql_database.vaultdb2",
  ]
}

## TODO - Figure out how to turn this into terraform resources
resource "null_resource" "db_setup_defaults" {
  provisioner "local-exec" {

    command = <<END
psql --command="
CREATE SCHEMA vaultdb2_schema;
ALTER ROLE vaultdb2_users IN DATABASE vaultdb2 SET SEARCH_PATH=vaultdb2_schema;
GRANT ALL PRIVILEGES ON SCHEMA vaultdb2_schema TO vaultdb2_users;
GRANT ALL PRIVILEGES ON DATABASE vaultdb2 TO vaultdb2_users;
GRANT TEMP ON DATABASE vaultdb2 TO vaultdb2_users;
"
END

    environment = {
      PGHOST = "localhost"
      PGPORT = "5432"
      PGUSER = "postgres"
      PGPASSWORD = "password"
      PGDATABASE = "vaultdb2"
    }
  }

  depends_on = [
    "null_resource.db_revoke_all",
  ]
}


resource "vault_mount" "database" {
  path                      = "database"
  type                      = "database"
  default_lease_ttl_seconds = "2592000" # 30 days
  max_lease_ttl_seconds     = "2592000" # 30 days
}

resource "vault_database_secret_backend_connection" "testdb" {
  backend = "database"
  name    = "testdb"
  allowed_roles = [ "testdb-dynamic"]

  verify_connection = false

  data = {
    "username" = "postgres"
    "password" = "password"
  }
  
  postgresql {
    max_open_connections = 3
    max_idle_connections = 3
    max_connection_lifetime = 0
    connection_url = "postgresql://{{username}}:{{password}}@database:5432/vaultdb2?sslmode=disable"
  }

  depends_on = [
    "null_resource.db_setup_defaults",
  ]
}

resource "vault_database_secret_backend_role" "testdb_testdb-dynamic" {
  name    = "testdb-dynamic"
  backend = "database"
  db_name = vault_database_secret_backend_connection.testdb.name
  creation_statements = [
    "CREATE USER \"{{name}}\" WITH ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT vaultdb2_users TO \"{{name}}\";",
    "ALTER ROLE \"{{name}}\" IN DATABASE vaultdb2 SET search_path = vaultdb2_schema;",
    "ALTER DEFAULT PRIVILEGES FOR ROLE \"{{name}}\" GRANT ALL ON TABLES to vaultdb2_users;",
    "ALTER DEFAULT PRIVILEGES FOR ROLE \"{{name}}\" GRANT ALL ON SEQUENCES to vaultdb2_users;",
    "ALTER DEFAULT PRIVILEGES FOR ROLE \"{{name}}\" GRANT ALL ON FUNCTIONS to vaultdb2_users;"
  ]
}