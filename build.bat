set version=1.0.0.

Powershell.exe -noprofile -executionpolicy Bypass -file ./GetNuget.ps1 

del *.nupkg
.nuget\nuget.exe pack  VersionOne.Build.Common.nuspec -Verbosity Detailed -Version %version%%BUILD_NUMBER%