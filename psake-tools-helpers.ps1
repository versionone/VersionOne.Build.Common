
function Clean-Characters {
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[object]$obj
	)	
		$obj.psobject.properties |
		? { $_.Value.GetType().Name.Equals("String") -and $_.Value.Contains(';')} |
		% {	$_.Value = ($_.Value -replace ';', '`;') }

		$obj.psobject.properties |
		? { $_.Value.GetType().Name.Equals("Object[]") } |
		% {	$_.Value | % { $_ = (Clean-Characters $_ ) } }

		$obj.psobject.properties |
		? { $_.Value.GetType().Name.Equals("Object") } |
		% {	$_.Value | % { $_ = (Clean-Characters $_ ) } }
		
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
	"msbuild $($config.projectToPublish) -t:Publish -p:Configuration=$($config.configuration) `"-p:Platform=AnyCPU`""
}

function Get-RestorePackagesCommand {
	".\\.nuget\nuget.exe restore $($config.solution) -Source $($config.nugetSources)"
}

function Get-UpdatePackagesCommand {
	".\\.nuget\nuget.exe update $($config.solution) -Source $($config.nugetSources) -NonInteractive -FileConflictAction Overwrite"
}

function Get-GeneratePackageCommand {
    param([string]$project)
	".\\.nuget\nuget.exe pack $project -Verbosity Detailed -Version $version -prop Configuration=$($config.configuration)"
}

function Get-GeneratePackageCommandFromNuspec {
    param([string]$nuspecFilePath)
	".\\.nuget\nuget.exe pack $nuspecFilePath -Verbosity Detailed"
}

function Get-PushMygetCommand {
	param([string]$apiKey,[string]$repoUrl)
	".\\.nuget\nuget.exe push *.nupkg $apiKey -Source $repoUrl"
}

function Get-PushNugetCommand {
	param([string]$apiKey)
	".\\.nuget\nuget.exe push *.nupkg $apiKey"
}

function Get-InstallNRunnersCommand {
	".\\.nuget\nuget.exe install NUnit.Runners -OutputDirectory packages"
}

function Get-InstallNSpecCommand {
	".\\.nuget\nuget.exe install nspec -OutputDirectory packages"
}

function Get-ProjectsToPackage {
    ($config.projectToPackage).Split(",")    
}

function Get-ProjectsToZip {
	($config.projectsToZip).Split(",")
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
		if ($config.assemblyInfo -ne $null){
			$config.assemblyinfo |
			% {
				if((get-item $file.DirectoryName).Parent.Name -eq $_.id)
				{
					$assemblyContent = `
"using System;
using System.Reflection;
using System.Resources;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
[assembly: AssemblyVersion(""$version"")]
[assembly: AssemblyFileVersion(""$version"")]

[assembly: AssemblyProduct(""$($_.product)"")]
[assembly: AssemblyTitle(""$($_.title)"")]
[assembly: AssemblyDescription(""$($_.description)"")]
[assembly: AssemblyCompany(""$($_.company)"")]
[assembly: AssemblyCopyright(""$($_.copyright)"")]
[assembly: AssemblyConfiguration(""$($config.configuration)"")]" > $tmp
				}
			}
			
		}
		else {
			(gc $file.FullName) |
			% {$_ -replace $versionFilePattern, $versionAssemblyFile } | 
			% {$_ -replace $versionPattern, $versionAssembly } `
			> $tmp
		}	

		if (test-path ($file.FullName)) { remove-item $file.FullName }
		move-item $tmp $file.FullName -force			
	}    
}

function Get-Version {
	param([DateTime]$currentUtcDate, [string]$buildNumber)
	if(($config.version -ne $null) -and ($config.version -match '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')){
		$version = $config.version
	}
	else {
		$year = $currentUtcDate.ToString("yy")		
		if( -not $buildNumber) { $buildNumber = $currentUtcDate.ToString("HHmm") }

		$dayOfyear = $currentUtcDate.DayOfYear
		if(([string]$dayOfyear).Length -eq 1){
			$dayOfyear=  "00" + $dayOfyear
		}
		elseif(([string]$dayOfyear).Length -eq 2){
			$dayOfyear = "0" + $dayOfyear
		}
		$version = "$($config.major).$($config.minor).$year$dayOfyear.$buildNumber"
	}
	return $version
}

function Get-PreExtensions {
	param([string]$path)
    [array](gci *.ps1 -Path $path | 
	? { $_.FullName -match "pre.[0-9]{3}\..*?\.ps1" }  | 
    sort FullName)
}

function Get-PostExtensions {
	param([string]$path)
	[array](gci *.ps1 -Path $path | 
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
	$target = Get-Tests $path
	$bin = Get-NewestFilePath "$path\packages" "nunit-console-x86.exe"
	Invoke-TestsRunner $bin $target
}

function Invoke-NspecTests {
	param([string]$path)
	$target = Get-Tests $path
	$bin = Get-NewestFilePath "$path\packages" "NSpecRunner.exe"
	Invoke-TestsRunner $bin $target
}

function Invoke-MsTests {
	param([string]$path)
	$target = Get-Tests $path
	#$bin = Get-NewestFilePath (Get-ChildItem -path $env:systemdrive\ -filter "mstest.exe" -erroraction silentlycontinue -recurse)[0].FullName
	$bin = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\MSTest.exe"
	$target | % { iex "& '$bin' /testcontainer:'$($_.FullName)' /resultsfile:'$env:WORKSPACE\$($_.Name -replace '.Tests.dll', '.TestResults.trx')'" }
}

function Invoke-TestsRunner {
	param($bin,$target)
    
	if ($target.Length -ne 0) {
		$target | % { iex "& '$bin' '$($_.FullName)'" }
	} else {
		Write-Host "There are no targets specified to run."
	}
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

function Get-PublishCatalogConfig {
    param([string]$fileName)
    
	if (Test-Path $fileName) {
		Get-Content $fileName -Raw | ConvertFrom-Json
	}
}

function Publish-Catalog {
    param([string]$productFile='product.json')
    
	$staging = Get-PublishCatalogConfig 'staging.json'
	
    if ($staging -eq $null) {
        $staging = @{}
		$staging.url = $Env:staging_url;
		$staging.username = $Env:staging_username;
		$staging.password = $Env:staging_password;
	}
	
	if (-not (Test-Path $productFile)) {
		"File $productFile does not exist. Upload aborted."
	}	
	
    try{
	    $response = Invoke-WebRequest `
		    -Uri $staging.url `
		    -Headers @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($staging.username+":"+$staging.password ))} `
		    -Method Put `
		    -InFile $productFile `
		    -ContentType 'application/json'
	}
	catch {
	    if($_.Exception.Response -ne $null){
	        $stream = $_.Exception.Response.GetResponseStream()
	        [void]$stream.Seek(0, [System.IO.SeekOrigin]::Begin)
	        $reader = New-Object System.IO.StreamReader $stream
	        $response = $reader.ReadToEnd()
	        $reader.close()
	        $stream.close()
	        throw $_.Exception.Message + "`nFile $productFile failed with response: " + $response
	    }
	    else{
	        throw $_.Exception
	    }
	}
        
    if ($response.StatusCode -ne "200") {
        throw $response.Content					
    }
    
    Write-Host $response.Content
}

function Promote-Catalog {
    param([string]$productId)   
	
	$staging = Get-PublishCatalogConfig 'staging.json'
    
	if ($staging -eq $null) {
        $staging = @{}
		$staging.url = $Env:staging_url;
	}
	
	$production = Get-PublishCatalogConfig 'production.json'
	if ($production -eq $null) {
        $production = @{}
		$production.url = $Env:production_url;
		$production.username = $Env:production_username;
		$production.password = $Env:production_password;
	}
    
	$parameters = @{'id'= $productId}
	
	$stagingResponse = Invoke-WebRequest `
	    -Uri $staging.url `
	    -Method Get `
	    -Body $parameters
	
	Write-Debug "staging: $($stagingResponse.StatusCode) - $($stagingResponse.StatusDescription)"
	
	$productionResponse = Invoke-WebRequest `
	    -Uri $production.url `
	    -Headers @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($production.username+":"+$production.password ))} `
	    -Method Put `
	    -Body $stagingResponse.Content `
	    -ContentType 'application/json'
	
	Write-Debug "production: $($productionResponse.StatusCode) - $($productionResponse.StatusDescription)"
	
	$productionResponse
}

function Publish-CatalogFromGitShow {
	$staging = Get-PublishCatalogConfig 'staging.json'
	if ($staging -eq $null) {
        $staging = @{}
		$staging.url = $Env:staging_url;
		$staging.username = $Env:staging_username;
		$staging.password = $Env:staging_password;
	}
	
	$git_files =  git show --name-only --pretty="format:"
	
	foreach($git_file in $git_files){
		if($git_file -ne "") {
			if ((Test-Path $git_file) -and ($git_file.EndsWith(".json",1))) {
				Write-Debug "Processing: $git_file"
				try{
					$stagingResponse = Invoke-WebRequest `
					    -Uri $staging.url `
					    -Headers @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($staging.username+":"+$staging.password ))} `
					    -Method Put `
					    -InFile $git_file `
					    -ContentType 'application/json'				
					
					Write-Debug " > $($stagingResponse.StatusCode) - $($stagingResponse.StatusDescription)"
				}
				catch {
				    if($_.Exception.Response -ne $null){
				        $stream = $_.Exception.Response.GetResponseStream()
				        [void]$stream.Seek(0, [System.IO.SeekOrigin]::Begin)
				        $reader = New-Object System.IO.StreamReader $stream
				        $response = $reader.ReadToEnd()
				        $reader.close()
				        $stream.close()
				        throw $_.Exception.Message + "`nFile $git_file failed with response: " + $response
				    }
				    else{
				        throw $_.Exception
				    }
				}


                
                Write-Host $stagingResponse.Content
			}
			else{
				Write-Debug "Nothing to do."
			}
		}
	}	
}

function Compress-Folder {
    param($targetFolder, $zipPathDestination)
    
    $zipFileName = Split-Path $zipPathDestination -Leaf
	[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
	$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
	[System.IO.Compression.ZipFile]::CreateFromDirectory($targetFolder,
	    "$Env:TEMP\$zipFileName", $compressionLevel, $false)        
        
    Move-Item -Path "$Env:TEMP\$zipFileName" -Destination $zipPathDestination -Force        
}

function Compress-FileList {
	param([string]$path)
	[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem")
	[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.ZipFile")
	[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.ZipFileExtensions")
	$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
	if($config.zip -ne $null){
		$config.zip | 
		% { 
			$zipFilePath = "$path\$($_.name)_$version.zip"
			Write-Host $zipFilePath
			if(Test-Path $zipFilePath) { Remove-Item $zipFilePath }
			$archive = [System.IO.Compression.ZipFile]::Open($zipFilePath,"Update")	
			$_.filesToZip.Split(",") | 
			% {
				$file = Get-NewestFilePath $path $_
				$null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file, $_, $compressionLevel)
			}
			$archive.Dispose()
		}
	}
}