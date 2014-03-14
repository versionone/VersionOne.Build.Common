param(
    [alias("env")]
    $environment = ''
)

function GetModulePath([string]$module){
	$commonPath = @(Get-ChildItem -r -Path packages -filter $module | Sort-Object FullName  -descending)
	return $commonPath[0].FullName
}

function DownloadNuget(){
	new-item (Get-Location).Path -name .nuget -type directory -force
	$destination = (Get-Location).Path + '\.nuget\nuget.exe'	
	Invoke-WebRequest -Uri "http://nuget.org/nuget.exe" -OutFile $destination
}

function DownloadAndImportModules(){
	.nuget\nuget.exe install psake -OutputDirectory packages -NoCache
	.nuget\nuget.exe install VersionOne.Build.Common -Source http://www.myget.org/F/versionone/api/v2/ -OutputDirectory  packages -NoCache
}

function CopyCommonToRoot(){
	$commonPath = GetModulePath "VersionOne.Build.Common.ps1"
	Copy-Item -Path $commonPath -Destination (Get-Location).Path -Force
}

function ImportPsake(){
	$psakePath = GetModulePath "psake.psm1"
	Import-Module $psakePath
}

function RunBuildExtensions() {
	ls build-ex.*.ps1 | sort | foreach-object -process {
		if ($psake.build_success -eq $false) { 
			throw "Build extension failed."			
		}
		if ($_ -like "*.script.*") { & $_ } 
	}
	# TODO add Invoke-psake for *.task.* match
}

try{
	DownloadNuget
	DownloadAndImportModules
	ImportPsake
	CopyCommonToRoot
	Invoke-psake VersionOne.Build.Common.ps1 $environment
	# Run extensions that are specific to this build
	RunBuildExtensions
}
Catch {
	throw "Build failed."
}
Finally {
	if ($psake.build_success -eq $false) {
		throw "Build failed."    	
	}
}