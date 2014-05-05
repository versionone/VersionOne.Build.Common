.".\psake-tools-helpers.ps1"

properties {
	$config = (Get-ConfigObjectFromFile '.\build.properties.json')
	$version = Get-Version ((get-date).ToUniversalTime()) (Get-EnvironmentVariableOrDefault "BUILD_NUMBER" $null)
	$baseDirectory = (pwd).Path
}

#groups of tasks
task default -depends local
task local -depends runPreExtensions,restorePackages,updatePackages,build,runNunitTests,runPostExtensions
task jenkins -depends runPreExtensions,restorePackages,updatePackages,build,runNunitTests,pushMyGet,runPostExtensions

#tasks
task validateInput {
	#TODO: validate build.properties.json for every task that uses it. If it fails show a file example
}

task setAssemblyInfo{
	Get-Assemblies $baseDirectory | Update-Assemblies	
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

task runNunitTests -depends installNunitRunners{
	exec{ Invoke-NunitTests $baseDirectory }
}

task setUpNuget {
	New-NugetDirectory $baseDirectory
	Get-NugetBinary $baseDirectory
}

task runPreExtensions{
	Get-PreExtensions $baseDirectory | Invoke-Extensions
}

task runPostExtensions{
	Get-PostExtensions $baseDirectory | Invoke-Extensions
}