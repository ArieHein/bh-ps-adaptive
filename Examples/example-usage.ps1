# example-usage.ps1
# Demonstrates the three public functions of the PSAdaptiveCards module.
# Run this script from the repository root:
#
#   pwsh -File .\Examples\example-usage.ps1
#
# Note: Invoke-AdaptiveCardUI requires Windows (WinForms).

# ----------------------------------------------------------
# 0. Import the module
# ----------------------------------------------------------
$modulePath = Join-Path $PSScriptRoot '..\PSAdaptiveCards\PSAdaptiveCards.psd1'
Import-Module $modulePath -Force

$sampleForm   = Join-Path $PSScriptRoot 'sample-form.json'
$sampleDeploy = Join-Path $PSScriptRoot 'sample-deploy.json'

# ----------------------------------------------------------
# 1. ConvertFrom-AdaptiveCard  – parse without showing UI
# ----------------------------------------------------------
Write-Host "`n=== ConvertFrom-AdaptiveCard ===" -ForegroundColor Cyan
$meta = ConvertFrom-AdaptiveCard -Path $sampleForm
Write-Host "Title   : $($meta.Title)"
Write-Host "Version : $($meta.Version)"
Write-Host "Inputs  :"
$meta.Inputs | Format-Table Id, Type, Label, IsRequired -AutoSize

# ----------------------------------------------------------
# 2. Invoke-AdaptiveCardUI  – show form, collect values
# ----------------------------------------------------------
if ($IsWindows) {
    Write-Host "`n=== Invoke-AdaptiveCardUI (sample-form.json) ===" -ForegroundColor Cyan
    Write-Host "A dialog will appear. Fill in the fields and click Register."
    $values = Invoke-AdaptiveCardUI -Path $sampleForm
    if ($values) {
        Write-Host "`nSubmitted values:"
        $values | ConvertTo-Json -Depth 5
    }
    else {
        Write-Host "User cancelled the form."
    }

    Write-Host "`n=== Invoke-AdaptiveCardUI (sample-deploy.json) ===" -ForegroundColor Cyan
    $deployValues = Invoke-AdaptiveCardUI -Path $sampleDeploy
    if ($deployValues) {
        Write-Host "`nDeploy parameters:"
        $deployValues | ConvertTo-Json -Depth 5
    }
}
else {
    Write-Warning 'Skipping Invoke-AdaptiveCardUI – requires Windows.'
}

# ----------------------------------------------------------
# 3. Start-AdaptiveCardMCPServer  – quick smoke test via stdin
# ----------------------------------------------------------
Write-Host "`n=== MCP Server quick smoke test ===" -ForegroundColor Cyan
Write-Host "Sending initialize + tools/list + validate_card through a pipe..."

$initRequest  = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"example","version":"1.0"}}}'
$listRequest  = '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
$validateReq  = '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"validate_card","arguments":{"card_json":"{\"type\":\"AdaptiveCard\",\"version\":\"1.5\",\"body\":[]}"}}}'

$input = @($initRequest, $listRequest, $validateReq) -join "`n"

$output = $input | pwsh -NoProfile -NonInteractive -Command {
    $modulePath = Join-Path $args[0] '..\PSAdaptiveCards\PSAdaptiveCards.psd1'
    Import-Module $modulePath -Force
    Start-AdaptiveCardMCPServer
} -args $PSScriptRoot 2>$null

$output | ForEach-Object {
    if ($_) {
        $parsed = $_ | ConvertFrom-Json
        Write-Host "Response id=$($parsed.id): $($_ | ConvertFrom-Json | Select-Object -ExpandProperty result | ConvertTo-Json -Depth 3 -Compress)"
    }
}

Write-Host "`nDone." -ForegroundColor Green
