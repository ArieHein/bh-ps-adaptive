function Show-AdaptiveCardForm {
    <#
    .SYNOPSIS
        Builds a Windows Forms dialog from a parsed Adaptive Card object and
        shows it to the user.
    .DESCRIPTION
        Iterates over the flattened card elements, creates the appropriate
        WinForms controls via New-WinFormControl, positions them vertically
        inside a scrollable panel, and attaches Submit / Cancel buttons.
        When the user clicks Submit the function collects and returns all
        input-field values as a [hashtable].
    .PARAMETER Card
        A parsed Adaptive Card object (result of ConvertFrom-Json).
    .OUTPUTS
        [hashtable] of field-id -> value, or $null if the user cancelled.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object] $Card
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $formWidth  = 500
    $padding    = 20
    $ctrlWidth  = $formWidth - ($padding * 2) - 20   # 20 for scrollbar
    $rowGap     = 8

    # ---- Outer form --------------------------------------------------------
    $form               = [System.Windows.Forms.Form]::new()
    $form.Text          = if ($Card.title)    { $Card.title }
                          elseif ($Card.'$schema') { 'Adaptive Card' }
                          else { 'Form' }
    $form.Width         = $formWidth
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox   = $false
    $form.MinimizeBox   = $false
    $form.Font          = [System.Drawing.Font]::new('Segoe UI', 9)
    $form.BackColor     = [System.Drawing.Color]::White

    # ---- Scrollable panel --------------------------------------------------
    $scrollPanel                  = [System.Windows.Forms.Panel]::new()
    $scrollPanel.AutoScroll       = $true
    $scrollPanel.Dock             = [System.Windows.Forms.DockStyle]::Fill
    $scrollPanel.Padding          = [System.Windows.Forms.Padding]::new($padding, $padding, $padding, 0)

    # ---- Collect body elements (recursively flattened) ---------------------
    $bodyElements = if ($Card.body) {
        Get-AdaptiveCardElements -Elements $Card.body
    }
    else { @() }

    $actionElements = if ($Card.actions) { $Card.actions } else { @() }

    $yPos        = $padding
    $inputControls = [System.Collections.Generic.List[object]]::new()
    $hasSubmit   = $false

    foreach ($flat in $bodyElements) {
        $element = $flat.Element
        $built   = New-WinFormControl -Element $element -FormWidth $ctrlWidth

        if ($built.Label) {
            $built.Label.Location = [System.Drawing.Point]::new(0, $yPos)
            $scrollPanel.Controls.Add($built.Label)
            $yPos += $built.Label.PreferredHeight + 2
        }

        if ($built.Control) {
            $built.Control.Location = [System.Drawing.Point]::new(0, $yPos)
            $built.Control.Width    = $ctrlWidth
            $scrollPanel.Controls.Add($built.Control)
            if (-not $built.IsAction) {
                $inputControls.Add($built.Control)
            }
            $yPos += $built.Control.Height + $rowGap
        }
    }

    # ---- Actions area ------------------------------------------------------
    $hasCardSubmit = $false

    foreach ($action in $actionElements) {
        $built = New-WinFormControl -Element $action -FormWidth $ctrlWidth
        if ($built.Control) {
            $built.Control.Location = [System.Drawing.Point]::new(0, $yPos)
            $scrollPanel.Controls.Add($built.Control)
            if ($action.type -eq 'Action.Submit') { $hasCardSubmit = $true }
            $yPos += $built.Control.Height + $rowGap
        }
    }

    # Default Submit + Cancel buttons if card has no Action.Submit
    if (-not $hasCardSubmit) {
        $btnSubmit              = [System.Windows.Forms.Button]::new()
        $btnSubmit.Text         = 'Submit'
        $btnSubmit.AutoSize     = $true
        $btnSubmit.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $btnSubmit.Location     = [System.Drawing.Point]::new(0, $yPos)
        $scrollPanel.Controls.Add($btnSubmit)
        $form.AcceptButton = $btnSubmit

        $btnCancel              = [System.Windows.Forms.Button]::new()
        $btnCancel.Text         = 'Cancel'
        $btnCancel.AutoSize     = $true
        $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $btnCancel.Location     = [System.Drawing.Point]::new($btnSubmit.Width + 10, $yPos)
        $scrollPanel.Controls.Add($btnCancel)
        $form.CancelButton = $btnCancel

        $yPos += 36
    }

    # ---- Size the form to fit content up to a maximum ----------------------
    $scrollPanel.AutoScrollMinSize = [System.Drawing.Size]::new($ctrlWidth, $yPos + $padding)
    $form.Height = [Math]::Min($yPos + $padding * 3 + 40, 700)
    $form.Controls.Add($scrollPanel)

    # ---- Show dialog and collect values ------------------------------------
    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }

    $values = @{}

    foreach ($ctrl in $inputControls) {
        $id = $null
        $val = $null

        if ($ctrl.Tag -is [hashtable]) {
            $id = $ctrl.Tag.Id
        }
        elseif ($ctrl.Tag -is [string]) {
            $id = $ctrl.Tag
        }

        if (-not $id) { continue }

        switch ($ctrl.GetType().Name) {
            'TextBox'          { $val = $ctrl.Text }
            'NumericUpDown'    { $val = [double]$ctrl.Value }
            'DateTimePicker'   {
                if ($ctrl.Format -eq [System.Windows.Forms.DateTimePickerFormat]::Time) {
                    $val = $ctrl.Value.ToString('HH:mm')
                }
                else {
                    $val = $ctrl.Value.ToString('yyyy-MM-dd')
                }
            }
            'CheckBox'         { $val = $ctrl.Checked }
            'CheckedListBox'   {
                $choices   = $ctrl.Tag.Choices
                $checked   = @()
                for ($i = 0; $i -lt $ctrl.Items.Count; $i++) {
                    if ($ctrl.GetItemChecked($i)) {
                        $checked += $choices[$i].value
                    }
                }
                $val = $checked -join ','
            }
            'Panel'            {
                # Radio buttons
                $selected = $ctrl.Controls | Where-Object { $_ -is [System.Windows.Forms.RadioButton] -and $_.Checked } | Select-Object -First 1
                $val = if ($selected) { $selected.Tag } else { $null }
                $id  = $ctrl.Tag.Id
            }
            'ComboBox'         {
                $choices = $ctrl.Tag.Choices
                $title   = $ctrl.SelectedItem
                $matched = $choices | Where-Object { $_.title -eq $title } | Select-Object -First 1
                $val     = if ($matched) { $matched.value } else { $null }
            }
            'Label'            { continue }
        }

        if ($null -ne $val) {
            $values[$id] = $val
        }
    }

    return $values
}
