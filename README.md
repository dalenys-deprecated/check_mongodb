# check-mongodb

#### Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Usage](#usage)
4. [NRPE/Nagios configuration](#NRPE/Nagios configuration)

## Overview

This script is just another NRPE script, to check the state of MongoDB.
It's written in Bash, to avoid any dependencies with PyMongo, venv or even Python.
Why ? Because in a perfect world, your production database should be as lightweight as possible, right ? ;)

Feel free to contribute, and add your own checks.

## Requirements

- bash
- awk
- mongodb-org-shell

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
 mem.resident  Check resident memory usage (amount of physical memory being used)
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
 $ ./check_mongo.bash -t standalone -h database1-2 -c mem.resident
 NOK : Resident memory used : 96%, readahead probably too high
 ```

## NRPE/Nagios configuration

Nagios side : /etc/nagios/databases/database1-1/services.cfg

 ```bash
 define service {
  host_name database1-1
  service_description Check status of MongoDB in replicaset
  check_command check_nrpe!check_mongodb_status
  use service-1m-24x7-mail
 }
 ```

Client side : /etc/nagios/nrpe.d/mongo.cfg

 ```bash
 # SERVICE
 command[check_mongodb_status]        = /usr/lib/nagios/plugins/check_mongodb.bash -t replicaset -h localhost -u username -p password -c rs.status
 ```
