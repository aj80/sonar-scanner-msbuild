function runTests() {
    Write-Host "Start tests"
    $x = ""; Get-ChildItem -path . -Recurse -Include *Tests.dll | where { $_.FullName -match "bin" } | foreach { $x += """$_"" " }; iex "& '$env:VSTEST_PATH' /EnableCodeCoverage $x"
    testExitCode
}

#Copied from https://github.com/SonarSource/sonar-csharp/blob/master/scripts/utils.ps1
function Write-Header([string]$text) {
    Write-Host
    Write-Host "================================================"
    Write-Host $text
    Write-Host "================================================"
}


# Original: http://jameskovacs.com/2010/02/25/the-exec-problem
function Exec ([scriptblock]$command, [string]$errorMessage = "ERROR: Command '${command}' FAILED.") {
    Write-Debug "Invoking command:${command}"
    Write-Host "Invoking command:${command}"

    $output = ""
    & $command | Tee-Object -Variable output
    if ((-not $?) -or ($lastexitcode -ne 0)) {
        throw $errorMessage
    }

    return $output
}

function Get-ExecutablePath([string]$name, [string]$directory, [string]$envVar) {
    Write-Debug "Trying to find '${name}' using '${envVar}' environment variable"
    $path = [environment]::GetEnvironmentVariable($envVar, "Process")

    try {
        if (!$path) {
            Write-Debug "Environment variable not found"

            if (!$directory) {
                Write-Debug "Trying to find path using 'where.exe'"
                $path = Exec { & where.exe $name } | Select-Object -First 1
            }
            else {
                Write-Debug "Trying to find path using 'where.exe' in '${directory}'"
                $path = Exec { & where.exe /R $directory $name } | Select-Object -First 1
            }
        }
    }
    catch {
        throw "Failed to locate executable '${name}' on the path"
    }

    if (Test-Path $path) {
        Write-Debug "Found '${name}' at '${path}'"
        [environment]::SetEnvironmentVariable($envVar, $path)
        return $path
    }

    throw "'${name}' located at '${path}' doesn't exist"
}

# Coverage
# Copied from https://github.com/SonarSource/sonar-csharp/blob/master/scripts/build/build-utils.ps1
function Get-VsTestPath {
    return Get-ExecutablePath -name "VSTest.Console.exe" -envVar "VSTEST_PATH"
}

function Get-CodeCoveragePath {
    $vstest_exe = Get-VsTestPath
    $codeCoverageDirectory = Join-Path (Get-ChildItem $vstest_exe).Directory "..\..\..\..\.."
    return Get-ExecutablePath -name "CodeCoverage.exe" -directory $codeCoverageDirectory -envVar "CODE_COVERAGE_PATH"
}

# Coverage
function Invoke-CodeCoverage() {
    Write-Header "Creating coverage report"

    $codeCoverageExe = Get-CodeCoveragePath

    Write-Host "Generating code coverage reports for"
    Get-ChildItem "TestResults" -Recurse -Include "*.coverage" | ForEach-Object {
        Write-Host "    -" $_.FullName

        $filePathWithNewExtension = $_.FullName + "xml"
        if (Test-Path $filePathWithNewExtension) {
            Write-Debug "Coveragexml report already exists, removing it"
            Remove-Item -Force $filePathWithNewExtension
        }

        Exec { & "$codeCoverageExe" analyze /output:"$filePathWithNewExtension" "$_.FullName" `
        } -errorMessage "ERROR: Code coverage reports generation FAILED."


        Exec { & $codeCoverageExe analyze /output:$filePathWithNewExtension $_.FullName `
        } -errorMessage "ERROR: Code coverage reports generation FAILED."
    }
}