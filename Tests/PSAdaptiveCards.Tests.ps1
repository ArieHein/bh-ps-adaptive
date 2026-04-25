#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Pester tests for the PSAdaptiveCards module.
    Tests focus on the non-UI functions (ConvertFrom-AdaptiveCard, card parsing
    helpers, MCP server protocol) so they can run on any platform without
    requiring Windows.Forms.
#>

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\PSAdaptiveCards\PSAdaptiveCards.psd1'
    Import-Module $modulePath -Force

    # ---- Shared test JSON payloads -----------------------------------------
    $script:MinimalCard = @'
{
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "type": "AdaptiveCard",
  "version": "1.5",
  "body": []
}
'@

    $script:FullCard = @'
{
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "type": "AdaptiveCard",
  "version": "1.5",
  "title": "Test Card",
  "body": [
    { "type": "TextBlock", "text": "Hello", "id": "tb1" },
    { "type": "Input.Text",   "id": "name",    "label": "Name",   "isRequired": true, "placeholder": "Enter name" },
    { "type": "Input.Number", "id": "age",     "label": "Age",    "min": 1, "max": 120, "value": 25 },
    { "type": "Input.Date",   "id": "dob",     "label": "DOB",    "value": "2000-01-01" },
    { "type": "Input.Time",   "id": "alarm",   "label": "Alarm",  "value": "07:30" },
    { "type": "Input.Toggle", "id": "active",  "title": "Active", "value": "true" },
    {
      "type": "Input.ChoiceSet",
      "id": "role",
      "label": "Role",
      "style": "compact",
      "choices": [
        { "title": "Admin", "value": "admin" },
        { "title": "User",  "value": "user"  }
      ],
      "value": "user"
    },
    {
      "type": "Input.ChoiceSet",
      "id": "skills",
      "label": "Skills",
      "style": "expanded",
      "isMultiSelect": true,
      "choices": [
        { "title": "PowerShell", "value": "ps" },
        { "title": "Python",     "value": "py" }
      ]
    }
  ],
  "actions": [
    { "type": "Action.Submit",  "title": "Save" },
    { "type": "Action.OpenUrl", "title": "Docs", "url": "https://adaptivecards.io" }
  ]
}
'@

    $script:ContainerCard = @'
{
  "type": "AdaptiveCard",
  "version": "1.5",
  "body": [
    {
      "type": "Container",
      "id": "c1",
      "items": [
        { "type": "Input.Text", "id": "nested1", "label": "Nested 1" },
        {
          "type": "ColumnSet",
          "columns": [
            {
              "type": "Column",
              "items": [ { "type": "Input.Text", "id": "col1", "label": "Col 1" } ]
            },
            {
              "type": "Column",
              "items": [ { "type": "Input.Text", "id": "col2", "label": "Col 2" } ]
            }
          ]
        }
      ]
    }
  ]
}
'@
}

# ============================================================
# ConvertFrom-AdaptiveCard
# ============================================================
Describe 'ConvertFrom-AdaptiveCard' {

    Context 'Minimal card' {
        It 'Returns a PSCustomObject' {
            $result = ConvertFrom-AdaptiveCard -Json $script:MinimalCard
            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Sets Type = AdaptiveCard' {
            $result = ConvertFrom-AdaptiveCard -Json $script:MinimalCard
            $result.Type | Should -Be 'AdaptiveCard'
        }

        It 'Sets Version correctly' {
            $result = ConvertFrom-AdaptiveCard -Json $script:MinimalCard
            $result.Version | Should -Be '1.5'
        }

        It 'Returns empty Inputs array for a card with no inputs' {
            $result = ConvertFrom-AdaptiveCard -Json $script:MinimalCard
            $result.Inputs | Should -BeNullOrEmpty
        }
    }

    Context 'Full card with all input types' {
        BeforeAll {
            $script:Meta = ConvertFrom-AdaptiveCard -Json $script:FullCard
        }

        It 'Extracts the card title' {
            $script:Meta.Title | Should -Be 'Test Card'
        }

        It 'Finds all 7 input fields' {
            $script:Meta.Inputs.Count | Should -Be 7
        }

        It 'Correctly maps Input.Text field' {
            $f = $script:Meta.Inputs | Where-Object { $_.Id -eq 'name' }
            $f | Should -Not -BeNullOrEmpty
            $f.Type       | Should -Be 'Input.Text'
            $f.Label      | Should -Be 'Name'
            $f.IsRequired | Should -BeTrue
        }

        It 'Correctly maps Input.Number field' {
            $f = $script:Meta.Inputs | Where-Object { $_.Id -eq 'age' }
            $f.Type | Should -Be 'Input.Number'
            $f.Min  | Should -Be 1
            $f.Max  | Should -Be 120
            $f.DefaultValue | Should -Be 25
        }

        It 'Correctly maps Input.Date field' {
            $f = $script:Meta.Inputs | Where-Object { $_.Id -eq 'dob' }
            $f.Type         | Should -Be 'Input.Date'
            $f.DefaultValue | Should -Be '2000-01-01'
        }

        It 'Correctly maps Input.Time field' {
            $f = $script:Meta.Inputs | Where-Object { $_.Id -eq 'alarm' }
            $f.Type | Should -Be 'Input.Time'
        }

        It 'Correctly maps Input.Toggle field' {
            $f = $script:Meta.Inputs | Where-Object { $_.Id -eq 'active' }
            $f.Type | Should -Be 'Input.Toggle'
        }

        It 'Correctly maps compact ChoiceSet field with choices' {
            $f = $script:Meta.Inputs | Where-Object { $_.Id -eq 'role' }
            $f.Type         | Should -Be 'Input.ChoiceSet'
            $f.Style        | Should -Be 'compact'
            $f.Choices.Count | Should -Be 2
            $f.Choices[0].Value | Should -Be 'admin'
        }

        It 'Correctly maps multi-select ChoiceSet field' {
            $f = $script:Meta.Inputs | Where-Object { $_.Id -eq 'skills' }
            $f.IsMultiSelect | Should -BeTrue
        }

        It 'Extracts both actions' {
            $script:Meta.Actions.Count | Should -Be 2
        }

        It 'Correctly identifies Action.Submit' {
            $a = $script:Meta.Actions | Where-Object { $_.Type -eq 'Action.Submit' }
            $a.Title | Should -Be 'Save'
        }

        It 'Correctly identifies Action.OpenUrl' {
            $a = $script:Meta.Actions | Where-Object { $_.Type -eq 'Action.OpenUrl' }
            $a.Url | Should -Be 'https://adaptivecards.io'
        }
    }

    Context 'Pipeline input' {
        It 'Accepts JSON via pipeline' {
            $result = $script:MinimalCard | ConvertFrom-AdaptiveCard
            $result.Type | Should -Be 'AdaptiveCard'
        }
    }

    Context 'File input' {
        It 'Reads from a file path' {
            $samplePath = Join-Path $PSScriptRoot '..\Examples\sample-form.json'
            $result = ConvertFrom-AdaptiveCard -Path $samplePath
            $result.Type | Should -Be 'AdaptiveCard'
            $result.Inputs.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Error handling' {
        It 'Throws on invalid JSON' {
            { ConvertFrom-AdaptiveCard -Json 'not json {{{' } | Should -Throw
        }

        It 'Warns when type is not AdaptiveCard' {
            $json = '{"type":"Other","version":"1.0","body":[]}'
            $w = $null
            $result = ConvertFrom-AdaptiveCard -Json $json -WarningVariable w
            $w | Should -Not -BeNullOrEmpty
        }
    }
}

# ============================================================
# Get-AdaptiveCardElements (private, tested via InModuleScope)
# ============================================================
Describe 'Get-AdaptiveCardElements (private helper)' {

    Context 'Flat body' {
        It 'Returns one entry per top-level element' {
            InModuleScope PSAdaptiveCards {
                $fullCard = @'
{
  "type": "AdaptiveCard",
  "version": "1.5",
  "body": [
    { "type": "TextBlock", "text": "Hello", "id": "tb1" },
    { "type": "Input.Text",   "id": "name"   },
    { "type": "Input.Number", "id": "age"    },
    { "type": "Input.Date",   "id": "dob"    },
    { "type": "Input.Time",   "id": "alarm"  },
    { "type": "Input.Toggle", "id": "active" },
    { "type": "Input.ChoiceSet", "id": "role", "choices": [] },
    { "type": "Input.ChoiceSet", "id": "skills", "isMultiSelect": true, "choices": [] }
  ]
}
'@
                $card = $fullCard | ConvertFrom-Json
                $elements = Get-AdaptiveCardElements -Elements $card.body
                # 8 elements: 1 TextBlock + 7 inputs
                $elements.Count | Should -Be 8
            }
        }
    }

    Context 'Nested Container and ColumnSet' {
        It 'Flattens nested items correctly' {
            InModuleScope PSAdaptiveCards {
                $containerCard = @'
{
  "type": "AdaptiveCard",
  "version": "1.5",
  "body": [
    {
      "type": "Container",
      "id": "c1",
      "items": [
        { "type": "Input.Text", "id": "nested1", "label": "Nested 1" },
        {
          "type": "ColumnSet",
          "columns": [
            { "type": "Column", "items": [ { "type": "Input.Text", "id": "col1" } ] },
            { "type": "Column", "items": [ { "type": "Input.Text", "id": "col2" } ] }
          ]
        }
      ]
    }
  ]
}
'@
                $card = $containerCard | ConvertFrom-Json
                $elements = Get-AdaptiveCardElements -Elements $card.body
                $ids = $elements.Element | Where-Object { $_.id } | Select-Object -ExpandProperty id
                $ids | Should -Contain 'c1'
                $ids | Should -Contain 'nested1'
                $ids | Should -Contain 'col1'
                $ids | Should -Contain 'col2'
            }
        }

        It 'Sets correct Depth for nested elements' {
            InModuleScope PSAdaptiveCards {
                $containerCard = @'
{
  "type": "AdaptiveCard",
  "version": "1.5",
  "body": [
    {
      "type": "Container",
      "id": "c1",
      "items": [
        { "type": "Input.Text", "id": "nested1" }
      ]
    }
  ]
}
'@
                $card = $containerCard | ConvertFrom-Json
                $elements = Get-AdaptiveCardElements -Elements $card.body
                $c1Depth      = ($elements | Where-Object { $_.Element.id -eq 'c1' }).Depth
                $nested1Depth = ($elements | Where-Object { $_.Element.id -eq 'nested1' }).Depth
                $c1Depth      | Should -Be 0
                $nested1Depth | Should -Be 1
            }
        }
    }
}

# ============================================================
# Start-AdaptiveCardMCPServer (protocol layer)
# ============================================================
Describe 'Start-AdaptiveCardMCPServer' {

    # Helper: send JSON-RPC messages to a piped server process and collect output
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '..\PSAdaptiveCards\PSAdaptiveCards.psd1'

        # Write a temp launcher script once for all tests
        $script:LauncherScript = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.ps1'
        @'
param([string]$ModulePath)
Import-Module $ModulePath -Force
Start-AdaptiveCardMCPServer
'@ | Set-Content -Path $script:LauncherScript -Encoding UTF8

        function script:Invoke-MCPMessages {
            param([string[]]$Messages)

            $allLines = $Messages -join "`n"

            $result = $allLines | pwsh -NoProfile -NonInteractive `
                -File $script:LauncherScript `
                -ModulePath $script:ModulePath 2>$null

            return $result | Where-Object { $_ -and $_.Trim() -ne '' } |
                   ForEach-Object { $_ | ConvertFrom-Json }
        }
    }

    AfterAll {
        if ($script:LauncherScript -and (Test-Path $script:LauncherScript)) {
            Remove-Item $script:LauncherScript -Force
        }
    }

    Context 'initialize handshake' {
        It 'Returns protocolVersion 2024-11-05' {
            $msgs = @(
                '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
            )
            $responses = Invoke-MCPMessages -Messages $msgs
            $init = $responses | Where-Object { $_.id -eq 1 }
            $init.result.protocolVersion | Should -Be '2024-11-05'
        }

        It 'Returns server name PSAdaptiveCards' {
            $msgs = @(
                '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
            )
            $responses = Invoke-MCPMessages -Messages $msgs
            $init = $responses | Where-Object { $_.id -eq 1 }
            $init.result.serverInfo.name | Should -Be 'PSAdaptiveCards'
        }
    }

    Context 'tools/list' {
        It 'Returns at least 4 tools' {
            $msgs = @(
                '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}',
                '{"jsonrpc":"2.0","method":"notifications/initialized"}',
                '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
            )
            $responses = Invoke-MCPMessages -Messages $msgs
            $list = $responses | Where-Object { $_.id -eq 2 }
            $list.result.tools.Count | Should -BeGreaterOrEqual 4
        }

        It 'Includes generate_form tool' {
            $msgs = @(
                '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}',
                '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
            )
            $responses = Invoke-MCPMessages -Messages $msgs
            $list = $responses | Where-Object { $_.id -eq 2 }
            $names = $list.result.tools | Select-Object -ExpandProperty name
            $names | Should -Contain 'generate_form'
        }
    }

    Context 'tools/call validate_card' {
        It 'Returns isValid=true for valid Adaptive Card JSON' {
            $cardEscaped = '{"type":"AdaptiveCard","version":"1.5","body":[]}'
            $callMsg = "{`"jsonrpc`":`"2.0`",`"id`":3,`"method`":`"tools/call`",`"params`":{`"name`":`"validate_card`",`"arguments`":{`"card_json`":`"$($cardEscaped -replace '"','\"')`"}}}"
            $msgs = @(
                '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}',
                $callMsg
            )
            $responses = Invoke-MCPMessages -Messages $msgs
            $call = $responses | Where-Object { $_.id -eq 3 }
            $text = $call.result.content[0].text
            $parsed = $text | ConvertFrom-Json
            $parsed.isValid | Should -BeTrue
        }

        It 'Returns isValid=false for invalid JSON' {
            $msgs = @(
                '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}',
                '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"validate_card","arguments":{"card_json":"not valid json {{"}}}'
            )
            $responses = Invoke-MCPMessages -Messages $msgs
            $call = $responses | Where-Object { $_.id -eq 3 }
            $text = $call.result.content[0].text
            $parsed = $text | ConvertFrom-Json
            $parsed.isValid | Should -BeFalse
        }
    }

    Context 'tools/call parse_card' {
        It 'Returns Input fields from the card JSON' {
            $cardJson = '{"type":"AdaptiveCard","version":"1.5","body":[{"type":"Input.Text","id":"username","label":"Username"}]}'
            $callPayload = [PSCustomObject]@{
                jsonrpc = '2.0'
                id      = 4
                method  = 'tools/call'
                params  = [PSCustomObject]@{
                    name      = 'parse_card'
                    arguments = [PSCustomObject]@{ card_json = $cardJson }
                }
            } | ConvertTo-Json -Depth 10 -Compress

            $msgs = @(
                '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}',
                $callPayload
            )
            $responses = Invoke-MCPMessages -Messages $msgs
            $call = $responses | Where-Object { $_.id -eq 4 }
            $text = $call.result.content[0].text
            $meta = $text | ConvertFrom-Json
            $meta.Inputs[0].Id | Should -Be 'username'
        }
    }

    Context 'tools/call list_element_types' {
        It 'Returns known element categories' {
            $msgs = @(
                '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}',
                '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"list_element_types","arguments":{}}}'
            )
            $responses = Invoke-MCPMessages -Messages $msgs
            $call = $responses | Where-Object { $_.id -eq 5 }
            $types = $call.result.content[0].text | ConvertFrom-Json
            $types.inputs | Should -Contain 'Input.Text'
            $types.actions | Should -Contain 'Action.Submit'
        }
    }

    Context 'Unknown method' {
        It 'Returns error code -32601 for unknown methods' {
            $msgs = @(
                '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}',
                '{"jsonrpc":"2.0","id":99,"method":"nonexistent/method","params":{}}'
            )
            $responses = Invoke-MCPMessages -Messages $msgs
            $err = $responses | Where-Object { $_.id -eq 99 }
            $err.error.code | Should -Be -32601
        }
    }

    Context 'ping' {
        It 'Responds to ping with an empty result' {
            $msgs = @(
                '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}',
                '{"jsonrpc":"2.0","id":10,"method":"ping","params":{}}'
            )
            $responses = Invoke-MCPMessages -Messages $msgs
            $pong = $responses | Where-Object { $_.id -eq 10 }
            $pong | Should -Not -BeNullOrEmpty
            $pong.error | Should -BeNullOrEmpty
        }
    }
}
