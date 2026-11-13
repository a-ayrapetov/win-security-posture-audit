Describe 'Audit-NewPC read-only claim' {
    BeforeAll {
        $blockedVerbs = @('Set', 'Remove', 'Stop', 'Disable', 'Restart', 'Uninstall', 'Clear', 'Format', 'Reset', 'Enable')
        $allowedCommands = @{
            # Formats report data without changing system state.
            'Format-Table' = $true
            # Formats report data without changing system state.
            'Format-List' = $true
            # Closes the transcript after writing the audit log.
            'Stop-Transcript' = $true
        }
        $scriptPath = (Resolve-Path (Join-Path (Get-Location).Path 'Audit-NewPC.ps1')).Path

        function Get-ReadOnlyViolations {
            param([Parameter(Mandatory)][string]$Path)

            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $Path,
                [ref]$tokens,
                [ref]$parseErrors
            )
            if ($parseErrors) {
                throw "Could not parse '$Path': $($parseErrors -join '; ')"
            }

            $ast.FindAll({
                param($node)

                if ($node -isnot [System.Management.Automation.Language.CommandAst]) {
                    return $false
                }

                $commandName = $node.GetCommandName()
                if (-not $commandName) {
                    return $false
                }

                $verb = ($commandName -split '-', 2)[0]
                return $blockedVerbs -contains $verb -and -not $allowedCommands.ContainsKey($commandName)
            }, $true) | ForEach-Object {
                $_.GetCommandName()
            }
        }
    }

    It 'parses without errors' {
        { Get-ReadOnlyViolations -Path $scriptPath } | Should -Not -Throw
    }

    It 'does not call state-changing commands' {
        $violations = @(Get-ReadOnlyViolations -Path $scriptPath)
        $violations | Should -BeNullOrEmpty
    }

    It 'reports every prohibited command in another script' {
        $tempScript = New-TemporaryFile
        try {
            @'
Set-ItemProperty -Path HKCU:\Software\Example -Name X -Value 1
Remove-Item C:\Example
'@ | Set-Content -LiteralPath $tempScript.FullName

            $violations = @(Get-ReadOnlyViolations -Path $tempScript.FullName)
            $violations | Should -Be @('Set-ItemProperty', 'Remove-Item')
        }
        finally {
            Remove-Item -LiteralPath $tempScript.FullName -Force
        }
    }
}
