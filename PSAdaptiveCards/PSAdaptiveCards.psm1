# PSAdaptiveCards.psm1 - Module root script
# Dot-sources all private helpers and public exported functions.

$Private = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
$Public  = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1"  -ErrorAction SilentlyContinue

foreach ($file in ($Private + $Public)) {
    try {
        . $file.FullName
    }
    catch {
        Write-Error "Failed to import '$($file.FullName)': $_"
    }
}

Export-ModuleMember -Function $Public.BaseName
