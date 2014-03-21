
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

function Get-NewestFilePath([string]$startingPath,[string]$file){
	$paths = @(Get-ChildItem -r -Path $startingPath -filter $file | Sort-Object FullName  -descending)
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
	"msbuild $($config.projectToPublish) -t:Publish -p:Configuration=$($config.configuration) `"-p:Platform=Any CPU`""
}

function Get-RestorePackagesCommand(){
	".\\.nuget\nuget.exe restore $($config.solution) -Source $($config.nugetSources)"
}

function Get-UpdatePackagesCommand(){
	".\\.nuget\nuget.exe update $($config.solution) -Source $($config.nugetSources)"
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
	param(
        [Parameter(Mandatory=$false, Position=0, ValueFromPipeline=$true)]
        [string]
        $startingPath
	)
	
	if (-not $startingPath) { $startingPath = (Get-Location).Path }
	
	$versionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
	$versionAssembly = 'AssemblyVersion("' + $version + '")';
	$versionFilePattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
	$versionAssemblyFile = 'AssemblyFileVersion("' + $version + '")';	
	
	Get-ChildItem -r -path $startingPath -filter AssemblyInfo.cs | 
	Update-Assemblies	
	
	Get-ChildItem -r -path $startingPath -filter AssemblyInfo.fs |
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