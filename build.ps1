function BuildAndPublishPackage(){
	$version = "1.0.0."
	$destDir = "build"
	Copy-Item  VersionOne.Build.Common.psm1 $destDir

	.nuget\nuget.exe pack  "$destDir\VersionOne.Build.Common.nuspec" -Verbosity Detailed -Version $version$env:BUILD_NUMBER
	.nuget\nuget.exe  push *.nupkg $env:MYGET_API_KEY -Source $env:MYGET_REPO_URL
}

function GetNuget(){
	new-item (Get-Location).Path -name .nuget -type directory -force
	
	$source = "http://nuget.org/nuget.exe"
	$destination = (Get-Location).Path + '\.nuget\nuget.exe'
	$wc = New-Object System.Net.WebClient
	$wc.DownloadFile($source, $destination)	
}

GetNuget
BuildAndPublishPackage