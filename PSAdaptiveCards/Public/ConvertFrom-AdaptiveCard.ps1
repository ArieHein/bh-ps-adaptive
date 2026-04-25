function ConvertFrom-AdaptiveCard {
    <#
    .SYNOPSIS
        Parses an Adaptive Card JSON string or file and returns structured
        metadata about its input fields and actions.
    .DESCRIPTION
        Reads an Adaptive Card JSON payload and extracts:
          - Card-level metadata (schema, type, version, title, description)
          - All input fields with their id, type, label, placeholder, required flag,
            default value, and choice lists
          - All actions with their type and title
        This function does NOT render any UI.  Use Invoke-AdaptiveCardUI to
        render the card as a Windows Form.
    .PARAMETER Json
        The raw Adaptive Card JSON string.
    .PARAMETER Path
        Path to a JSON file containing the Adaptive Card.
    .OUTPUTS
        [PSCustomObject] with properties: Schema, Type, Version, Title,
        Description, Inputs, Actions
    .EXAMPLE
        $meta = ConvertFrom-AdaptiveCard -Path .\Examples\sample-form.json
        $meta.Inputs | Format-Table Id, Type, Label, IsRequired
    .EXAMPLE
        $json = Get-Content .\card.json -Raw
        ConvertFrom-AdaptiveCard -Json $json
    #>
    [CmdletBinding(DefaultParameterSetName = 'Json')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Json', ValueFromPipeline)]
        [string] $Json,

        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string] $Path
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $Json = Get-Content -Path $Path -Raw -Encoding UTF8
        }

        try {
            $card = $Json | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "Invalid JSON: $_"
        }

        if ($card.type -ne 'AdaptiveCard') {
            Write-Warning "JSON does not appear to be an Adaptive Card (type = '$($card.type)')."
        }

        # Flatten all body elements
        $allElements = if ($card.body) {
            Get-AdaptiveCardElements -Elements $card.body
        }
        else { @() }

        $inputTypes  = @('Input.Text','Input.Number','Input.Date','Input.Time','Input.Toggle','Input.ChoiceSet')
        $inputs      = @()
        $actionsList = @()

        foreach ($flat in $allElements) {
            $el = $flat.Element
            if ($el.type -in $inputTypes) {
                $inputMeta = [PSCustomObject]@{
                    Id          = $el.id
                    Type        = $el.type
                    Label       = $el.label
                    Placeholder = $el.placeholder
                    IsRequired  = ($el.isRequired -eq $true)
                    DefaultValue = $el.value
                    Choices     = if ($el.choices) { $el.choices | ForEach-Object { [PSCustomObject]@{ Value = $_.value; Title = $_.title } } } else { $null }
                    IsMultiSelect = ($el.isMultiSelect -eq $true)
                    Style       = $el.style
                    Min         = $el.min
                    Max         = $el.max
                    MaxLength   = $el.maxLength
                }
                $inputs += $inputMeta
            }
        }

        foreach ($action in ($card.actions ?? @())) {
            $actionsList += [PSCustomObject]@{
                Type  = $action.type
                Title = $action.title
                Url   = $action.url
                Verb  = $action.verb
                Data  = $action.data
            }
        }

        return [PSCustomObject]@{
            Schema      = $card.'$schema'
            Type        = $card.type
            Version     = $card.version
            Title       = $card.title
            Description = $card.description
            Inputs      = $inputs
            Actions     = $actionsList
        }
    }
}
