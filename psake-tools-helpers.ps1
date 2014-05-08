
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

function Get-PublishCatalogConfig {
    param([string]$fileName)
    
	if (Test-Path $fileName) {
		Get-Content $fileName -Raw | ConvertFrom-Json
	}
}

function Publish-Catalog {
    param([string]$productFile='product.json')
    
	$staging = @{}
	$staging = Get-PublishCatalogConfig('staging.json')
	
    if ($staging.Count -eq 0) {
		$staging.url = $Env:staging_url;
		$staging.username = $Env:staging_username;
		$staging.password = $Env:staging_password;
	}
	
	if (-not (Test-Path $productFile)) {
		"File $productFile does not exist. Upload aborted."
	}	
	
    $response = Invoke-WebRequest `
	    -Uri $staging.url `
	    -Headers @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($staging.username+":"+$staging.password ))} `
	    -Method Put `
	    -InFile $productFile `
	    -ContentType 'application/json'
        
    if ($response.StatusCode -ne "200") {
        throw $response.Content					
    }
}

function Promote-Catalog {
    param([string]$productId)
    
	$staging = @{}
	$staging = Get-PublishCatalogConfig('staging.json')
    
	if ($staging.Count -eq 0) {
		$staging.url = $Env:staging_url;
	}

	$production = @{}
	$production = Get-PublishCatalogConfig('production.json')
	if ($production.Count -eq 0) {
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

function Push-GitCatalog {	
	$staging = @{}
	$staging = Get-PublishCatalogConfig('staging.json')
	if ($staging.Count -eq 0) {
		$staging.url = $Env:staging_url;
		$staging.username = $Env:staging_username;
		$staging.password = $Env:staging_password;
	}
	
	$git_files =  git show --name-only --pretty="format:"
	
	foreach($git_file in $git_files){
		if($git_file -ne "") {
			if ((Test-Path $git_file) -and ($git_file.EndsWith(".json",1))) {
				Write-Debug "Processing: $git_file"

				$stagingResponse = Invoke-WebRequest `
				    -Uri $staging.url `
				    -Headers @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($staging.username+":"+$staging.password ))} `
				    -Method Put `
				    -InFile $git_file `
				    -ContentType 'application/json'				
				
				Write-Debug " > $($stagingResponse.StatusCode) - $($stagingResponse.StatusDescription)"

				if ($stagingResponse.StatusCode -ne "200")
				{
                    throw $stagingResponse.Content					
				}
			}
			else{
				Write-Debug "Nothing to do."
			}
		}
	}	
}
