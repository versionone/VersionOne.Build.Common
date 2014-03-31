
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
	
	cat $fileName -Raw | 
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
        [object[]]
        $files
	)
	
	begin {
		$versionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
		$versionAssembly = 'AssemblyVersion("' + $version + '")';
		$versionFilePattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
		$versionAssemblyFile = 'AssemblyFileVersion("' + $version + '")'
	}
	
	process
	{		
		foreach ($file in $files)
		{			
			echo Updating file $file.FullName
			$tmp = ($file.FullName + ".tmp")
			if (test-path ($tmp)) { remove-item $tmp }
			
			(cat $file.FullName) |
			% {$_ -replace $versionFilePattern, $versionAssemblyFile } | 
			% {$_ -replace $versionPattern, $versionAssembly } `
			> $tmp

			if (test-path ($file.FullName)) { remove-item $file.FullName }
			move-item $tmp $file.FullName -force			
		}
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

function Get-Extensions {
	param([string]$path)
	,@(ls build-ex.*.script.*.ps1 -Path $path | sort FullName)
}

function Invoke-Extensions {
	param(
        [Parameter(Mandatory=$false, Position=0, ValueFromPipeline=$true)]
        [object[]]
        $extensions
	)
	
	process {
		if(-not $extensions) { return }
		$extensions |% {
			echo "The next extension has been loaded: $_ "
			& $_.FullName
		}
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