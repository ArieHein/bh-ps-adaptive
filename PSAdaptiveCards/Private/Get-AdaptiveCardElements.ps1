function Get-AdaptiveCardElements {
    <#
    .SYNOPSIS
        Recursively flattens all elements in an Adaptive Card body.
    .DESCRIPTION
        Traverses Container, ColumnSet, Column, and other wrapper elements and
        returns every leaf element together with its depth and parent chain so
        the caller can lay them out in order.
    .PARAMETER Elements
        An array of Adaptive Card element objects (from the 'body' property of
        the parsed card JSON).
    .OUTPUTS
        [PSCustomObject[]] with properties: Element, Depth, ParentId
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [object[]] $Elements,

        [int]    $Depth    = 0,
        [string] $ParentId = ''
    )

    $containerTypes = @('Container', 'ColumnSet', 'Column', 'TableRow', 'TableCell')

    foreach ($element in $Elements) {
        if (-not $element.type) { continue }

        [PSCustomObject]@{
            Element  = $element
            Depth    = $Depth
            ParentId = $ParentId
        }

        # Recurse into container types
        switch ($element.type) {
            'Container' {
                if ($element.items) {
                    Get-AdaptiveCardElements -Elements $element.items -Depth ($Depth + 1) -ParentId $element.id
                }
            }
            'ColumnSet' {
                if ($element.columns) {
                    foreach ($col in $element.columns) {
                        if ($col.items) {
                            Get-AdaptiveCardElements -Elements $col.items -Depth ($Depth + 1) -ParentId $col.id
                        }
                    }
                }
            }
            'Column' {
                if ($element.items) {
                    Get-AdaptiveCardElements -Elements $element.items -Depth ($Depth + 1) -ParentId $element.id
                }
            }
        }
    }
}
