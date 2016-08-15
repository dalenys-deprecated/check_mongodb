# check_mongodb ![License][license-img] [![Build Status][build-img]][build-url]

#### Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Usage](#usage)
4. [Nagios configuration](#Nagios configuration)
5. [Development](#development)

## Overview

This script is a  nagios plugin, to check the state of  MongoDB. It's written in
Bash, to avoid any dependencies with PyMongo, venv and even Python.

Why  ?  Because in  a  perfect  world, your  production  database  should be  as
lightweight as possible, right ? ;)

The design of the script is quite easy, in order to allow you to contribute with
your own needs. Basically, one check is one function, keep it simple.

Nagios : https://www.nagios.org/
MongoDB : https://www.mongodb.com/

## Requirements

- bash
- awk
- mongodb-org-shell

### Debian and Ubuntu

You need MongoDB repository : https://docs.mongodb.com/manual/tutorial/install-mongodb-on-ubuntu/

```bash
$ sudo apt-get install mongodb-org-shell
```

### RedHat and Fedora

You need MongoDB repository : https://docs.mongodb.com/manual/tutorial/install-mongodb-on-red-hat/

```bash
$ sudo yum install -y mongodb-org-shell
```

## Usage

```bash
Usage: check_mongo.bash -t [standalone|replicaset] -h [hostname] -c [check_name]
Optional :
-u [username]
-p [password]
-w [port]
-v verbose

Any rs.xxx command has to be associated with -t replicaset

check_name :
mem.resident  Check resident memory usage (amount of physical memory being used, only for MMAPv1 storage engine)
rs.status     Status of the local node
rs.count      Count how many member are in the replicaset
rs.lag        Check replication lag
```

```bash
$ /usr/lib/nagios/plugins/check_mongodb.bash -t replicaset -h database1-1.domain -u username -p password -c rs.status
$ OK - State is PRIMARY
```

```bash
$ /usr/lib/nagios/plugins/check_mongodb.bash -t replicaset -h database1-1.domain -u username -p password -c rs.lag
$ OK : Lag replication is 0 hr(s)
```

```bash
$ /usr/lib/nagios/plugins/check_mongo.bash -t standalone -h database1-2 -c mem.resident
NOK : Resident memory used : 96%, readahead probably too high
```

## Nagios configuration

Nagios side : /etc/nagios/databases/database1/mongodb.cfg

```
define service {
  host_name database1
  service_description Check status of MongoDB in replicaset
  check_command check_nrpe!check_mongodb_status
  use service-1m-24x7-mail
}
```

Client side : /etc/nagios/nrpe.d/mongodb.cfg

```
command[check_mongodb_status] = /usr/lib/nagios/plugins/check_mongodb.bash -t replicaset -h localhost -u username -p password -c rs.status
```

## Development

Feel free to contribute on GitHub.

```
    ╚⊙ ⊙╝
  ╚═(███)═╝
 ╚═(███)═╝
╚═(███)═╝
 ╚═(███)═╝
  ╚═(███)═╝
   ╚═(███)═╝
```

[license-img]: https://img.shields.io/badge/license-ISC-blue.svg
[build-img]: https://travis-ci.org/dalenys/check_mongodb.svg?branch=master
[build-url]: https://travis-ci.org/dalenys/check_mongodb
