# Story storm for making this project a reusable library for other developers outside of VersionOne

## Major Goal

As a DevOps Dude building .NET projects and libraries on the Windows platform, I want my projects to build both in my CI tool and on local developer workstations.

## Supporting Goals

* In my solution, I have one or more library projects that I want to package up as NuGet packages and deploy either to the public NuGet server or to my own NuGet server, like MyGet.
* I don't want my build setup to be confined to Jenkins-specific or TeamCity-specific, or any other tool-specific plugins
* When a build starts, it runs through the standard flow like Build, Test, Package, Deploy, Publish Test Results

## Scenarios

* When I create a Configuration for My Build I can:
  * Rely on the default Project Naming Convention if I've named by projects in accordance with it
    * Or, provide a Project Naming Convention Search Pattern to override the default
    * Or, specify a list of root-relative project file paths
  * Rely on the default Test Discovery Convention if I've named by test projects in accordance with it
    * Or, provide a Test Project Naming Convention Search Pattern to override the default
  * Specify which TestRunner to use and the build will find and run tests with it
  * Add additional "extended tasks" like PackageForAzure, PublishToAzure, or whatever else is specific to my build
  
