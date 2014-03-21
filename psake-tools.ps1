.".\psake-tools-helpers.ps1"

properties {
	$config = (Get-ConfigObjectFromFile '.\build.properties.json')
	$version = Get-Version
}

#groups of tasks
task default -depends local
task local -depends restorePackages,updatePackages,build,runTests,runExtensions
task jenkins -depends restorePackages,updatePackages,build,runTests,pushPackages,runExtensions

#tasks
task validateInput {
	#TODO: validate build.properties.json
}

task setAssemblyInfo{	
	Update-AssemblyInfo
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

task pushPackages -depends generatePackage{	
	exec { iex (Get-PushPackagesCommand) }	
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