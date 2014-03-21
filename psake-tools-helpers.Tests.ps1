function Get-ConfigSample(){
	'{	
		"solution": "MySolution.sln",
		"projectToPublish": "MyProject.csproj",
		"configuration": "Release",
    	"platform": "Any CPU",    
    	"major": "2",
    	"minor": "1" 
	}'
}

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
			$config.projectToPublish | Should Be "MyProject.csproj"
		}
	}
}

Describe "Get-NewestFilePath" {
	$folder = 'packages\Some.Library.Name'
	$library = 'Some.Library.Name.dll'
	
	Setup -File "$folder.0.0.0.121\$library" ''
	Setup -File "$folder.0.0.2.1\$library" ''
  	Setup -File "$folder.3.0.0.50\$library" ''
	
	Context "When calling it with the path that cointains those libraries" {
		$p = Get-NewestFilePath $TestDrive $library
		 It "should get the newest one" {
		 	$p | Should Be "$TestDrive\$folder.3.0.0.50\$library"	
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

Describe "Update-AssemblyInfo" {	
	$f1 = "a\AssemblyInfo.cs"
	$f2 = "a\b.c\AssemblyInfo.cs"
	$f3 = "a\b-c\d\AssemblyInfo.cs"
	
	Setup -File $f1 (Get-AssemblySample)
	Setup -File $f2 (Get-AssemblySample)
  	Setup -File $f3 (Get-AssemblySample)
	
	$version = "0.1.2.3"
	
	Context "When calling it in a path that cointains those files" {
		Update-AssemblyInfo $TestDrive
		 It "should update the version values for the three files" {		 	
			(Get-Content $TestDrive\$f1) | Should Be (Get-AssemblySampleWithNewVersion $version)
		 }
	}
}

Describe "Get-BuildCommand" {
	$config = Setup-Object
	
	Context "When calling it" {		
		It "should return the msbuild command with the values from the configuration file" {		
			Get-BuildCommand | Should Be "msbuild MySolution.sln -t:Build -p:Configuration=Release `"-p:Platform=Any CPU`""
		}
	}
}

Describe "Get-CleanCommand" {
	$config = Setup-Object
	
	Context "When calling it" {		
		It "should return the msbuild command with the values from the configuration file" {		
			Get-CleanCommand | Should Be "msbuild MySolution.sln -t:Clean -p:Configuration=Release `"-p:Platform=Any CPU`""
		}
	}
}

Describe "Get-PublishCommand" {
	$config = Setup-Object
	
	Context "When calling it" {		
		It "should return the msbuild command with the values from the configuration file" {		
			Get-PublishCommand | Should Be "msbuild MyProject.csproj -t:Publish -p:Configuration=Release `"-p:Platform=Any CPU`""			
		}
	}
}