properties {	
	$config = Get-ConfigObject
	$version = $config.version + '.' + (Get-EnvironmentVariableOrDefault "BUILD_NUMBER" $config.buildNumber)
}

#groups of tasks
task default -depends RestoreAndUpdatePackages,Build,runUnitTests
task jenkins -depends default,PushMyget

#tasks
task validateInput {
	#TODO: validate build.properties.json
}

task build -depends clean,generateAssemblyInfo {
	$solution = $config.solution
	$configuration = $config.configuration
	$platform = $config.platform
	exec { msbuild $solution -t:Build -p:Configuration=$configuration "-p:Platform=$platform" }	
}
 
task clean {
	$solution = $config.solution
	$configuration = $config.configuration
	$platform = $config.platform
	exec { msbuild $solution -t:Clean -p:Configuration=$configuration "-p:Platform=$platform" }	
}

task publish{
	$project = $config.projectToPublish
	$configuration = $config.configuration
	exec { msbuild $project -t:Publish -p:Configuration=$configuration }	
}

task restoreAndUpdatePackages {
	exec { .\\.nuget\nuget.exe restore  $config.solution -Source $config.nugetSources }	
	exec { .\\.nuget\nuget.exe update  $config.solution -Source $config.nugetSources }	
}
 
task generateAssemblyInfo{	
	Write-AssemblyInfo
}

task setUpNuget {
	New-NugetDirectory
	Get-NugetBinary
}

task generateNugetPackage{	
	$project = $config.projectToPackage
	$configuration = $config.configuration
	exec { .\\.nuget\nuget.exe pack $project -Verbosity Detailed -Version $version -prop Configuration=$configuration }
}

task pushMyget -depends GenerateNugetPackage{
	if ($env:MYGET_BYPASS -ne "true") {
		exec { .\\.nuget\nuget.exe push *.nupkg $env:MYGET_API_KEY -Source $env:MYGET_REPO_URL }
	}
}

task installNunitRunners{
	exec { .\\.nuget\nuget.exe install NUnit.Runners -OutputDirectory packages }
}

task runUnitTests{
	$testRunner = Get-NewestFilePath "nunit-console-x86.exe"
	$configuration = $config.configuration
	
	(ls -r *.Tests.dll) | where { $_.FullName -like "*\bin\Release\*.Tests.dll" } | foreach {
		$fullName = $_.FullName
		exec { iex "$testRunner $fullName" }
	}	
}

#helpers

function Get-ConfigObject(){
	return Get-Content .\build.properties.json -Raw | ConvertFrom-Json	
}

function Get-EnvironmentVariableOrDefault([string] $variable, [string]$default){		
	if([Environment]::GetEnvironmentVariable($variable))
	{
		return [Environment]::GetEnvironmentVariable($variable)
	}
	else
	{
		return $default
	}
}

function Get-NewestFilePath([string]$file){
	$paths = @(Get-ChildItem -r -Path packages -filter $file | Sort-Object FullName  -descending)
	return $paths[0].FullName
}

function New-NugetDirectory(){
	new-item (Get-Location).Path -name .nuget -type directory -force
}

function Get-NugetBinary (){		
	$destination = (Get-Location).Path + '\.nuget\nuget.exe'	
	Invoke-WebRequest -Uri "http://nuget.org/nuget.exe" -OutFile $destination
}


function Write-AssemblyInfo(){
	
	$version = $config.major + "." + $config.minor + "." + (get-date -format "yyMM.HHmm")
	$versionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
	$versionAssembly = 'AssemblyVersion("' + $version + '")';
	$versionFilePattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
	$versionAssemblyFile = 'AssemblyFileVersion("' + $version + '")';
	
	Get-ChildItem -r -filter AssemblyInfo.cs | 
	Update-Assemblies	
	
	Get-ChildItem -r -filter AssemblyInfo.fs |
	Update-Assemblies
}

function Update-Assemblies() {
	param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [object[]]
        $files
	)	
	process
	{
		$files.Length
		foreach ($file in $files)
		{
			Write-Host Updating file $file.FullName
			$tmp = ($file.FullName + ".tmp")
			if (test-path ($tmp)) { remove-item $tmp }
			
			(get-content $file.FullName) | 
			% {$_ -replace $versionFilePattern, $versionAssemblyFile } | 
			% {$_ -replace $versionPattern, $versionAssembly } > $tmp
			
			if (test-path ($file.FullName)) { remove-item $file.FullName }
			move-item $tmp $file.FullName -force			
		}
	}    
}