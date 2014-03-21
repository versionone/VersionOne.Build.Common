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

function Setup-Object(){
	Setup -File 'build.properties.json' (Get-ConfigSample)
	Get-ConfigObjectFromFile "$TestDrive\build.properties.json"
} 

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

."$here\psake-tools-helpers.ps1"


Describe "psake-tools-helpers hasn't been initialized" {
	Context "When reading the configuration file with Get-ConfigObjectFromFile" {
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

Describe "There are three files with different version" {
	$folder = 'packages\Some.Library.Name'
	$library = 'Some.Library.Name.dll'
	
	Setup -File "$folder.0.0.0.121\$library" ''
	Setup -File "$folder.0.0.2.1\$library" ''
  	Setup -File "$folder.3.0.0.50\$library" ''
	
	Context "When calling Get-NewestFilePath" {
		$p = Get-NewestFilePath $TestDrive $library
		 It "should get the newest one" {
		 	$p | Should Be "$TestDrive\$folder.3.0.0.50\$library"	
		 }
	}
}

Describe "I am at the current folder location" {	
	Mock Get-Location -MockWith { return @{ Path = "$TestDrive"; } }	
	
	Context "When calling New-NugetDirectory" {
		New-NugetDirectory
		 It "should create the nuget folder" {		 	
		 	Test-Path "$TestDrive\.nuget" | Should Be $true
		 }
	}
}

Describe "The helper is initialized with the values from the configuration file" {
	$config = Setup-Object
	
	Context "When calling Get-BuildCommand" {		
		It "should return the msbuild command with the values from the configuration file" {		
			Get-BuildCommand | Should Be "msbuild MySolution.sln -t:Build -p:Configuration=Release `"-p:Platform=Any CPU`""
		}
	}
	
	Context "When calling Get-CleanCommand" {		
		It "should return the msbuild command with the values from the configuration file" {		
			Get-CleanCommand | Should Be "msbuild MySolution.sln -t:Clean -p:Configuration=Release `"-p:Platform=Any CPU`""
		}
	}
	
	Context "When calling Get-PublishCommand" {		
		It "should return the msbuild command with the values from the configuration file" {		
			Get-PublishCommand | Should Be "msbuild MyProject.csproj -t:Publish -p:Configuration=Release `"-p:Platform=Any CPU`""			
		}
	}
}