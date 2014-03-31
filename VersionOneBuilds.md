# VersionOne Requirements for Using psake-tools

This document describes requirements for using psake-tools to build VersionOne .NET projects. Note: it may not be applicable to other projects outside of VersionOne, but we're collaborating on the doc here during the iteration.

# Jenkins Job Conifuguration setup

When configuring a Jenkins job, apply these settings:

## Job Notifications
* Check `Restrict where this project can be run`
  * Set `Label Expression` = `powershell4`
    * TODO: this is because Powershell4 is not on all machines. Probably should standardize this component on slaves, not rely on snowflakes like this

## Build Triggers
* Check `Build after other projects are built`
 * Set `Project names` = `openAgile.psake-tasks` (at minimum)
* Check `Build when a change is pushed to GitHub`

## Build Environment
* Check `Delete workspace before build starts`
  
## Build
* Add a new `Execute Windows batch command`
 * Set `Command` = `build.bat jenkins` (This passes the VersionOne-specific `jenkins` parameter to psake-tools and executes several specific targets)
 
# Solution requirements: 
* build.properties.json file with the basic data for that particular project
* A basic build.ps1 file that downloads setup.ps1 from https://raw.github.com/openAgile/Build.PSakeTasks/master/setup.ps1
