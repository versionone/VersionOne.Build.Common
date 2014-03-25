.".\psake-tools-helpers.ps1"

properties {
	$config = (Get-ConfigObjectFromFile '.\build.properties.json')
	$version = Get-Version ((get-date).ToUniversalTime()) (Get-EnvironmentVariableOrDefault "BUILD_NUMBER" $null)
	$baseDirectory = (Get-Location).Path
}

#groups of tasks
task default -depends local
task local -depends restorePackages,updatePackages,build,runTests,runExtensions
task jenkins -depends restorePackages,updatePackages,build,runTests,pushMyGet,runExtensions

#tasks
task validateInput {
	#TODO: validate build.properties.json
}

task setAssemblyInfo{	
	Update-AssemblyInfo $baseDirectory
}

task build -depends clean,setAssemblyInfo {	
	exec { iex (Get-BuildCommand) }	
}
 
task clean {	
	exec { iex (Get-CleanCommand) }	
}

task publish{	
	exec { iex (Get-PublishCommand) }	
}

task restorePackages {
	exec { iex (Get-RestorePackagesCommand) }	
}

task updatePackages {
	exec { iex (Get-UpdatePackagesCommand) }	
}

task generatePackage{
	#TODO: make this able to generate multiple packages
	exec { iex (Get-GeneratePackageCommand) }
}

task pushMyGet -depends generatePackage{
	#TODO: should we check for the variables existence before?
	exec { iex (Get-PushMygetCommand $env:MYGET_API_KEY $env:MYGET_REPO_URL) }	
}

task installNunitRunners{
	exec { iex (Get-InstallNRunnersCommand) }	
}

task runTests -depends installNunitRunners{
	$testRunner = Get-NewestFilePath "packages" "nunit-console-x86.exe"	
	
	(ls -r *.Tests.dll) | 
	where { $_.FullName -like "*\bin\Release\*.Tests.dll" } | 
	foreach {
		$fullName = $_.FullName
		exec { iex "$testRunner $fullName" }
	}
}

task setUpNuget {
	New-NugetDirectory
	Get-NugetBinary
}

task runExtensions{
	ls build-ex.*.ps1 |
	sort |
	foreach{		
		if ($_ -like "*.script.*") { 
			Write-Host "The next extension has been loaded: $_ "  -ForegroundColor green
			& $_
		}
	}
}