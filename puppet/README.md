# Overview

This directory contains various installation scripts.
You can install these:

- PuppetServer
- PuppetDB
- Puppet Agent
- PostgreSQL

## How to install Puppet agent

Default installation
```
./install_puppetagent.sh
```

Install Puppet agent without enable service
```
./install_puppetagent.sh --disable
```

Install Puppet agent and set PuppetServer URL
```
./install_puppetagent.sh --server=puppet-global.cdngp.net
```

Help
```
./install_puppetagent.sh --help
```

## How to install PuppetServer

Default installation
```
./install_puppetserver.sh
```

## How to install PostgreSQL server

Installation example
```
./install_postgresql.sh --version=9.6 --password 'please_change_me' -d 'puppetdb' --user-account 'puppetdb' --user-password 'please_change_me'
```
The above command will install PostgreSQL 9.6 and create a database and an account.

## How to install PuppetDB
Installation example
```
./install_puppetdb.sh --pg-host 172.16.0.24 --pg-database puppetdb --pg-account puppetdb --pg-password please_change_me

```
