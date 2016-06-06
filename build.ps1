function BuildAndPublishPackage {
	Write-Host "Building..."
	$version = "1.0.0."
	$destDir = "build"
	Copy-Item  psake-tools.ps1 $destDir
	Copy-Item  psake-tools-helpers.ps1 $destDir

	.nuget\nuget.exe pack  "$destDir\psake-tools.nuspec" -Verbosity Detailed -Version $version$env:BUILD_NUMBER
	.nuget\nuget.exe  push *.nupkg $env:MYGET_API_KEY -Source $env:MYGET_REPO_URL
}

function DownloadNuget {
	new-item (Get-Location).Path -name .nuget -type directory -force
	
	$source = "http://nuget.org/nuget.exe"
	$destination = (pwd).Path + '\.nuget\nuget.exe'
	$wc = New-Object System.Net.WebClient
	$wc.DownloadFile($source, $destination)	
}

function InstallPsGet {
	(Invoke-WebRequest "http://psget.net/GetPsGet.ps1") | iex
}

function InstallPester {
	Install-Module Pester
	Import-Module Pester
}

function RunPester {	
	 $result = Invoke-Pester -PassThru	 
	 if($result.FailedCount -ne 0) { throw "Some tests didn't pass."}
}

try{
	DownloadNuget
	InstallPsGet
	InstallPester
	RunPester
	BuildAndPublishPackage
}
catch{	
	echo $_.Exception.Message
	echo "Build failed."
	exit 1
}