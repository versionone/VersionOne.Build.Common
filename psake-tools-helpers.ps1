
function Get-ConfigObjectFromFile($file){
	cat $file -Raw | ConvertFrom-Json	
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
	$paths = @(ls -r -Path $startingPath -filter $file | sort FullName -descending)
	$paths[0].FullName
}

function New-NugetDirectory(){
	New-Item (pwd).Path -name .nuget -type directory -force
}

function Get-NugetBinary (){		
	$destination = (pwd).Path + '\.nuget\nuget.exe'	
	curl -Uri "http://nuget.org/nuget.exe" -OutFile $destination
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

function Get-PushMygetCommand([string]$apiKey,[string]$repoUrl) {	
	".\\.nuget\nuget.exe push *.nupkg $apiKey -Source $repoUrl"
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
	
	if (-not $startingPath) { $startingPath = (pwd).Path }
	
	$versionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
	$versionAssembly = 'AssemblyVersion("' + $version + '")';
	$versionFilePattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
	$versionAssemblyFile = 'AssemblyFileVersion("' + $version + '")';	
	
	ls -r -path $startingPath -filter AssemblyInfo.cs | 
	Update-Assemblies	
	
	ls -r -path $startingPath -filter AssemblyInfo.fs |
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
			Write-Host Updating file $file.FullName -ForegroundColor green
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

function Get-Version([DateTime]$currentUtcDate, [string]$buildNumber){	
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

function Get-Extensions([string]$path)
{
	@(ls build-ex.*.script.*.ps1 -Path $path | sort FullName)
}

function Invoke-Extensions([object[]]$extensions) {
	$extensions |% {
		Write-Host "The next extension has been loaded: $_ "  -ForegroundColor green
		& $_.FullName
	}
}