
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
	$testRunner = Get-NewestFilePath "nunit-console-x86.exe"	
	
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

#helpers

function Get-ConfigObjectFromFile($file){
	Get-Content $file -Raw | ConvertFrom-Json	
}

function Get-EnvironmentVariableOrDefault([string] $variable, [string]$default){		
	if([Environment]::GetEnvironmentVariable($variable))
	{
		[Environment]::GetEnvironmentVariable($variable)
	}
	else
	{
		$default
	}
}

function Get-NewestFilePath([string]$file){
	$paths = @(Get-ChildItem -r -Path packages -filter $file | Sort-Object FullName  -descending)
	$paths[0].FullName
}

function New-NugetDirectory(){
	new-item (Get-Location).Path -name .nuget -type directory -force
}

function Get-NugetBinary (){		
	$destination = (Get-Location).Path + '\.nuget\nuget.exe'	
	Invoke-WebRequest -Uri "http://nuget.org/nuget.exe" -OutFile $destination
}

function Get-BuildCommand(){
	"msbuild $($config.solution) -t:Build -p:Configuration=$($config.configuration) `"-p:Platform=$($config.platform)`""
}

function Get-CleanCommand(){
	"msbuild $($config.solution) -t:Clean -p:Configuration=$($config.configuration) `"-p:Platform=$($config.platform)`""
}

function Get-PublishCommand(){
	"msbuild $($config.projectToPublish) -t:Publish -p:Configuration=$($config.configuration)"
}

function Get-RestorePackagesCommand(){
	".\\.nuget\nuget.exe restore  $($config.solution) -Source $($config.nugetSources)"
}

function Get-UpdatePackagesCommand(){
	".\\.nuget\nuget.exe update  $($config.solution) -Source $($config.nugetSources)"
}

function Get-GeneratePackageCommand (){
	".\\.nuget\nuget.exe pack $($config.projectToPackage) -Verbosity Detailed -Version $version -prop Configuration=$($config.configuration)"
}

function Get-PushPackagesCommand() {	
	".\\.nuget\nuget.exe push *.nupkg $env:MYGET_API_KEY -Source $env:MYGET_REPO_URL"
}

function Get-InstallNRunnersCommand(){
	".\\.nuget\nuget.exe install NUnit.Runners -OutputDirectory packages"
}

function Update-AssemblyInfo(){
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

function Get-Version(){	
	$year = (get-date).ToUniversalTime().ToString("yy")	
	$hourMinute = (get-date).ToUniversalTime().ToString("HHmm")	
	$buildNumber = Get-EnvironmentVariableOrDefault "BUILD_NUMBER" $hourMinute
	
	$dayOfyear = (get-date).DayOfYear
	if(([string]$dayOfyear).Length -eq 1){
		$dayOfyear=  "00" + $dayOfyear
	}
	elseif(([string]$dayOfyear).Length -eq 2){
		$dayOfyear = "0" + $dayOfyear
	}
	
	"$($config.major).$($config.minor).$year$dayOfyear.$buildNumber"
}