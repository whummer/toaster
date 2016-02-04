# Introduction

citac is a tool for automatically testing Puppet manifests for *idempotence* and *convergence*, hence that repeated executions do not change the desired state once reached:

- **Idempotence:** Resources do not fail and do not alter the system state on re-execution.
- **Convergence:** Resources do not conflict with each other but describe a common desired state. Even in case of temporary failures and partial executions, the system eventually reaches the desired state.

> Please not that citac is a research prototype which is still in its early stages.

# Installation

citac can be installed by running the following command. Please not that we currently support only Ubuntu 14.04.

```sh
$ curl -sSL https://raw.githubusercontent.com/citac/citac/master/install/install.sh | sudo bash
```

The script performs the following changes to your system:

1. Install Docker
2. Deploy a custom AppArmor profile for Docker
3. Install the citac main executable to `/usr/bin/citac`
4. Download Docker images for running citac tests

# Usage

In order to test a given Puppet manifest (site.pp) for idempotence and convergence, you need to:

1. prepare a citac test (directory containing the Puppet manifest as well as all required Puppet modules)
2. execute the citac test
3. inspect the test results

## Step 1 - Test Preparation

Create an empty directory in which your Puppet manifest, all required Puppet modules as well as the test results will reside. The directory name needs to end with `.spec`.

```sh
$ mkdir demo.spec
```

Initialize the directory structure.

```sh
$ cd demo.spec
$ citac init
```

Supply your Puppet manifest in `scripts/default`.

```sh
$ echo "exec {'/bin/echo on >> /etc/setting': }" > scripts/default
$ echo "exec {'/bin/date >> /tmp/runs.txt': }" >> scripts/default
$ cat scripts/default
exec {'/bin/echo on >> /etc/setting': }
exec {'/bin/date >> /tmp/runs.txt': }
```

Add all required Puppet modules. If you do not specify a version, the latest one will be used.

```sh
$ citac add puppetlabs/stdlib 3.2.1
```

Choose an operating system on which to run the tests (Docker containers are used for running the tests).
Run `citac os` to get a list of supported operating systems. Currently, we support Debian 7, Ubuntu 14.04 and CentOS 7.

```sh
$ citac os debian-7
```

## Step 2 - Run Tests

In order to run tests, simple run the following command in the test directory. The test process can be aborted
at any time. In order to resume the tests, simply run the command again.

```sh
$ citac test
```

The test process tracks changes to the Docker container in order decide whether a resource is idempotent or not or
in conflict with another one. It may happen that some detected change should not be taken into account, i.e.,
modifications to the temp directory may be allowed. In such a case you can supply regular expression patterns for
excluded paths in the file `files/excluded_files.yml`:

```sh
$ cat files/excluded_files.yml
---
- ^/tmp/runs\.txt$
```

Apart from files, citac tracks also changes to network interfaces, route configuration, server sockets,
mounted file systems and running processes. For instance, one may exclude routes on the network interface lo by
patterns saved to `files/excluded_states.yml`. Please note that in contrast to the file exclusion list, you need to
specify two patterns per ignored aspect (first is the state key, second the state value).

```sh
$ cat files/excluded_states.yml
---
- - routes
  - iface=>"lo"
```

You can clear the test results by running `citac reset`.

## Step 3 - Inspect Results

Test results as well as the test progress can be shown by running the following command.

```sh
$ citac results
2 out of 2 test cases executed.

Status: Problems detected
(run "citac results -d" to include error details)

Problems:
 - Exec[/bin/echo on >> /etc/setting] is not idempotent
```

Our sample script above is obviously not idempotent because on each run "on" is appended to the file `/etc/setting`.
citac will therefore report that the resource is not idempotent with an output similar to the following:

```sh
$ citac results -d
2 out of 2 test cases executed.

Status: Problems detected

Problems:
 - Exec[/bin/echo on >> /etc/setting] is not idempotent
   Notice: /Stage[main]/Main/Exec[/bin/echo on >> /etc/setting]/returns: executed successfully
   1 changes:
     file/changed: /etc/setting
```

# Further Resources

Currently there is no further documentation available. If you have any questions, feel free to contact us.