@{
    ModuleVersion     = '1.0.0'
    GUID              = 'a8f2c347-1e5b-4d89-b3c6-7f92e10d45a3'
    Author            = 'ArieHein'
    CompanyName       = 'BlackHat'
    Copyright         = '(c) 2026 ArieHein. All rights reserved.'
    Description       = 'PowerShell module that generates a Windows Forms UI from an Adaptive Cards JSON structure and hosts a local MCP server so AI assistants can drive form collection.'
    PowerShellVersion = '7.5'
    RootModule        = 'PSAdaptiveCards.psm1'

    FunctionsToExport = @(
        'ConvertFrom-AdaptiveCard'
        'Invoke-AdaptiveCardUI'
        'Start-AdaptiveCardMCPServer'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('AdaptiveCards', 'UI', 'WinForms', 'MCP', 'ModelContextProtocol', 'Forms', 'JSON')
            ProjectUri   = 'https://github.com/ArieHein/bh-ps-adaptive'
            ReleaseNotes = 'Initial release: WinForms UI renderer and stdio MCP server.'
        }
    }
}
