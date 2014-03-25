function Get-ConfigSample(){
	'{	
		"solution": "MySolution.sln",
		"projectToPublish": "MyPublishProject.csproj",
		"projectToPackage": "MyPackageProject.csproj",
		"configuration": "Release",
    	"platform": "Any CPU",    
    	"major": "2",
    	"minor": "1",
		"nugetSources": "http://packages.nuget.org/api/v2/;http://packages.otherSource.org"
	}'
}
# careful with the ";" in nugetSources

function Get-AssemblySample(){
"[assembly: AssemblyVersion(`"0.0.123.456`")][assembly: AssemblyFileVersion(`"0.0.789.123`")][assembly: AssemblyCompany(`"Company, Inc.`")][assembly: AssemblyDescription(`"SomeAssembly`")]"
}

function Get-AssemblySampleWithNewVersion($v){
"[assembly: AssemblyVersion(`"$v`")][assembly: AssemblyFileVersion(`"$v`")][assembly: AssemblyCompany(`"Company, Inc.`")][assembly: AssemblyDescription(`"SomeAssembly`")]"
}

function Setup-Object(){
	Setup -File 'build.properties.json' (Get-ConfigSample)
	Get-ConfigObjectFromFile "$TestDrive\build.properties.json"
} 

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"
."$here\psake-tools-helpers.ps1"


Describe "Get-ConfigObjectFromFile" {
	Context "When reading the configuration file" {
		$config = Setup-Object
		It "should return an object with the proper values" {
			$config.solution | Should Be "MySolution.sln"
			$config.configuration | Should Be "Release"
			$config.platform | Should Be "Any CPU"
			$config.major | Should Be "2"
			$config.minor | Should Be "1"
			$config.projectToPublish | Should Be "MyPublishProject.csproj"
			$config.projectToPackage | Should Be "MyPackageProject.csproj"
		}
	}
}

Describe "Get-NewestFilePath" {
	$folder = 'packages\Some.Library.Name'
	$library = 'Some.Library.Name.dll'
	
	$libraries = `
		"$folder.0.0.0.121\$library", `
		"$folder.0.0.2.1\$library", `
		"$folder.3.0.0.50\$library"
	
	$libraries | foreach { Setup -File $_ } 
	
	Context "When calling it with a path that cointains those libraries" {
		$path = Get-NewestFilePath $TestDrive $library
		 It "should get the newest one" {
		 	$path | Should Be "$TestDrive\$folder.3.0.0.50\$library"	
		 }
	}
}

Describe "New-NugetDirectory" {	
	Mock Get-Location -MockWith { return @{ Path = "$TestDrive"; } }	
	
	Context "When calling it" {
		New-NugetDirectory
		 It "should create the nuget folder" {		 	
		 	Test-Path "$TestDrive\.nuget" | Should be $true
		 }
	}
}

Describe "Get-Version" {	
	$config = Setup-Object
	
	Context "When calling it without the build number and a one digit day of year" {
		$date = Get-Date -Year 2014 -Month 1 -Day 1 -Hour 1 -Minute 23
		$result = Get-Version $date
		It "should return" {		 	
			$result | Should be "2.1.14001.0123"	
		}
	}
	
	Context "When calling it without the build number and a two digits day of year" {
		$date = Get-Date -Year 2014 -Month 1 -Day 20 -Hour 1 -Minute 23
		$result = Get-Version $date
		It "should return" {		 	
			$result | Should be "2.1.14020.0123"	
		}
	}
	
	Context "When calling it without the build number and a three digits day of year" {
		$date = Get-Date -Year 2014 -Month 4 -Day 10 -Hour 1 -Minute 23
		$result = Get-Version $date $null
		It "should return" {		 	
			$result | Should be "2.1.14100.0123"	
		}
	}
	
	Context "When calling it with the build number" {
		$date = Get-Date -Year 2014 -Month 1 -Day 1 -Hour 1 -Minute 23
		$result = Get-Version $date "2900"
		 It "should return" {		 	
		 	$result | Should be "2.1.14001.2900"
		 }
	}
}

Describe "Update-AssemblyInfo" {	
	$files = `
		"a\AssemblyInfo.cs",`
		"a\b.c\AssemblyInfo.cs",`
		"a\b-c\d\AssemblyInfo.cs"

	$files | foreach { Setup -File $_ (Get-AssemblySample) }
	
	$version = "0.1.2.3"
	
	Context "When calling it in a path that cointains three AssemblyInfo files" {
		Update-AssemblyInfo $TestDrive
		 It "should update the version values for the three files" {
		 	$files | foreach { (Get-Content $TestDrive\$_) | Should Be (Get-AssemblySampleWithNewVersion $version) }
		 }
	}
}

Describe "Get-EnvironmentVariableOrDefault" {
	
	Context "When calling it with a variable that doesn't exist" {
		$result = Get-EnvironmentVariableOrDefault "ThereShoulNotBeAVariableWithThisName" "defaultValue"
		 It "should return the default value " {		 	
		 	 $result | Should be "defaultValue"
		 }		 
	}
	
	Context "When calling it with a variable that does exist" {
		$result = Get-EnvironmentVariableOrDefault "Path" "defaultValue"		
		 It "should not be the default value" {		 	
		 	 $result | Should not be "defaultValue"
		 }
	}
}

Describe "Get-BuildCommand" {
	$config = Setup-Object
	
	Context "When calling it with the configuration initialized" {
		It "should return the msbuild command with the values from the configuration file" {		
			Get-BuildCommand |
			Should Be "msbuild MySolution.sln -t:Build -p:Configuration=Release `"-p:Platform=Any CPU`""
		}
	}
}

Describe "Get-CleanCommand" {
	$config = Setup-Object
	
	Context "When calling it with the configuration initialized" {
		It "should return the msbuild command with the values from the configuration file" {		
			Get-CleanCommand |
			Should Be "msbuild MySolution.sln -t:Clean -p:Configuration=Release `"-p:Platform=Any CPU`""
		}
	}
}

Describe "Get-PublishCommand" {
	$config = Setup-Object
	
	Context "When calling it with the configuration initialized" {
		It "should return the msbuild command with the values from the configuration file" {		
			Get-PublishCommand |
			Should Be "msbuild MyPublishProject.csproj -t:Publish -p:Configuration=Release `"-p:Platform=Any CPU`""			
		}
	}
}

Describe "Get-RestorePackagesCommand" {
	$config = Setup-Object
	
	Context "When calling it with the configuration initialized" {
		It "should return the msbuild command with the values from the configuration file" {		
			Get-RestorePackagesCommand |
			Should Be ".\\.nuget\nuget.exe restore MySolution.sln -Source http://packages.nuget.org/api/v2/;http://packages.otherSource.org"
		}
	}
}

Describe "Get-UpdatePackagesCommand" {
	$config = Setup-Object
	
	Context "When calling it with the configuration initialized" {
		It "should return the msbuild command with the values from the configuration file" {		
			Get-UpdatePackagesCommand |
			Should Be ".\\.nuget\nuget.exe update MySolution.sln -Source http://packages.nuget.org/api/v2/;http://packages.otherSource.org"
		}
	}
}

Describe "Get-GeneratePackageCommand" {
	$config = Setup-Object
	$version = "1.2.3.4"
	Context "When calling it with the configuration initialized" {
		It "should return the msbuild command with the values from the configuration file" {		
			Get-GeneratePackageCommand | 
			Should Be ".\\.nuget\nuget.exe pack MyPackageProject.csproj -Verbosity Detailed -Version 1.2.3.4 -prop Configuration=Release"			
		}
	}
}

Describe "Get-PushMyGetCommand" {
	$apiKey = "someKey"
	$repoUrl = "http://someUrl.org"
	
	Context "When calling it with the configuration initialized" {
		It "should return the msbuild command with the values from the configuration file" {		
			(Get-PushMyGetCommand $apiKey $repoUrl) | 
			Should Be ".\\.nuget\nuget.exe push *.nupkg someKey -Source http://someUrl.org"
		}
	}
}

Describe "Get-InstallNRunnersCommand" {	
	Context "When calling it" {
		It "should return the msbuild command" {		
			Get-InstallNRunnersCommand |
			Should Be ".\\.nuget\nuget.exe install NUnit.Runners -OutputDirectory packages"
		}
	}
}