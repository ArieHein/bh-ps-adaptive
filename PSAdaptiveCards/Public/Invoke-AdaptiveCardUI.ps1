function Invoke-AdaptiveCardUI {
    <#
    .SYNOPSIS
        Renders an Adaptive Card as a Windows Forms dialog and returns the
        values submitted by the user.
    .DESCRIPTION
        Accepts an Adaptive Card JSON string or file path, builds the
        corresponding Windows Form (labels, text boxes, date pickers, check
        boxes, combo boxes, etc.), presents it to the user, and returns a
        hashtable of field-id -> submitted-value pairs when the user clicks
        Submit (or $null if the user cancelled).

        Requires Windows with .NET's System.Windows.Forms assembly.
    .PARAMETER Json
        The raw Adaptive Card JSON string.
    .PARAMETER Path
        Path to a JSON file containing the Adaptive Card.
    .OUTPUTS
        [hashtable] of field-id -> value, or $null when cancelled.
    .EXAMPLE
        $values = Invoke-AdaptiveCardUI -Path .\Examples\sample-form.json
        if ($values) { $values | ConvertTo-Json }
    .EXAMPLE
        $json = Get-Content .\card.json -Raw
        $values = Invoke-AdaptiveCardUI -Json $json
    #>
    [CmdletBinding(DefaultParameterSetName = 'Json')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Json', ValueFromPipeline)]
        [string] $Json,

        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string] $Path
    )

    process {
        if (-not $IsWindows) {
            throw 'Invoke-AdaptiveCardUI requires Windows (System.Windows.Forms).'
        }

        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $Json = Get-Content -Path $Path -Raw -Encoding UTF8
        }

        try {
            $card = $Json | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "Invalid Adaptive Card JSON: $_"
        }

        if ($card.type -ne 'AdaptiveCard') {
            Write-Warning "JSON does not appear to be an Adaptive Card (type = '$($card.type)'). Attempting to render anyway."
        }

        return Show-AdaptiveCardForm -Card $card
    }
}
