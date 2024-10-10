# Goals
Since migration of Sonatype Nexus 3.71.0, lots of things have changed for free version (Java 17 and H2).

In my company, we used Groove clean-up script to purge old Maven releases with internal “org.sonatype.nexus.repository.storage.StorageFacet” and “org.sonatype.nexus.repository.storage.Query”.
If removal of OrientDB, we can not do it anymore. Also, script are deprecated (and disabled by default) and it is not reliable to use internal classes.

Nexus contains a “retain select versions” feature, but for [pro version only](https://help.sonatype.com/en/cleanup-policies.html). So we decided to create a shell script that use public API of Nexus.

# Features
This script has these features:
* clean-up Sonatype Nexus repositories (used for Maven but it will work for other types);
* white list by group or components;
* keep X latest versions of each component.

# Dependencies
Only few things:
* a shell (tested with bash-4.2 and zsh-5.8);
* **jq** (tested with jq-1.6);
* curl (tested with curl-7.29);
* grep (tested with grep-2.20);
* sed (tested with sed-4.2);
* sort (tested with coreutils-8.22, needs at least `--sort-version`);
* **a dedicated user on Nexus** with roles `nx-repository-view-maven2-*-browse` and `nx-repository-view-maven2-*-delete` (“*” can be a single repository depending on your need).

# Usage
Simply download `purge_nexus.sh` and give it execute rights `chmod +x purge_nexus.sh`.

Usage: `./purge_nexus.sh [OPTION]`

Options:
* `-s` is simulation mode (only print delete commands);
* `-v` is verbose mode.