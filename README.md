# Vault Provider PSQL Example

An example repo to create a dynamic postgresql user with Vault

By default, a created user in Postgres can access all databases without grants, you have to explcitly revoke this ability:

* https://aws.amazon.com/blogs/database/managing-postgresql-users-and-roles/
* https://dba.stackexchange.com/questions/17790/created-user-can-access-all-databases-in-postgresql-without-any-grants
* https://blog.dbrhino.com/locking-down-permissions-in-postgresql-and-redshift.html

## Pre-reqs 

Have the following installed:

- docker-compose
- terraform
- vault

## Usage

### Warning

This is for testing only, there are hardcoded passwords and tokens everywhere.

### Set Environment Variables

```bash
export VAULT_TOKEN="TEST"
export VAULT_ADDR="http://0.0.0.0:8200"
```

### Starting up docker-compose

```bash
docker-compose up
```

### Terraform

Run: 

```bash 
terraform init
terraform apply
```

### Check dynamic role statement creation

```
vault read database/creds/testdb-dynamic
Key                Value
---                -----
lease_id           database/creds/testdb-dynamic/SAcpI3VO0qBAw3m8XDygmts4
lease_duration     720h
lease_renewable    true
password           A1a-c0MR87kSwRlcOYl3
username           v-token-testdb-d-5HjCGGI6dhybuzoziJOT-1600171406
```

Then use to login to posgresql:

```
psql -h localhost -U "v-token-testdb-d-5HjCGGI6dhybuzoziJOT-1600171406" -W -d vaultdb2
```

Create a table:

```
psql (12.4, server 9.6.12)
Type "help" for help.

vaultdb2=> create table test99a(id serial not null primary key);
```

See it has the right permissions:

```
vaultdb2=> \z
                                                                                 Access privileges
 Schema |      Name      |   Type   |                                               Access privileges                                               | Column privileges | Policies
--------+----------------+----------+---------------------------------------------------------------------------------------------------------------+-------------------+----------
 public | test99a        | table    | vaultdb2_users=arwdDxt/"v-token-testdb-d-5HjCGGI6dhybuzoziJOT-1600171406"                                    +|                   |
        |                |          | "v-token-testdb-d-5HjCGGI6dhybuzoziJOT-1600171406"=arwdDxt/"v-token-testdb-d-5HjCGGI6dhybuzoziJOT-1600171406" |                   |
 public | test99a_id_seq | sequence | vaultdb2_users=rwU/"v-token-testdb-d-5HjCGGI6dhybuzoziJOT-1600171406"                                        +|                   |
        |                |          | "v-token-testdb-d-5HjCGGI6dhybuzoziJOT-1600171406"=rwU/"v-token-testdb-d-5HjCGGI6dhybuzoziJOT-1600171406"     |                   |
(2 rows)
```