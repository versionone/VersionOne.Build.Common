param(
    [alias("t")]
    [string] $tasks = ''
)

function GetModulePath([string]$module){
	$commonPath = @(Get-ChildItem -r -Path packages -filter $module | Sort-Object FullName  -descending)
	return $commonPath[0].FullName
}

function DownloadNuget(){
	new-item (Get-Location).Path -name .nuget -type directory -force
	$destination = (Get-Location).Path + '\.nuget\nuget.exe'	
	Write-Host "Destination for nuget=" $destination
#This will insure the latest nuget.exe.  Having a fixed version caused issue when tls changed
	$latestNuget = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	
	Invoke-WebRequest -Uri $latestNuget -OutFile $destination
}

function DownloadAndImportModules(){
	$AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
	[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
	.nuget\nuget.exe install psake -OutputDirectory packages -NoCache
	.nuget\nuget.exe install psake-tools -Source http://www.myget.org/F/versionone/api/v2/ -OutputDirectory  packages -NoCache
}

function CopyPsakeToolsToRoot(){
	$toolsPath = GetModulePath "psake-tools.ps1"
	Copy-Item -Path $toolsPath -Destination (Get-Location).Path -Force
	$helpersPath = GetModulePath "psake-tools-helpers.ps1"
	Copy-Item -Path $helpersPath -Destination (Get-Location).Path -Force
}

function ImportPsake(){
	$psakePath = GetModulePath "psake.psm1"
	Import-Module $psakePath
}

try{
	DownloadNuget
	Write-Host "DownloadNuget ran"
}
Catch {
	throw "DownloadNuget failed."
}
try{
	DownloadAndImportModules
	Write-Host "DownloadAndImportModules ran"
}
Catch {
	throw "DownloadAndImportModules failed."
}
try{
	ImportPsake
	Write-Host "ImportPsake ran"
}
Catch {
	throw "ImportPsake failed."
}
try{
	CopyPsakeToolsToRoot
	Write-Host "CopyPsakeToolsToRoot ran"	
}
Catch {
	throw "CopyPsakeToolsToRoot failed."
}
try{
	Invoke-psake psake-tools.ps1 ($tasks.Split(',').Trim())	
	Write-Host "invoke psake ran"
}
Catch {
	throw " Invoke-psake psake-tools.ps with args failed."
}
Finally {
	if ($psake.build_success -eq $false) {
		throw "problem with psak.build_success"    	
	}
}
