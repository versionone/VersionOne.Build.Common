function Get-ConfigSample {
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

function Get-AssemblySample {
"[assembly: AssemblyVersion(`"0.0.123.456`")]" +
"[assembly: AssemblyFileVersion(`"0.0.789.123`")]" + 
"[assembly: AssemblyCompany(`"Company, Inc.`")]" + 
"[assembly: AssemblyDescription(`"SomeAssembly`")]"
}

function Get-AssemblySampleWithNewVersion {
param([string]$v)
"[assembly: AssemblyVersion(`"$v`")]" +
"[assembly: AssemblyFileVersion(`"$v`")]" +
"[assembly: AssemblyCompany(`"Company, Inc.`")]" + 
"[assembly: AssemblyDescription(`"SomeAssembly`")]"
}

function Setup-Object {
	Setup -File 'build.properties.json' (Get-ConfigSample)
	Get-ConfigObjectFromFile "$TestDrive\build.properties.json"
} 

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"
."$here\psake-tools-helpers.ps1"


Describe "Get-ConfigObjectFromFile" {
	Context "when reading the configuration file" {
		$config = Setup-Object
		It "should return an object with the proper values" {
			$config.solution | Should Be 'MySolution.sln'
			$config.configuration | Should Be 'Release'
			$config.platform | Should Be  'Any CPU'
			$config.major | Should Be '2'
			$config.minor | Should Be '1'
			$config.projectToPublish | Should Be 'MyPublishProject.csproj'
			$config.projectToPackage | Should Be 'MyPackageProject.csproj'
			$config.nugetSources | Should Be 'http://packages.nuget.org/api/v2/`;http://packages.otherSource.org'
		}
	}
}

Describe "Get-NewestFilePath" {
	$folder = 'packages\Some.Library.Name'
	$library = 'Some.Library.Name.dll'
	
	$libraries =
		"$folder.0.0.0.121\$library",
		"$folder.0.0.2.1\$library",
		"$folder.3.0.0.50\$library"
	
	$libraries | % { Setup -File $_ } 
	
	Context "when calling it with a path that cointains those libraries" {
		$path = Get-NewestFilePath $TestDrive $library
		 It "should get the newest one" {
		 	$path | Should Be "$TestDrive\$folder.3.0.0.50\$library"	
		 }
	}
}

Describe "New-NugetDirectory" {
	Context "when calling it with a path parameter" {
		New-NugetDirectory $TestDrive > $null
		 It "should create the nuget folder in that location" {		 	
		 	Test-Path "$TestDrive\.nuget" | Should be $true
		 }
	}
}

Describe "Get-NugetBinary" {
	Context "when calling it with a path parameter" {
		mock Invoke-WebRequest { Setup -File ("\.nuget\nuget.exe") } -Verifiable
		Get-NugetBinary $TestDrive		
		
		It "should call Invoke-WebRequest" {
			Assert-VerifiableMocks
		}
		It "should put the nuget binary in that location" {		 	
		 	Test-Path "$TestDrive\.nuget" | Should be $true
		 }
	}
}

Describe "Get-Version" {	
	$config = Setup-Object
	
	Context "when calling it without the build number and a one digit day of year" {
		$date = Get-Date -Year 2014 -Month 1 -Day 1 -Hour 1 -Minute 23
		$result = Get-Version $date
		It "should return version with the proper length" {
			$result | Should be "2.1.14001.0123"	
		}
	}
	
	Context "when calling it without the build number and a two digits day of year" {
		$date = Get-Date -Year 2014 -Month 1 -Day 20 -Hour 1 -Minute 23
		$result = Get-Version $date
		It "should return version with the proper length" {
			$result | Should be "2.1.14020.0123"	
		}
	}
	
	Context "when calling it without the build number and a three digits day of year" {
		$date = Get-Date -Year 2014 -Month 4 -Day 10 -Hour 1 -Minute 23
		$result = Get-Version $date $null
		It "should return version with the proper length" {
			$result | Should be "2.1.14100.0123"	
		}
	}
	
	Context "when calling it with the build number" {
		$date = Get-Date -Year 2014 -Month 1 -Day 1 -Hour 1 -Minute 23
		$result = Get-Version $date "2900"
		It "should return version with the build number as the last element" {
		 	$result | Should be "2.1.14001.2900"
		 }
	}
}

Describe "Update-AssemblyInfo" {
	Context "when calling it with a path that cointains three AssemblyInfo files" {
		$version = "0.1.2.3"
		$files =
			"a\AssemblyInfo.cs",
			"a\b.c\AssemblyInfo.cs",
			"a\b-c\d\AssemblyInfo.cs"

		$files | % { Setup -File $_ (Get-AssemblySample) }
		Update-AssemblyInfo $TestDrive > $null
		
		It "should update the version values for the three files" {
			$files | 
			% { (cat $TestDrive\$_) | 
			Should Be (Get-AssemblySampleWithNewVersion $version) }
		 }
	}
}

Describe "Get-EnvironmentVariableOrDefault" {
	
	Context "when calling it with a variable that doesn't exist" {
		$result = Get-EnvironmentVariableOrDefault "ThereShoulNotBeAVariableWithThisName" "defaultValue"
		 It "should return the default value " {		 	
		 	 $result | Should be "defaultValue"
		 }		 
	}
	
	Context "when calling it with a variable that does exist" {
		$result = Get-EnvironmentVariableOrDefault "Path" "defaultValue"		
		 It "should not return be the default value" {		 	
		 	 $result | Should not be "defaultValue"
		 }
	}
}

Describe "Get-Extensions" {
	Context "when calling it with a path that contains several files" {
		$files =
		"build-ex.001.script.zzz.ps1",
		"build-ex.010.script.aaa.ps1",
		"build-ex.100.script.mmm.ps1",
		"build-ex.100.foo.script.ps1",
		"build-ex.script.foo.mmm.ps1",
		"build-ex.script.foo.mmm.ps11",
		"build-ex.script.foo.mmm.ps",
		"some-ex.001.script.zzz.ps1"		
		
	$files | % { Setup -File $_ '' }
		$result = Get-Extensions $TestDrive
		It "should only return files that match the pattern build-ex.*.script.*.ps1" {
			$result.Length | Should Be 3			
		}
		
		It "should return scripts paths in the proper order" {
			$result[0].Name | Should Be "build-ex.001.script.zzz.ps1"
			$result[1].Name | Should Be "build-ex.010.script.aaa.ps1"
			$result[2].Name | Should Be "build-ex.100.script.mmm.ps1"
		}
	}
}

Describe "Invoke-Extensions" {
	Context "when calling it with three extensions" {
		$files = 
		"build-ex.001.script.zzz.ps1",
		"build-ex.010.script.aaa.ps1",
		"build-ex.100.script.mmm.ps1"
	
		0,1,2 | % { Setup -File $files[$_] "New-Item $TestDrive -name $_.tmp -type file" }
		(Get-Extensions $TestDrive) | Invoke-Extensions > $null
		
		It "should run the three scripts that create a temporal file each one" {
			0,1,2 | % { Test-Path "$TestDrive\$_.tmp" | Should Be $true }			
		}
	}
	
	Context "when calling it with an empty array" {
		@() | Invoke-Extensions > $null
		It "shouldn't throw an exception" { }
	}
	
	Context "when calling it with null" {
		$null | Invoke-Extensions > $null
		It "shouldn't throw an exception" { }
	}
}

Describe "Get-Tests" {
	Context "when calling it with a path that has test dlls" {
		$config = Setup-Object
		
		"foo\bin\release\project.Tests.dll",
		"foo\bin\debug\project.Tests.dll",
		"foo\obj\release\project.Tests.dll",
		"foo\obj\debug\project.Tests.dll",
		"release\project.Tests.dll",
		"project.Tests.dll",
		".Tests.dll",
		"Tests.dll" | 
		% { Setup -File $_ '' }
		
		It "should return the dlls that are at the proper folder for the current build configuration (debug, release)" {
			 (Get-Tests $TestDrive).Length | Should Be 1
		}
	}
}

Describe "Get-BuildCommand" {
	Context "when calling it with the configuration initialized" {
		$config = Setup-Object
		It "should return the msbuild command with the values from the configuration file" {		
			Get-BuildCommand |
			Should Be 'msbuild MySolution.sln -t:Build -p:Configuration=Release "-p:Platform=Any CPU"'
		}
	}
}

Describe "Get-CleanCommand" {
	Context "when calling it with the configuration initialized" {
		$config = Setup-Object
		It "should return the msbuild command with the values from the configuration file" {		
			Get-CleanCommand |
			Should Be 'msbuild MySolution.sln -t:Clean -p:Configuration=Release "-p:Platform=Any CPU"'
		}
	}
}

Describe "Get-PublishCommand" {
	Context "when calling it with the configuration initialized" {
		$config = Setup-Object
		It "should return the msbuild command with the values from the configuration file" {		
			Get-PublishCommand |
			Should Be 'msbuild MyPublishProject.csproj -t:Publish -p:Configuration=Release "-p:Platform=Any CPU"'
		}
	}
}

Describe "Get-RestorePackagesCommand" {
	Context "when calling it with the configuration initialized" {
		$config = Setup-Object
		It "should return the expected command with the values from the configuration file" {		
			Get-RestorePackagesCommand |
			Should Be '.\\.nuget\nuget.exe restore MySolution.sln -Source http://packages.nuget.org/api/v2/`;http://packages.otherSource.org'
		}
	}
}

Describe "Get-UpdatePackagesCommand" {
	Context "when calling it with the configuration initialized" {
		$config = Setup-Object
		It "should return the expected command with the values from the configuration file" {		
			Get-UpdatePackagesCommand |
			Should Be '.\\.nuget\nuget.exe update MySolution.sln -Source http://packages.nuget.org/api/v2/`;http://packages.otherSource.org'
		}
	}
}

Describe "Get-GeneratePackageCommand" {	
	Context "when calling it with the configuration initialized" {
		$config = Setup-Object
		$version = "1.2.3.4"
		It "should return the expected command with the values from the configuration file" {		
			Get-GeneratePackageCommand | 
			Should Be '.\\.nuget\nuget.exe pack MyPackageProject.csproj -Verbosity Detailed -Version 1.2.3.4 -prop Configuration=Release'
		}
	}
}

Describe "Get-PushMyGetCommand" {
	Context "when calling it with the api key and the repository url" {
		$apiKey = "someKey"
		$repoUrl = "http://someUrl.org"
		It "should return the expected command" {
			(Get-PushMyGetCommand $apiKey $repoUrl) | 
			Should Be '.\\.nuget\nuget.exe push *.nupkg someKey -Source http://someUrl.org'
		}
	}
}

Describe "Get-InstallNRunnersCommand" {	
	Context "when calling it" {
		It "should return the expected command" {
			Get-InstallNRunnersCommand |
			Should Be '.\\.nuget\nuget.exe install NUnit.Runners -OutputDirectory packages'
		}
	}
}