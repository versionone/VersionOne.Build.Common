function Get-ConfigSample {
	'{
		"solution": "MySolution.sln",
		"projectToPublish": "MyPublishProject.csproj",
		"projectToPackage": "MyPackageProject.csproj,MyPackageProject2.csproj",
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
			$config.projectToPackage | Should Be 'MyPackageProject.csproj,MyPackageProject2.csproj'
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
			Assert-VerifiableMock
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

Describe "Get-Assemblies" {
	Context "when calling it with a path that contains
        four AssemblyInfo files on different directories" {
		"a\AssemblyInfo.cs",
		"a\b.c\AssemblyInfo.cs",
		"a\b-c\d\AssemblyInfo.cs",
		"a\b-c\d\efg\AssemblyInfo.fs",
        "a\b-c\d\efg\AssemblyInfo.zs",
        "AssemblyInfo" |
		% { Setup -File $_ (Get-AssemblySample) }

		$assemblies = Get-Assemblies $TestDrive

		It "should get all those files" {
			$assemblies.Length | Should Be 4
		 }
	}
}

Describe "Update-Assemblies" {
	Context "when calling with the path of four AssemblyInfo files" {
		$version = "0.1.2.3"
		$files =
			"a\AssemblyInfo.cs",
			"a\b.c\AssemblyInfo.cs",
			"a\b-c\d\AssemblyInfo.cs",
			"a\b-c\d\efg\AssemblyInfo.fs"

		$files | % { Setup -File $_ (Get-AssemblySample) }
		Get-Assemblies $TestDrive | Update-Assemblies > $null

		It "should update the version values for those files" {
			$files |
			% { (cat $TestDrive\$_) |
			Should Be (Get-AssemblySampleWithNewVersion $version) }
		 }
	}

	Context "when calling with assemblyInfo in config" {
		$version = "0.1.2.3"
		$cfg = @{
			"version" = $version;
			"assemblyInfo"= @(@{
				"id" = "VersionOne.MyProject";
				"product" = "VersionOne.Product";
				"title" = "VersionOne.Title";
				"description" = "My VersionOne product";
				"company" = "VersionOne, Inc.";
				"copyright" = "da kopyright"
				})
		}

		Setup -File "VersionOne.MyProject\Properties\AssemblyInfo.cs" (Get-AssemblySample)
		Get-Item "$TestDrive\VersionOne.MyProject\Properties\AssemblyInfo.cs" | Update-Assemblies -Cfg $cfg

		It "should update assembly info" {
			$expected = "using System;
using System.Reflection;
using System.Resources;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
[assembly: AssemblyVersion(""$($cfg.version)"")]
[assembly: AssemblyFileVersion(""$($cfg.version)"")]

[assembly: AssemblyProduct(""$($cfg.assemblyInfo[0].product)"")]
[assembly: AssemblyTitle(""$($cfg.assemblyInfo[0].title)"")]
[assembly: AssemblyDescription(""$($cfg.assemblyInfo[0].description)"")]
[assembly: AssemblyCompany(""$($cfg.assemblyInfo[0].company)"")]
[assembly: AssemblyCopyright(""$($cfg.assemblyInfo[0].copyright)"")]
[assembly: AssemblyConfiguration(""$($cfg.assemblyInfo[0].configuration)"")]"

			$actual = Get-Content -Raw "$TestDrive\VersionOne.MyProject\Properties\AssemblyInfo.cs"
			$actual.Trim() | Should be $expected
		}
	}

	Context "when calling with assemblyInfo in config and omiting a field" {
		$version = "0.1.2.3"
		$cfg = @{
			"version" = $version;
			"product" = "da product"
			"title" = "da title"
			"assemblyInfo"= @(@{
				"id" = "VersionOne.MyProject";
#no product				"product" = "VersionOne.Product";
#no title				"title" = "VersionOne.Title";
				"description" = "My VersionOne product";
				"company" = "VersionOne, Inc.";
				"copyright" = "da kopyright"
				})
		}

		Setup -File "VersionOne.MyProject\Properties\AssemblyInfo.cs" (Get-AssemblySample)
		Get-Item "$TestDrive\VersionOne.MyProject\Properties\AssemblyInfo.cs" | Update-Assemblies -Cfg $cfg

		It "should update assembly info" {
			$expected = "using System;
using System.Reflection;
using System.Resources;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
[assembly: AssemblyVersion(""$($cfg.version)"")]
[assembly: AssemblyFileVersion(""$($cfg.version)"")]

[assembly: AssemblyProduct(""$($cfg.product)"")]
[assembly: AssemblyTitle(""$($cfg.title)"")]
[assembly: AssemblyDescription(""$($cfg.assemblyInfo[0].description)"")]
[assembly: AssemblyCompany(""$($cfg.assemblyInfo[0].company)"")]
[assembly: AssemblyCopyright(""$($cfg.assemblyInfo[0].copyright)"")]
[assembly: AssemblyConfiguration(""$($cfg.assemblyInfo[0].configuration)"")]"

			$actual = Get-Content -Raw "$TestDrive\VersionOne.MyProject\Properties\AssemblyInfo.cs"
			$actual.Trim() | Should be $expected
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

Describe "Get-PreExtensions" {
	Context "when calling it with a path that contains several files" {
		$files =
		"pre.001.zzz.ps1",
		"pre.010.aaa.ps1",
		"pre.100.mmm.ps1",
		"pre.101.foo.script.ps1",
		"pre.script.foo.mmm.ps1",
		"some-ex.001.script.zzz.ps1"

	    $files | % { Setup -File $_ '' }

        $result = Get-PreExtensions $TestDrive
		It "should only return files that match the pattern pre.number.*.ps1" {
			$result.Length | Should Be 4
		}

		It "should return scripts paths in the proper order" {
			$result[0].Name | Should Be "pre.001.zzz.ps1"
			$result[1].Name | Should Be "pre.010.aaa.ps1"
			$result[2].Name | Should Be "pre.100.mmm.ps1"
            $result[3].Name | Should Be "pre.101.foo.script.ps1"
		}
	}
}

Describe "Get-PostExtensions" {
	Context "when calling it with a path that contains several files" {
		$files =
        "post.001.zzz.ps1",
		"post.010.aaa.ps1",
		"post.100.mmm.ps1",
		"post.101.foo.script.ps1",
		"build-ex.001.script.zzz.ps1",
		"build-ex.010.script.aaa.ps1",
		"build-ex.100.script.mmm.ps1",
		"build-ex.100.foo.script.ps1",
		"build-ex.script.foo.mmm.ps1",
		"build-ex.script.foo.mmm.ps11",
		"build-ex.script.foo.mmm.ps",
		"some-ex.001.script.zzz.ps1"

	$files | % { Setup -File $_ '' }
		$result = Get-PostExtensions $TestDrive
		It "should only return files that match the pattern post.number.*.ps1" {
			$result.Length | Should Be 4
		}

		It "should return scripts paths in the proper order" {
			$result[0].Name | Should Be "post.001.zzz.ps1"
			$result[1].Name | Should Be "post.010.aaa.ps1"
			$result[2].Name | Should Be "post.100.mmm.ps1"
            $result[3].Name | Should Be "post.101.foo.script.ps1"
		}
	}
}

Describe "Invoke-Extensions" {
	Context "when calling it with three extensions" {
		$files =
		"pre.001.script.zzz.ps1",
		"pre.010.script.aaa.ps1",
		"pre.100.script.mmm.ps1"

		0,1,2 | % { Setup -File $files[$_] "New-Item $TestDrive -name $_.tmp -type file" }
		(Get-PreExtensions $TestDrive) | Invoke-Extensions > $null

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

Describe "Get-UnitTests" {
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
			 (Get-UnitTests $TestDrive).Length | Should Be 1
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
			Should Be 'msbuild MyPublishProject.csproj -t:Publish -p:Configuration=Release "-p:Platform=AnyCPU"'
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
			Should Be '.\\.nuget\nuget.exe update MySolution.sln -Source http://packages.nuget.org/api/v2/`;http://packages.otherSource.org -NonInteractive -FileConflictAction Overwrite'
		}
	}
}

Describe "Get-GeneratePackageCommand" {
	Context "when calling it with the project to package" {
		$config = Setup-Object
		$version = "1.2.3.4"
		It "should return the expected command with the values from the configuration file" {
			Get-GeneratePackageCommand "MyPackageProject.csproj" |
			Should Be '.\\.nuget\nuget.exe pack MyPackageProject.csproj -Verbosity Detailed -Version 1.2.3.4 -prop "Configuration=Release"'
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

Describe "Get-PushNuGetCommand" {
	Context "when calling it with the api key" {
		$apiKey = "someKey"
		It "should return the expected command" {
			(Get-PushNuGetCommand $apiKey) |
			Should Be '.\\.nuget\nuget.exe push *.nupkg -ApiKey someKey -Source https://api.nuget.org/v3/index.json'
		}
	}
    
    Context "when calling it with the api key and source url" {
		$apiKey = "someKey"
        $sourceUrl = "sourceUrl"
		It "should return the expected command" {
			(Get-PushNuGetCommand $apiKey $sourceUrl) |
			Should Be '.\\.nuget\nuget.exe push *.nupkg -ApiKey someKey -Source sourceUrl'
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

Describe "Get-InstallNSpecCommand" {
	Context "when calling it" {
		It "should return the expected command" {
			Get-InstallNSpecCommand |
			Should Be '.\\.nuget\nuget.exe install nspec -OutputDirectory packages'
		}
	}
}

Describe "Compress-Folder" {
	Context "when calling it with a path with 3 files" {
        $files = "one.dll","two.txt", "three.sln"
	    $files | % { Setup -File $_ '' }
        Compress-Folder "$TestDrive" "$TestDrive\test.zip"

		It "compresses the 3 files into a zip specified as a parameter" {
            Test-Path "$TestDrive\test.zip" | Should be $true
		}
	}
}

Describe "IsPathRooted" {
	Context "when calling it with a relative path" {
		$result = IsPathRooted -Path "my\relative\path"

		It "returns false" {
			$result | Should be $false
		}
	}

	Context "when calling it with a rooted path" {
		$result = IsPathRooted -Path "C:\my\rooted\path"

		It "returns true" {
			$result | Should be $true
		}
	}
}

Describe "Root-Path" {
	Context "when calling it with a relative path and a parent" {
		$result = Root-Path -Parent "C:\root" -Path "my\relative\path"

		It "returns the path rooted to C:\root" {
			$result | Should be "C:\root\my\relative\path"
		}
	}

	Context "when calling it with a relative path and no parent path" {
		Mock Get-Location { return @{ Path = "C:\current\location" } }

		$result = Root-Path -Path "my\relative\path"

		It "returns the path rooted to the current location" {
			$result | Should be "C:\current\location\my\relative\path"
		}
	}

	Context "when calling it with a rooted path and a parent" {
		$result = Root-Path -Parent "C:\root" -Path "C:\my\rooted\path"

		It "returns the path unchanged" {
			$result | Should be "C:\my\rooted\path"
		}
	}
}

Describe "Compress-Files" {
	Context "when calling it with a full path to a file" {
		Setup -File "myFile.txt"
		Compress-Files -ZipPath "$TestDrive\test.zip" -Files "$TestDrive\myFile.txt"

		It "creates a zip file with myFile.txt inside" {
			$archive = [System.IO.Compression.ZipFile]::Open("$TestDrive\test.zip","Read")
			$actual = @{}
			$archive.Entries | % { $actual.Add($_.Name, $_.FullName) }
			$archive.Dispose()

			$expected = @{ "myFile.txt" = "myFile.txt" }

			$actual.Keys.Count | Should be $expected.Keys.Count
			$actual.Keys | % { $actual[$_] | Should be $expected[$_] }
		}
	}

	Context "when calling it with three files" {
		$files = "one.dll", "two.dll", "three.sln"
		$files | % { Setup -File $_ '' }

		Mock Get-Location { return @{ Path = $TestDrive } }
		Compress-Files -ZipPath "$TestDrive\test.zip" -Files $files

		It "creates a zip file with these three files inside" {
			$archive = [System.IO.Compression.ZipFile]::Open("$TestDrive\test.zip","Read")
			$actual = @{}
			$archive.Entries | % { $actual.Add($_.Name, $_.FullName) }
			$archive.Dispose()

			$expected = @{
				"one.dll" = "one.dll";
				"two.dll" = "two.dll";
				"three.sln" = "three.sln"
			}

			$actual.Keys.Count | Should be $expected.Keys.Count
			$actual.Keys | % { $actual[$_] | Should be $expected[$_] }
		}
	}

	Context "when calling it with a directory path" {
		$files = "myFolder\one.dll", "myFolder\two.dll", "myFolder\three.sln"
		$files | % { Setup -File $_ '' }

		Mock Get-Location { return @{ Path = $TestDrive } }
		Compress-Files -ZipPath "$TestDrive\test.zip" -Files "myFolder"

		It "creates a zip file with the folder" {
			$archive = [System.IO.Compression.ZipFile]::Open("$TestDrive\test.zip","Read")

			$actual = @{}
			$archive.Entries | % { $actual.Add($_.Name, $_.FullName) }
			$archive.Dispose()

			$expected = @{
				"one.dll" = "myFolder\one.dll";
				"two.dll" = "myFolder\two.dll";
				"three.sln" = "myFolder\three.sln"
			}

			$actual.Keys.Count | Should be $expected.Keys.Count
			$actual.Keys | % { $actual[$_] | Should be $expected[$_] }
		}
	}

	Context "when calling it with three files and a zip path that does not exists" {
		$files = "one.dll", "two.dll", "three.sln"
		$files | % { Setup -File $_ '' }

		Mock Get-Location { return @{ Path = $TestDrive } }
		Compress-Files -ZipPath "new\path\test.zip" -Files $files

		It "creates a zip file with these three files inside new\path\test.zip" {
			Test-Path "$TestDrive\new\path\test.zip" | Should be $true
			$archive = [System.IO.Compression.ZipFile]::Open("$TestDrive\new\path\test.zip","Read")
			$actual = @{}
			$archive.Entries | % { $actual.Add($_.Name, $_.FullName) }
			$archive.Dispose()

			$expected = @{
				"one.dll" = "one.dll";
				"two.dll" = "two.dll";
				"three.sln" = "three.sln"
			}

			$actual.Keys.Count | Should be $expected.Keys.Count
			$actual.Keys | % { $actual[$_] | Should be $expected[$_] }
		}
	}
}

Describe "Extract-File" {
	Context "when calling it with absolute paths" {
		Setup -File "myFile.txt"
		Setup -Dir "extracted"
		Compress-Files -ZipPath "$TestDrive\test.zip" -Files "$TestDrive\myFile.txt"

		Extract-File "$TestDrive\test.zip" "$TestDrive\extracted"

		It "puts the zip content inside the folder named extracted" {
			Test-Path "$TestDrive\extracted\myFile.txt" | Should be $true
		}
	}

	Context "when calling it with a relative path to the zip file" {
		Setup -File "myFile.txt"
		Setup -Dir "extracted"
		Compress-Files -ZipPath "$TestDrive\test.zip" -Files "$TestDrive\myFile.txt"
		Mock Get-Location { return @{ Path = "$TestDrive" } }

		Extract-File "test.zip" "$TestDrive\extracted"

		It "puts the zip content inside the folder named extracted" {
			Test-Path "$TestDrive\extracted\myFile.txt" | Should be $true
		}
	}

	Context "when calling it without the destination parameter" {
		Setup -File "myFile.txt"
		Compress-Files -ZipPath "$TestDrive\test.zip" -Files "$TestDrive\myFile.txt"
		Mock Get-Location { return @{ Path = $TestDrive } }

		Remove-Item "$TestDrive\myFile.txt"
		Extract-File "$TestDrive\test.zip"

		It "puts the zip content inside the current location" {
			Test-Path "$TestDrive\myFile.txt" | Should be $true
		}
	}

	Context "when calling it with a relative destination" {
		Setup -File "myFile.txt"
		Setup -Dir "extracted"
		Compress-Files -ZipPath "$TestDrive\test.zip" -Files "$TestDrive\myFile.txt"
		Mock Get-Location { return @{ Path = "$TestDrive" } }

		Extract-File "$TestDrive\test.zip" "extracted"

		It "puts the zip content inside the current location" {
			Test-Path "$TestDrive\myFile.txt" | Should be $true
		}
	}
}

Describe "Stringify-Config" {
	Context "when calling it with the config object" {
		$cfg = New-Object PSObject -Property @{
			"version" = "1.0.0.0"
		}

		It "returns the string 'version=1.0.0.0;" {
			Stringify $cfg | Should be "version=1.0.0.0;"
		}
	}
}