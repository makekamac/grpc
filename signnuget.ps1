# Signs a nuget and authenticode signs all .dll files contained in it.
# Usage: powershell -File signnuget.ps1 -nugetfile NUGET_PACKAGE_TO_SIGN
param (
   [Parameter(Mandatory=$true)][string]$nugetfile
)
$ErrorActionPreference = "Stop"  # Exit early on errors

$extractedPath = "$nugetfile.extracted"
$signedNuget = "$nugetfile.signed"

# paths to tooling
$signtoolExe = "c:\Program Files (x86)\Windows kits\10\bin\x86\signtool.exe"
# TODO(jtattermusch): set correct path for nuget.ext (must be version >4.6)
$nugetExe = "T:\src\git\grpc\nuget.exe"

Add-Type -Assembly 'System.IO.Compression.FileSystem';

# Extract the nupkg (it's just a zipfile)
Write-Host "extracting $nugetfile"
[System.IO.Compression.ZipFile]::ExtractToDirectory($nugetfile, $extractedPath);

# Add authenticode signature for each dll
Get-ChildItem -Path $extractedPath -Include '*.dll' -Recurse | ForEach-Object {
   Write-Host "authenticode signing $_"
   & "$signtoolExe" sign /v /tr http://timestamp.digicert.com /i SHA2 /fd sha256 /td sha256 "$_"
   if ($LastExitCode -ne 0) { throw "Command returned exit code $LastExitCode" }
}

# Pack the nupkg again (some files are now authenticode-signed)
Write-Host "packaging $extractedPath"
[System.IO.Compression.ZipFile]::CreateFromDirectory($extractedPath, $signedNuget);

Write-Host "signing $signedNuget"

# Sign the resulting nuget package itself
& "$nugetExe" sign "$signedNuget" -CertificateSubjectName "Google LLC" -Verbosity detailed -Overwrite -Timestamper http://timestamp.digicert.com
if ($LastExitCode -ne 0) { throw "Command returned exit code $LastExitCode" }

Write-Host "Successfully signed $signedNuget"
