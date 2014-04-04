# Designing psake-tools

## User Stories

As the product manager, I want to deploy working .NET code every 2 weeks. When the build is hard to use, breaks easily, or takes a lot of time to change, then I get less working code in 2 weeks, and sometimes none at all.

As a developer building .NET projects and libraries on the Windows platform, I want my projects to build both in my CI tool and on local developer workstations.

## Practices

* Small Components - Even small products are built from multiple components. Each component manifests good design principles such as low coupling, high cohesion, single responsibility principle, and Don't Repeat Yourself. In .NET that means breaking each component out as a separate solution found in a different GitHub repository.
* Package Management - Managing component dependencies is hard. While the short-term problem can be solved by simply putting libraries in the GitHub repo, this leaves the long-term integration issues unsolved. In .NET, NuGet is the prevailing solution for managing library dependencies. We manage dependencies on 3rd parties via NuGet. We produce libraries that other people can consume via NuGet. We sometimes use "unofficial NuGet feeds" such as MyGet and Artifactory.
* Build as Code - Most of our products have survived major team changes where nobody remembers the inception, let alone manual steps to build the code. The code has changed repositories and CI tools. Therefore, our build scripts are more than just convenient automation, they encode knowledge for future generations of developers. In .NET, that means knowing when to use MS Build and when to avoid it. It also means being careful not to embed all the build knowledge into a CI tool like Jenkins or TeamCity.
* Build Conventions - With many small GitHub repos comes the potential cost of context switching. Conventions across projects helps keep the cost low. In .NET, that means we have a standard lifecycle.

## Build Problems

* MS Build XML is hard to read and harder to debug.
* .NET developers not familiar with bash.
* Too much bash code compensating for Windows conventions, such as navigating directories or passing parameters.
* Too much time spent debugging differences between local and build enviroments.
* Hard to share common build tasks between projects, such as versioning the AssemblyInfo.cs file.
* Hard to automate new build tasks, such as Azure deployment.
* Need to jump between many .NET projects each with a different notion of the build lifecycle, unlike Java projects where maven provides standard targets with "clean", "compile", "test", and "deploy" (but we also don't want to be so rigid as maven that new phases can't easily emerge when we need them).

## Examples of Common .NET Build Tasks

* Version DLLs by generating AssemblyInfo.cs
* Restore dependencies via NuGet restore
* Update dependencies via NuGet update
* Compile via MSBuild
* Test via NUnit
* Integration testing with approval tests
* BDD with TickSpec
* Measure code coverage
* Package for NuGet
* Deploy to MyGet or NuGet
* Deploy to Azure
* Deploy app catalog entry

## Lifecycle Convention

(Proposed)

* Clean (manual) - Delete build artifacts
* Initialization - Load build tasks
  * Load psake tasks
* Configuration - Prepare workspace items
  * Version DLLs by generating AssemblyInfo.cs
  * Restore dependencies via NuGet restore
  * Update dependencies via NuGet update
* Compile - Compile source
  * Compile via MSBuild
* Test - Unit tests that can run without external dependencies
  * Test via NUnit
  * Measure code coverage
* Integration-Test - Tests that require external dependencies, like an instance of VersionOne
  * Integration testing with approval tests
  * BDD with TickSpec
  * Measure code coverage
* Package - Put the build artifacts into an appropriate distributable
  * Package for NuGet
* Deploy - Put stuff where it goes for manual testing and early access
  * Deploy to MyGet
  * Deploy to Azure
  * Deploy app catalog entry
* Promote - Put stuff where it goes for customers
  * Promote from NuGet to MyGet
  * Promote from Azure Stating to Azure Production
  * Promote from stating app catalog to production app catalog



## Scenarios

* When I create a Configuration for My Build I can:
  * Rely on the default Project Naming Convention if I've named my projects in accordance with it
    * Or, provide a Project Naming Convention Search Pattern to override the default
    * Or, specify a list of root-relative project file paths
  * Rely on the default Test Discovery Convention if I've named by test projects in accordance with it
    * Or, provide a Test Project Naming Convention Search Pattern to override the default
  * Specify which TestRunner to use and the build will find and run tests with it
  * Add additional "extended tasks" like PackageForAzure, PublishToAzure, or whatever else is specific to my build
  
