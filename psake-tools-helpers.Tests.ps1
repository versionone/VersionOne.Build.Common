function Get-ConfigSample(){
	'{	
		"solution": "MySolution.sln",
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



Describe "When reading the configuration file" {		
	$config = Setup-Object
	It "should return an object with the proper values" {
		$config.solution | Should Be "MySolution.sln"
		$config.configuration | Should Be "Release"
		$config.platform | Should Be "Any CPU"
		$config.major | Should Be "2"
		$config.minor | Should Be "1"
	}
}

Describe "When calling Get-BuildCommand" {
	$config = Setup-Object
	It "should return the msbuild command with the values from the configuration file" {		
		Get-BuildCommand | Should Be "msbuild MySolution.sln -t:Build -p:Configuration=Release `"-p:Platform=Any CPU`""
	}
}
