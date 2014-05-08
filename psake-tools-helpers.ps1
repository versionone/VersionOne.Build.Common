
function Clean-Characters {
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[object]$obj
	)	
		$obj.psobject.properties |
		? {$_.Value.Contains(';') } |
		% {	$_.Value = ($_.Value -replace ';', '`;') }
		
		$obj
}


function Get-ConfigObjectFromFile {
	param([string]$fileName)
	
	gc $fileName -Raw | 
	ConvertFrom-Json |	
	Clean-Characters
}



function Get-EnvironmentVariableOrDefault {
	param([string]$variable, [string]$default)
	if([Environment]::GetEnvironmentVariable($variable))
	{
		[Environment]::GetEnvironmentVariable($variable)
	}
	else
	{
		$default
	}
}

function Get-NewestFilePath {
	param([string]$startingPath,[string]$file)
	
	$paths = @(ls -r -Path $startingPath -filter $file | sort FullName -descending)
	$paths[0].FullName
}

function New-NugetDirectory {
	param([string]$path)
	New-Item $path -name .nuget -type directory -force
}

function Get-NugetBinary {
	param([string]$path)
	$destination = $path + '\.nuget\nuget.exe'
	curl -Uri "http://nuget.org/nuget.exe" -OutFile $destination
}

function Get-BuildCommand {
	"msbuild $($config.solution) -t:Build -p:Configuration=$($config.configuration) `"-p:Platform=$($config.platform)`""
}

function Get-CleanCommand {
	"msbuild $($config.solution) -t:Clean -p:Configuration=$($config.configuration) `"-p:Platform=$($config.platform)`""
}

function Get-PublishCommand {
	"msbuild $($config.projectToPublish) -t:Publish -p:Configuration=$($config.configuration) `"-p:Platform=Any CPU`""
}

function Get-RestorePackagesCommand {
	".\\.nuget\nuget.exe restore $($config.solution) -Source $($config.nugetSources)"
}

function Get-UpdatePackagesCommand {
	".\\.nuget\nuget.exe update $($config.solution) -Source $($config.nugetSources)"
}

function Get-GeneratePackageCommand {
	".\\.nuget\nuget.exe pack $($config.projectToPackage) -Verbosity Detailed -Version $version -prop Configuration=$($config.configuration)"
}

function Get-PushMygetCommand {
	param([string]$apiKey,[string]$repoUrl)
	".\\.nuget\nuget.exe push *.nupkg $apiKey -Source $repoUrl"
}

function Get-InstallNRunnersCommand {
	".\\.nuget\nuget.exe install NUnit.Runners -OutputDirectory packages"
}

function Get-Assemblies {
	param([string]$startingPath)	
	if (-not $startingPath) { $startingPath = (pwd).Path }
	
	@(ls -r -path $startingPath -filter AssemblyInfo.cs) + 
	@(ls -r -path $startingPath -filter AssemblyInfo.fs)
}

function Update-Assemblies {
	param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]        
        $file
	)
	
	begin {
		$versionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
		$versionAssembly = 'AssemblyVersion("' + $version + '")';
		$versionFilePattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
		$versionAssemblyFile = 'AssemblyFileVersion("' + $version + '")'
	}
	
	process
	{
        echo Updating file $file.FullName
		$tmp = ($file.FullName + ".tmp")
		if (test-path ($tmp)) { remove-item $tmp }
			
		(gc $file.FullName) |
		% {$_ -replace $versionFilePattern, $versionAssemblyFile } | 
		% {$_ -replace $versionPattern, $versionAssembly } `
		> $tmp

		if (test-path ($file.FullName)) { remove-item $file.FullName }
		move-item $tmp $file.FullName -force			
	}    
}

function Get-Version {
	param([DateTime]$currentUtcDate, [string]$buildNumber)
	$year = $currentUtcDate.ToString("yy")		
	if( -not $buildNumber) { $buildNumber = $currentUtcDate.ToString("HHmm") }
	
	$dayOfyear = $currentUtcDate.DayOfYear
	if(([string]$dayOfyear).Length -eq 1){
		$dayOfyear=  "00" + $dayOfyear
	}
	elseif(([string]$dayOfyear).Length -eq 2){
		$dayOfyear = "0" + $dayOfyear
	}
	
	"$($config.major).$($config.minor).$year$dayOfyear.$buildNumber"
}

function Get-PreExtensions {
	param([string]$path)
    ,@(gci *.ps1 -Path $path | 
	? { $_.FullName -match "pre.[0-9]{3}\..*?\.ps1" }  | 
    sort FullName)
}

function Get-PostExtensions {
	param([string]$path)
	,@(gci *.ps1 -Path $path | 
	? { $_.FullName -match "post.[0-9]{3}\..*?\.ps1" }  | 
    sort FullName)
}

function Invoke-Extensions {
	param([Parameter(Mandatory=$false,ValueFromPipeline=$true)]$extension)
	
	process {
		if(-not $extension) { return }
        echo "The next extension has been loaded: $($extension.Name)"
		& ($extension.FullName)
	}
}

function Get-Tests {
	param([string]$path)
	,@(ls -r *.Tests.dll -Path $path | 
	? { $_.FullName -like "*\bin\$($config.configuration)\*.Tests.dll" })
}

function Invoke-NunitTests {
	param([string]$path)
	$testRunner = Get-NewestFilePath "$path\packages" "nunit-console-x86.exe"	
	Get-Tests $path | % { iex "$testRunner $($_.FullName)" }	
}

function Publish-Documentation {
	# ----- Prepare Branches ------------------------------------------------------
	git checkout -f gh-pages
	git checkout master

	# ----- Publish Documentation -------------------------------------------------
	## Publishes a subdirectory "doc" of the main project to the gh-pages branch.
	## From: http://happygiraffe.net/blog/2009/07/04/publishing-a-subdirectory-to-github-pages/
	$docHash = ((git ls-tree -d HEAD doc) -split "\s+")[2]
	$newCommit = (Write-Host "Auto-update docs." | git commit-tree $docHash -p refs/heads/gh-pages)
	git update-ref refs/heads/gh-pages $newCommit


	# ----- Push Docs -------------------------------------------------------------
	## Push changes.
	git push origin gh-pages
}
