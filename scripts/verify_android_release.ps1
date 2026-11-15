<#
.SYNOPSIS
Verifies an existing Flutter release APK without rebuilding or changing its key.
.EXAMPLE
powershell -NoProfile -File scripts/verify_android_release.ps1
.EXAMPLE
powershell -NoProfile -File scripts/verify_android_release.ps1 -VerificationDate 2026-11-16
.NOTES
Reads android/key.properties locally. The keystore password is passed to keytool
through a temporary process environment variable, never a command-line argument.
The JSON report contains public certificate fingerprints and APK metadata only.
For builds with version overrides, pass -ExpectedVersionName/-ExpectedVersionCode.
#>
[CmdletBinding()]
param(
    [string]$ApkPath = 'build/app/outputs/flutter-apk/app-release.apk',
    [string]$ReportPath = 'build/reports/android-release-verification.json',
    [string]$ExpectedApplicationId = 'id.santiagobernabeu.booking',
    [string]$ExpectedVersionName,
    [string]$ExpectedVersionCode,
    [string]$AndroidSdkPath,
    [string]$JavaHomePath,
    [datetime]$VerificationDate = (Get-Date)
)

$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$checks = [System.Collections.Generic.List[object]]::new()
$stage = 'APK input'
$report = [ordered]@{
    verificationDate = $VerificationDate.ToString('yyyy-MM-dd')
    hostRecordedAtUtc = [DateTime]::UtcNow.ToString('o')
    passed = $false
    checks = $checks
}

function Resolve-ProjectPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $projectDirectory $Path))
}

function ConvertFrom-PropertyEscape([string]$Value) {
    return [regex]::Replace($Value, '\\(u[0-9a-fA-F]{4}|.)', {
        param($match)
        $escape = $match.Groups[1].Value
        switch -CaseSensitive ($escape) {
            't' { return "`t" }
            'r' { return "`r" }
            'n' { return "`n" }
            'f' { return "`f" }
        }
        if ($escape -match '^u[0-9a-fA-F]{4}$') {
            return [string][char][Convert]::ToInt32($escape.Substring(1), 16)
        }
        return $escape
    })
}

# Match Java Properties escaping; never print the signing properties.
function Read-JavaProperties([string]$Path) {
    $properties = @{}
    $logicalLine = ''
    foreach ($physicalLine in [IO.File]::ReadAllLines($Path, [Text.Encoding]::GetEncoding(28591))) {
        $line = $physicalLine.TrimStart()
        if (!$logicalLine -and ($line.Length -eq 0 -or $line.StartsWith('#') -or $line.StartsWith('!'))) {
            continue
        }
        $logicalLine += $line
        $trailingSlashes = [regex]::Match($logicalLine, '\\+$').Length
        if (($trailingSlashes % 2) -eq 1) {
            $logicalLine = $logicalLine.Substring(0, $logicalLine.Length - 1)
            continue
        }
        if ($logicalLine -match '^((?:\\.|[^=:\s])+)(?:\s*[=:]\s*|\s+)(.*)$') {
            $properties[(ConvertFrom-PropertyEscape $Matches[1])] = ConvertFrom-PropertyEscape $Matches[2]
        }
        $logicalLine = ''
    }
    if ($logicalLine) { throw 'Signing properties contain an incomplete continuation.' }
    return $properties
}

function Invoke-AndroidTool([string]$Tool, [string[]]$ToolArguments, [string]$Label) {
    $previousPreference = $ErrorActionPreference
    try {
        # Some successful Java tools write informational lines to stderr.
        $ErrorActionPreference = 'Continue'
        $result = & $Tool @ToolArguments 2>&1
        $toolExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($toolExitCode -ne 0) { throw "$Label failed (exit $toolExitCode)." }
    return ($result | ForEach-Object { $_.ToString() }) -join "`n"
}

function Add-Check([string]$Name, [bool]$Passed) {
    $checks.Add([ordered]@{ name = $Name; passed = $Passed })
}

function Get-Sha256([byte[]]$Bytes) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
}

try {
    $resolvedApk = Resolve-ProjectPath $ApkPath
    if (!(Test-Path -LiteralPath $resolvedApk -PathType Leaf)) { throw 'Release APK not found. Build it before running verification.' }
    $report.apk = [ordered]@{
        path = $resolvedApk
        bytes = (Get-Item -LiteralPath $resolvedApk).Length
        sha256 = (Get-FileHash -LiteralPath $resolvedApk -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    $stage = 'Expected release version'
    if (!$ExpectedVersionName -or !$ExpectedVersionCode) {
        $pubspec = [IO.File]::ReadAllText((Join-Path $projectDirectory 'pubspec.yaml'))
        if ($pubspec -notmatch '(?m)^version:\s*([^\s+]+)\+(\d+)\s*$') { throw 'Cannot read the expected version from pubspec.yaml.' }
        if (!$ExpectedVersionName) { $ExpectedVersionName = $Matches[1] }
        if (!$ExpectedVersionCode) { $ExpectedVersionCode = $Matches[2] }
    }

    $stage = 'Android SDK and JDK tools'
    if (!$AndroidSdkPath) {
        $localProperties = Join-Path $projectDirectory 'android/local.properties'
        if (Test-Path -LiteralPath $localProperties) {
            $AndroidSdkPath = (Read-JavaProperties $localProperties)['sdk.dir']
        }
        if (!$AndroidSdkPath) { $AndroidSdkPath = $env:ANDROID_SDK_ROOT }
        if (!$AndroidSdkPath) { $AndroidSdkPath = $env:ANDROID_HOME }
        if (!$AndroidSdkPath -and $env:LOCALAPPDATA) { $AndroidSdkPath = Join-Path $env:LOCALAPPDATA 'Android/sdk' }
    }
    if (!$AndroidSdkPath -or !(Test-Path -LiteralPath $AndroidSdkPath)) { throw 'Android SDK was not found. Supply -AndroidSdkPath.' }
    $buildTools = Get-ChildItem -LiteralPath (Join-Path $AndroidSdkPath 'build-tools') -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending |
        Where-Object { (Test-Path -LiteralPath (Join-Path $_.FullName 'aapt.exe')) -and (Test-Path -LiteralPath (Join-Path $_.FullName 'apksigner.bat')) } |
        Select-Object -First 1
    if (!$buildTools) { throw 'Android build-tools containing aapt and apksigner were not found.' }

    if (!$JavaHomePath) { $JavaHomePath = $env:JAVA_HOME }
    if (!$JavaHomePath -and $env:ProgramFiles) {
        $studioJbr = Join-Path $env:ProgramFiles 'Android/Android Studio/jbr'
        if (Test-Path -LiteralPath (Join-Path $studioJbr 'bin/keytool.exe')) { $JavaHomePath = $studioJbr }
    }
    $keytool = if ($JavaHomePath) { Join-Path $JavaHomePath 'bin/keytool.exe' } else { (Get-Command keytool -ErrorAction Stop).Source }
    if (!(Test-Path -LiteralPath $keytool)) { throw 'JDK keytool was not found. Supply -JavaHomePath.' }
    $report.tools = [ordered]@{ androidBuildTools = $buildTools.Name }

    $stage = 'Android manifest'
    $aapt = Join-Path $buildTools.FullName 'aapt.exe'
    $badging = Invoke-AndroidTool $aapt @('dump', 'badging', $resolvedApk) 'Android manifest inspection'
    if ($badging -notmatch "(?m)^package: name='([^']+)' versionCode='([^']+)' versionName='([^']*)'") { throw 'Android manifest identity could not be read.' }
    $applicationId, $versionCode, $versionName = $Matches[1], $Matches[2], $Matches[3]
    $debuggable = $badging -match '(?m)^application-debuggable\s*$'
    $permissions = Invoke-AndroidTool $aapt @('dump', 'permissions', $resolvedApk) 'Android permission inspection'
    $hasInternet = $permissions -match "(?m)^uses-permission:\s+name='android\.permission\.INTERNET'(?:\s|$)"
    $report.manifest = [ordered]@{
        applicationId = $applicationId
        versionCode = $versionCode
        versionName = $versionName
        debuggable = $debuggable
        internetPermission = $hasInternet
    }
    Add-Check 'applicationId matches expected release' ($applicationId -eq $ExpectedApplicationId)
    Add-Check 'versionName matches expected release' ($versionName -eq $ExpectedVersionName)
    Add-Check 'versionCode matches expected release' ($versionCode -eq $ExpectedVersionCode)
    Add-Check 'manifest is not debuggable' (!$debuggable)
    Add-Check 'INTERNET permission is declared' $hasInternet

    $stage = 'Flutter release contents'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($resolvedApk)
    try {
        $appLibraries = @($archive.Entries | Where-Object { $_.FullName -match '^lib/[^/]+/libapp\.so$' -and $_.Length -gt 0 })
        $kernelEntries = @($archive.Entries | Where-Object { $_.FullName -match '(^|/)kernel_blob\.bin$' })
        $noticeEntries = @($archive.Entries | Where-Object { $_.FullName -match '^assets/flutter_assets/NOTICES(?:\.Z)?$' -and $_.Length -gt 0 })
        Add-Check 'compiled libapp.so is present' ($appLibraries.Count -gt 0)
        Add-Check 'debug kernel_blob.bin is absent' ($kernelEntries.Count -eq 0)
        Add-Check 'Flutter dependency license notices are bundled' ($noticeEntries.Count -gt 0)
        $report.flutter = [ordered]@{ appLibraries = @($appLibraries.FullName); kernelBlobPresent = $kernelEntries.Count -gt 0; licenseNotices = @($noticeEntries.FullName) }

        $stage = 'Bundled public configuration'
        $configEntry = $archive.GetEntry('assets/flutter_assets/config/supabase.public.json')
        $configValid = $false
        if ($configEntry) {
            $reader = [IO.StreamReader]::new($configEntry.Open())
            try { $config = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
            $fieldNames = @($config.PSObject.Properties.Name)
            $fieldsValid = $fieldNames.Count -eq 2 -and $fieldNames -contains 'SUPABASE_URL' -and $fieldNames -contains 'SUPABASE_PUBLISHABLE_KEY'
            $url = $config.SUPABASE_URL
            $publicKey = $config.SUPABASE_PUBLISHABLE_KEY
            $parsedUrl = $null
            $urlValid = $url -is [string] -and [Uri]::TryCreate($url, [UriKind]::Absolute, [ref]$parsedUrl) -and $parsedUrl.Scheme -eq 'https' -and $parsedUrl.Host -and !$parsedUrl.UserInfo -and !$parsedUrl.Query -and !$parsedUrl.Fragment -and $parsedUrl.AbsolutePath -eq '/'
            $keyValid = $publicKey -is [string] -and $publicKey -cmatch '^sb_publishable_[A-Za-z0-9_-]+$'
            $configValid = $fieldsValid -and $urlValid -and $keyValid
        }
        Add-Check 'bundled public config has exactly URL and valid publishable key' $configValid
        $report.publicConfiguration = [ordered]@{ bundled = $null -ne $configEntry; valid = $configValid; validation = 'Offline URL/key structure; no backend request' }
    } finally { $archive.Dispose() }

    $stage = 'APK signature'
    $previousJavaHome = $env:JAVA_HOME
    try {
        if ($JavaHomePath) { $env:JAVA_HOME = $JavaHomePath }
        $signature = Invoke-AndroidTool (Join-Path $buildTools.FullName 'apksigner.bat') @('verify', '--verbose', '--print-certs', $resolvedApk) 'APK signature verification'
    } finally { $env:JAVA_HOME = $previousJavaHome }
    $signerMatches = [regex]::Matches($signature, '(?m)^Signer #\d+ certificate SHA-256 digest:\s*([0-9a-fA-F:]+)\s*$')
    $signerFingerprints = @($signerMatches | ForEach-Object { $_.Groups[1].Value.Replace(':', '').ToLowerInvariant() })
    Add-Check 'APK has exactly one verified signer' ($signerFingerprints.Count -eq 1)

    $stage = 'Existing upload keystore certificate'
    $signingPath = Join-Path $projectDirectory 'android/key.properties'
    if (!(Test-Path -LiteralPath $signingPath)) { throw 'android/key.properties is required to compare the existing signing certificate.' }
    $signing = Read-JavaProperties $signingPath
    foreach ($property in @('storeFile', 'storePassword', 'keyAlias')) {
        if ([string]::IsNullOrWhiteSpace($signing[$property])) { throw 'Required local signing properties are missing.' }
    }
    $keystorePath = $signing['storeFile']
    if (![IO.Path]::IsPathRooted($keystorePath)) { $keystorePath = Join-Path (Join-Path $projectDirectory 'android') $keystorePath }
    if (!(Test-Path -LiteralPath $keystorePath -PathType Leaf)) { throw 'The existing release keystore was not found.' }

    $previousPassword = [Environment]::GetEnvironmentVariable('SANTIAGO_RELEASE_KEYSTORE_PASSWORD', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('SANTIAGO_RELEASE_KEYSTORE_PASSWORD', $signing['storePassword'], 'Process')
        $certificate = Invoke-AndroidTool $keytool @('-exportcert', '-rfc', '-keystore', $keystorePath, '-alias', $signing['keyAlias'], '-storepass:env', 'SANTIAGO_RELEASE_KEYSTORE_PASSWORD') 'Existing signing certificate inspection'
    } finally {
        [Environment]::SetEnvironmentVariable('SANTIAGO_RELEASE_KEYSTORE_PASSWORD', $previousPassword, 'Process')
        $signing.Clear()
    }
    if ($certificate -notmatch '(?s)-----BEGIN CERTIFICATE-----\s*(.*?)\s*-----END CERTIFICATE-----') { throw 'The existing keystore certificate could not be exported.' }
    $expectedFingerprint = Get-Sha256 ([Convert]::FromBase64String(($Matches[1] -replace '\s', '')))
    $signerMatchesKeystore = $signerFingerprints.Count -eq 1 -and $signerFingerprints[0] -eq $expectedFingerprint
    Add-Check 'APK signer matches the existing upload keystore certificate' $signerMatchesKeystore
    $report.signing = [ordered]@{
        verified = $true
        signerCertificateSha256 = $signerFingerprints
        existingKeystoreCertificateSha256 = $expectedFingerprint
        matchesExistingKeystore = $signerMatchesKeystore
    }
    $report.passed = @($checks | Where-Object { !$_.passed }).Count -eq 0
} catch {
    # Avoid recording native tool output or credential/configuration contents.
    $report.error = "$stage could not be verified. Tool output and configuration contents are omitted."
} finally {
    $resolvedReport = Resolve-ProjectPath $ReportPath
    $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $resolvedReport))
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedReport -Encoding UTF8
}

if (!$report.passed) { throw "Android release verification failed. See $resolvedReport" }
Write-Output "Android release verification passed. Report: $resolvedReport"
