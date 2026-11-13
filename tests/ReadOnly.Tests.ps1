$blockedVerbs = @('Set', 'Remove', 'Stop', 'Disable', 'Restart', 'Uninstall', 'Clear', 'Format', 'Reset', 'Enable')
$allowedCommands = @{
    # Formats report data without changing system state.
    'Format-Table' = $true
    # Formats report data without changing system state.
    'Format-List' = $true
    # Closes the transcript after writing the audit log.
    'Stop-Transcript' = $true
}

Describe 'Audit-NewPC read-only claim' {
    BeforeAll {
        $scriptPath = (Resolve-Path (Join-Path (Get-Location).Path 'Audit-NewPC.ps1')).Path
        $tokens = $null
        $parseErrors = $null
        $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath,
            [ref]$tokens,
            [ref]$parseErrors
        )
    }

    It 'parses without errors' {
        $parseErrors | Should -BeNullOrEmpty
    }

    It 'does not call state-changing commands' {
        $violations = $scriptAst.FindAll({
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
            '{0} (line {1})' -f $_.GetCommandName(), $_.Extent.StartLineNumber
        }

        $violations | Should -BeNullOrEmpty
    }
}
