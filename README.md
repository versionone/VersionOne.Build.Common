psake-tools
=======================

Reusable tasks for psake-based built scripts (maybe add to https://github.com/psake/psake-contrib?)
##Requirements
Powershell 4

##Getting Started
Want to start right away? Create the next two files at the directory you have the solution.sln:
###build.properties.json:
```json
{
    "solution": "yourSolution.sln",    
    "nugetSources": "http://packages.nuget.org/api/v2/;http://www.myget.org/F/versionone/api/v2/",
    "configuration": "Release",
    "platform": "Any CPU",    
    "major": "1",
    "minor": "3"
}
```

###build.ps1:
```
param(
    [alias("t")]
    [string]$tasks = ''
)

function DownloadSetup {
    $source = "https://raw.github.com/openAgile/Build.PSakeTasks/master/setup.ps1"  
    Invoke-WebRequest -Uri $source -OutFile setup.ps1
}

try {
    DownloadSetup
    .\setup.ps1 $tasks
}
Catch {
    Write-Host $_.Exception.Message
    exit 1
}
```

By running build.ps1 you are all set for a basic local build.

##Tasks parameters
If you only want to run some of the tasks, you can specify them by passing their names as parameters in the next way:
``.\build.ps1 "restorePackages,updatePackages,build"``
keep in mind that some tasks have dependencies. For example; if you call build it will also call clean and setAssemblyInfo.

##Predefined tasks
There are two major sets of tasks that you can use as parameter, local and jenkins. Local includes the basic tasks that you probably want in a local build. Jenkins is for CI, it includes tasks that will generate nuget packages and publish them into myget.

###The complete list of tasks:

build, clean, setAssemblyInfo, publish, restorePackages, updatePackages, generatePackage, pushMyGet, installNunitRunners, runNunitTests, setUpNuget, runPreExtensions, runPostExtensions, publishDocumentation, publishToAppCatalog, zipFiles.


##Extensions
Predefined tasks aren't enough for you? Don't worry, just create your script file with the next name format:

pre.**OrderNumber**.**NameOfYourScript**.ps1
or
post.**OrderNumber**.**NameOfYourScript**.ps1

Example: `post.001.DeployToAWS.ps1`

The pre scripts are run at the very beginning, before any other task. Post scripts will be run at the end as an extra task. If you have more than one, use the OrderNumber to decide the order in which they are executed.
