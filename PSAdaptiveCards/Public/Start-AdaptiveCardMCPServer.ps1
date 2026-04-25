function Start-AdaptiveCardMCPServer {
    <#
    .SYNOPSIS
        Starts a local Model Context Protocol (MCP) server over stdio that
        exposes Adaptive Card form generation as AI-callable tools.
    .DESCRIPTION
        Implements the MCP 2024-11-05 specification over stdin/stdout using
        JSON-RPC 2.0.  An AI assistant (such as Claude Desktop, Copilot, or
        any MCP-compatible client) can connect to this server via stdio and
        call the following tools:

          generate_form    – Show a WinForms dialog built from an Adaptive Card
                             JSON string and return the submitted values.
          parse_card       – Parse an Adaptive Card JSON string and return
                             metadata about its input fields and actions.
          validate_card    – Validate that a string is a well-formed Adaptive
                             Card JSON payload.
          list_element_types – List all supported Adaptive Card element types.

        The server runs until the client closes stdin or the process is
        terminated.  All diagnostic messages are written to stderr so they do
        not interfere with the JSON-RPC stream on stdout.

        To use with Claude Desktop, add an entry to its MCP configuration:

            {
              "mcpServers": {
                "adaptive-cards": {
                  "command": "pwsh",
                  "args": [
                    "-NoProfile",
                    "-NonInteractive",
                    "-Command",
                    "Import-Module '<path>\\PSAdaptiveCards'; Start-AdaptiveCardMCPServer"
                  ]
                }
              }
            }

    .PARAMETER LogPath
        Optional path to a log file.  Diagnostic messages are appended there
        in addition to stderr.
    .EXAMPLE
        # Run interactively (useful for testing with manual JSON-RPC input)
        Start-AdaptiveCardMCPServer

        # Run with logging
        Start-AdaptiveCardMCPServer -LogPath C:\Temp\mcp-server.log
    #>
    [CmdletBinding()]
    param(
        [string] $LogPath
    )

    # ---- Helper: write a log line to stderr (and optional file) ------------
    $logMessage = {
        param([string]$Msg)
        $line = "[$(Get-Date -Format 'HH:mm:ss')] $Msg"
        [Console]::Error.WriteLine($line)
        if ($LogPath) { Add-Content -Path $LogPath -Value $line -Encoding UTF8 }
    }

    # ---- Helper: send a JSON-RPC response to stdout ------------------------
    $sendResponse = {
        param([object]$Response)
        $json = $Response | ConvertTo-Json -Depth 20 -Compress
        [Console]::Out.WriteLine($json)
        [Console]::Out.Flush()
    }

    # ---- Helper: build a JSON-RPC success response -------------------------
    $okResponse = {
        param($Id, [object]$Result)
        [ordered]@{ jsonrpc = '2.0'; id = $Id; result = $Result }
    }

    # ---- Helper: build a JSON-RPC error response ---------------------------
    $errResponse = {
        param($Id, [int]$Code, [string]$Message)
        [ordered]@{
            jsonrpc = '2.0'
            id      = $Id
            error   = [ordered]@{ code = $Code; message = $Message }
        }
    }

    # ---- Tool definitions --------------------------------------------------
    $toolDefs = @(
        [ordered]@{
            name        = 'generate_form'
            description = 'Render an Adaptive Card JSON as a Windows Forms dialog. Returns the submitted field values as a JSON object, or null if the user cancelled.'
            inputSchema = [ordered]@{
                type       = 'object'
                properties = [ordered]@{
                    card_json = [ordered]@{
                        type        = 'string'
                        description = 'The Adaptive Card JSON string to render as a form.'
                    }
                }
                required   = @('card_json')
            }
        }
        [ordered]@{
            name        = 'parse_card'
            description = 'Parse an Adaptive Card JSON and return metadata about its input fields and actions without showing any UI.'
            inputSchema = [ordered]@{
                type       = 'object'
                properties = [ordered]@{
                    card_json = [ordered]@{
                        type        = 'string'
                        description = 'The Adaptive Card JSON string to parse.'
                    }
                }
                required   = @('card_json')
            }
        }
        [ordered]@{
            name        = 'validate_card'
            description = 'Check whether the provided string is a well-formed Adaptive Card JSON payload. Returns an object with isValid (bool) and an optional error message.'
            inputSchema = [ordered]@{
                type       = 'object'
                properties = [ordered]@{
                    card_json = [ordered]@{
                        type        = 'string'
                        description = 'The JSON string to validate.'
                    }
                }
                required   = @('card_json')
            }
        }
        [ordered]@{
            name        = 'list_element_types'
            description = 'Return the list of Adaptive Card element types supported by this module.'
            inputSchema = [ordered]@{
                type       = 'object'
                properties = [ordered]@{}
            }
        }
    )

    # ---- Tool implementations ----------------------------------------------
    $handleToolCall = {
        param([string]$ToolName, [hashtable]$ToolArgs)

        switch ($ToolName) {

            'generate_form' {
                $cardJson = $ToolArgs['card_json']
                if (-not $cardJson) {
                    return [ordered]@{
                        isError  = $true
                        content  = @([ordered]@{ type = 'text'; text = "Missing required argument 'card_json'." })
                    }
                }

                try {
                    $card = $cardJson | ConvertFrom-Json -ErrorAction Stop
                }
                catch {
                    return [ordered]@{
                        isError = $true
                        content = @([ordered]@{ type = 'text'; text = "Invalid JSON: $_" })
                    }
                }

                if (-not $IsWindows) {
                    return [ordered]@{
                        isError = $true
                        content = @([ordered]@{ type = 'text'; text = 'generate_form requires Windows (System.Windows.Forms is not available on this platform).' })
                    }
                }

                try {
                    $values = Show-AdaptiveCardForm -Card $card
                    if ($null -eq $values) {
                        $text = 'User cancelled the form.'
                    }
                    else {
                        $text = $values | ConvertTo-Json -Depth 10 -Compress
                    }
                    return [ordered]@{
                        content = @([ordered]@{ type = 'text'; text = $text })
                    }
                }
                catch {
                    return [ordered]@{
                        isError = $true
                        content = @([ordered]@{ type = 'text'; text = "Error rendering form: $_" })
                    }
                }
            }

            'parse_card' {
                $cardJson = $ToolArgs['card_json']
                if (-not $cardJson) {
                    return [ordered]@{
                        isError = $true
                        content = @([ordered]@{ type = 'text'; text = "Missing required argument 'card_json'." })
                    }
                }

                try {
                    $meta = ConvertFrom-AdaptiveCard -Json $cardJson
                    $text = $meta | ConvertTo-Json -Depth 10 -Compress
                    return [ordered]@{
                        content = @([ordered]@{ type = 'text'; text = $text })
                    }
                }
                catch {
                    return [ordered]@{
                        isError = $true
                        content = @([ordered]@{ type = 'text'; text = "Error parsing card: $_" })
                    }
                }
            }

            'validate_card' {
                $cardJson = $ToolArgs['card_json']
                if (-not $cardJson) {
                    return [ordered]@{
                        isError = $true
                        content = @([ordered]@{ type = 'text'; text = "Missing required argument 'card_json'." })
                    }
                }

                try {
                    $obj = $cardJson | ConvertFrom-Json -ErrorAction Stop
                    $isCard = ($obj.type -eq 'AdaptiveCard')
                    $result = [ordered]@{
                        isValid = $true
                        isAdaptiveCard = $isCard
                        version = $obj.version
                        message = if ($isCard) { 'Valid Adaptive Card JSON.' } else { "Parsed as JSON but type is '$($obj.type)' (expected 'AdaptiveCard')." }
                    }
                    return [ordered]@{
                        content = @([ordered]@{ type = 'text'; text = ($result | ConvertTo-Json -Compress) })
                    }
                }
                catch {
                    $result = [ordered]@{ isValid = $false; isAdaptiveCard = $false; message = "JSON parse error: $_" }
                    return [ordered]@{
                        content = @([ordered]@{ type = 'text'; text = ($result | ConvertTo-Json -Compress) })
                    }
                }
            }

            'list_element_types' {
                $types = [ordered]@{
                    display = @('TextBlock', 'Image', 'Media', 'RichTextBlock')
                    inputs  = @('Input.Text', 'Input.Number', 'Input.Date', 'Input.Time', 'Input.Toggle', 'Input.ChoiceSet')
                    layout  = @('Container', 'ColumnSet', 'Column', 'Table', 'TableRow', 'TableCell')
                    actions = @('Action.Submit', 'Action.OpenUrl', 'Action.Execute', 'Action.ShowCard', 'Action.ToggleVisibility')
                }
                return [ordered]@{
                    content = @([ordered]@{ type = 'text'; text = ($types | ConvertTo-Json -Compress) })
                }
            }

            default {
                return [ordered]@{
                    isError = $true
                    content = @([ordered]@{ type = 'text'; text = "Unknown tool: $ToolName" })
                }
            }
        }
    }

    # ---- Main server loop --------------------------------------------------
    & $logMessage "PSAdaptiveCards MCP server starting (PID $PID)."

    $reader = [System.Console]::In
    $initialized = $false

    while ($true) {
        try {
            $line = $reader.ReadLine()
        }
        catch {
            & $logMessage "stdin read error: $_"
            break
        }

        if ($null -eq $line) {
            & $logMessage 'stdin closed – shutting down.'
            break
        }

        $line = $line.Trim()
        if ($line -eq '') { continue }

        & $logMessage "RX: $line"

        try {
            $msg = $line | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            & $logMessage "JSON parse error: $_"
            # Cannot reply without an id; ignore malformed messages
            continue
        }

        $msgId = $msg.id     # may be $null for notifications
        $method = $msg.method

        # Notifications have no id – process but do not reply
        if ($null -eq $msgId -and $method -eq 'notifications/initialized') {
            $initialized = $true
            & $logMessage 'Client initialized.'
            continue
        }

        switch ($method) {

            'initialize' {
                $clientProto = $msg.params.protocolVersion
                $reply = & $okResponse $msgId ([ordered]@{
                    protocolVersion = '2024-11-05'
                    capabilities    = [ordered]@{
                        tools = [ordered]@{ listChanged = $false }
                    }
                    serverInfo = [ordered]@{
                        name    = 'PSAdaptiveCards'
                        version = '1.0.0'
                    }
                })
                & $sendResponse $reply
                & $logMessage "Initialized with client protocol $clientProto."
            }

            'tools/list' {
                $reply = & $okResponse $msgId ([ordered]@{ tools = $toolDefs })
                & $sendResponse $reply
            }

            'tools/call' {
                $toolName = $msg.params.name
                $toolArgs = @{}
                if ($msg.params.arguments) {
                    # ConvertFrom-Json gives a PSCustomObject – convert to hashtable
                    $msg.params.arguments.PSObject.Properties | ForEach-Object {
                        $toolArgs[$_.Name] = $_.Value
                    }
                }

                & $logMessage "Tool call: $toolName"
                $toolResult = & $handleToolCall $toolName $toolArgs
                $reply = & $okResponse $msgId $toolResult
                & $sendResponse $reply
            }

            'ping' {
                $reply = & $okResponse $msgId ([ordered]@{})
                & $sendResponse $reply
            }

            default {
                if ($null -ne $msgId) {
                    $reply = & $errResponse $msgId -32601 "Method not found: $method"
                    & $sendResponse $reply
                }
            }
        }
    }

    & $logMessage 'PSAdaptiveCards MCP server stopped.'
}
