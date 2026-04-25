function New-WinFormControl {
    <#
    .SYNOPSIS
        Creates a Windows Forms control that corresponds to an Adaptive Card element.
    .DESCRIPTION
        Maps Adaptive Card element types to their WinForms equivalents:
          TextBlock         -> Label
          Input.Text        -> TextBox  (multiline when isMultiline = true)
          Input.Number      -> NumericUpDown
          Input.Date        -> DateTimePicker (date mode)
          Input.Time        -> DateTimePicker (time mode)
          Input.Toggle      -> CheckBox
          Input.ChoiceSet   -> ComboBox (style: compact / filtered) or
                               Panel of RadioButton (style: expanded, not multi-select)
                               or CheckedListBox (style: expanded, multi-select)
          Action.Submit     -> Button (DialogResult = OK)
          Action.OpenUrl    -> Button (opens URL on click)
          Action.Execute    -> Button (fires event)
          TextBlock heading -> Bold Label
        All controls are set to a standard width (360 px) and carry their
        element's 'id' in the .Tag property so submitted values can be mapped
        back to field identifiers.
    .PARAMETER Element
        The Adaptive Card element object.
    .PARAMETER FormWidth
        The width of the parent form (used to scale control widths).
    .OUTPUTS
        Hashtable with keys:
          Label   - [System.Windows.Forms.Label] or $null
          Control - [System.Windows.Forms.Control] or $null
          IsAction - [bool]
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Element,

        [int] $FormWidth = 460
    )

    $ctrlWidth  = $FormWidth - 60
    $labelFont  = [System.Drawing.Font]::new('Segoe UI', 9)
    $inputFont  = [System.Drawing.Font]::new('Segoe UI', 10)
    $boldFont   = [System.Drawing.Font]::new('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $result = @{ Label = $null; Control = $null; IsAction = $false }

    switch -Wildcard ($Element.type) {

        'TextBlock' {
            $lbl            = [System.Windows.Forms.Label]::new()
            $lbl.Text       = if ($Element.text) { $Element.text } else { '' }
            $lbl.AutoSize   = $false
            $lbl.Width      = $ctrlWidth
            $lbl.Height     = if ($Element.wrap) { 0 } else { 20 }
            $lbl.AutoSize   = $true
            $lbl.MaximumSize = [System.Drawing.Size]::new($ctrlWidth, 0)
            $lbl.Font       = if ($Element.weight -eq 'bolder' -or $Element.size -eq 'large') { $boldFont } else { $labelFont }
            if ($Element.color -eq 'attention') {
                $lbl.ForeColor = [System.Drawing.Color]::Red
            }
            elseif ($Element.color -eq 'good') {
                $lbl.ForeColor = [System.Drawing.Color]::Green
            }
            elseif ($Element.color -eq 'warning') {
                $lbl.ForeColor = [System.Drawing.Color]::DarkOrange
            }
            $lbl.Tag = $Element.id
            $result.Control = $lbl
        }

        'Input.Text' {
            # Optional: heading label for the field
            if ($Element.label -or $Element.placeholder) {
                $lbl            = [System.Windows.Forms.Label]::new()
                $lbl.Text       = if ($Element.label) { $Element.label } else { $Element.placeholder }
                $lbl.Font       = $labelFont
                $lbl.AutoSize   = $true
                $result.Label   = $lbl
            }

            $tb             = [System.Windows.Forms.TextBox]::new()
            $tb.Name        = $Element.id
            $tb.Tag         = $Element.id
            $tb.Width       = $ctrlWidth
            $tb.Font        = $inputFont
            if ($Element.isMultiline) {
                $tb.Multiline  = $true
                $tb.Height     = 80
                $tb.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
            }
            if ($Element.placeholder) { $tb.PlaceholderText = $Element.placeholder }
            if ($Element.value)       { $tb.Text = $Element.value }
            if ($Element.maxLength)   { $tb.MaxLength = [int]$Element.maxLength }
            if ($Element.style -eq 'password') { $tb.PasswordChar = '*' }
            if ($Element.isRequired -and $null -ne $result.Label) { $result.Label.Text += ' *' }
            $result.Control = $tb
        }

        'Input.Number' {
            if ($Element.label -or $Element.placeholder) {
                $lbl            = [System.Windows.Forms.Label]::new()
                $lbl.Text       = if ($Element.label) { $Element.label } else { $Element.placeholder }
                $lbl.Font       = $labelFont
                $lbl.AutoSize   = $true
                $result.Label   = $lbl
            }

            $nud            = [System.Windows.Forms.NumericUpDown]::new()
            $nud.Name       = $Element.id
            $nud.Tag        = $Element.id
            $nud.Width      = $ctrlWidth
            $nud.Font       = $inputFont
            $nud.Minimum    = if ($null -ne $Element.min) { [decimal]$Element.min } else { [decimal]::MinValue / 1000 }
            $nud.Maximum    = if ($null -ne $Element.max) { [decimal]$Element.max } else { [decimal]::MaxValue / 1000 }
            if ($null -ne $Element.value) { $nud.Value = [decimal]$Element.value }
            if ($Element.isRequired -and $null -ne $result.Label) { $result.Label.Text += ' *' }
            $result.Control = $nud
        }

        'Input.Date' {
            if ($Element.label -or $Element.placeholder) {
                $lbl            = [System.Windows.Forms.Label]::new()
                $lbl.Text       = if ($Element.label) { $Element.label } else { $Element.placeholder }
                $lbl.Font       = $labelFont
                $lbl.AutoSize   = $true
                $result.Label   = $lbl
            }

            $dtp            = [System.Windows.Forms.DateTimePicker]::new()
            $dtp.Name       = $Element.id
            $dtp.Tag        = $Element.id
            $dtp.Width      = $ctrlWidth
            $dtp.Font       = $inputFont
            $dtp.Format     = [System.Windows.Forms.DateTimePickerFormat]::Short
            if ($Element.value) {
                try { $dtp.Value = [datetime]::Parse($Element.value) } catch {}
            }
            $result.Control = $dtp
        }

        'Input.Time' {
            if ($Element.label -or $Element.placeholder) {
                $lbl            = [System.Windows.Forms.Label]::new()
                $lbl.Text       = if ($Element.label) { $Element.label } else { $Element.placeholder }
                $lbl.Font       = $labelFont
                $lbl.AutoSize   = $true
                $result.Label   = $lbl
            }

            $dtp            = [System.Windows.Forms.DateTimePicker]::new()
            $dtp.Name       = $Element.id
            $dtp.Tag        = $Element.id
            $dtp.Width      = $ctrlWidth
            $dtp.Font       = $inputFont
            $dtp.Format     = [System.Windows.Forms.DateTimePickerFormat]::Time
            $dtp.ShowUpDown = $true
            if ($Element.value) {
                try {
                    $today = [datetime]::Today
                    $parts = $Element.value -split ':'
                    $dtp.Value = $today.AddHours([int]$parts[0]).AddMinutes([int]$parts[1])
                }
                catch {}
            }
            $result.Control = $dtp
        }

        'Input.Toggle' {
            $cb            = [System.Windows.Forms.CheckBox]::new()
            $cb.Name       = $Element.id
            $cb.Tag        = $Element.id
            $cb.Text       = if ($Element.title) { $Element.title } else { $Element.id }
            $cb.Font       = $inputFont
            $cb.AutoSize   = $true
            $cb.Checked    = ($Element.value -eq $true -or $Element.value -eq 'true')
            $result.Control = $cb
        }

        'Input.ChoiceSet' {
            if ($Element.label -or $Element.placeholder) {
                $lbl            = [System.Windows.Forms.Label]::new()
                $lbl.Text       = if ($Element.label) { $Element.label } else { $Element.placeholder }
                $lbl.Font       = $labelFont
                $lbl.AutoSize   = $true
                $result.Label   = $lbl
            }

            $isExpanded  = ($Element.style -eq 'expanded')
            $isMultiSel  = ($Element.isMultiSelect -eq $true)
            $choices     = if ($Element.choices) { $Element.choices } else { @() }

            if ($isExpanded -and $isMultiSel) {
                # CheckedListBox
                $clb             = [System.Windows.Forms.CheckedListBox]::new()
                $clb.Name        = $Element.id
                $clb.Tag         = $Element.id
                $clb.Width       = $ctrlWidth
                $clb.Height      = [Math]::Min(160, ($choices.Count * 20) + 8)
                $clb.Font        = $inputFont
                $clb.CheckOnClick = $true
                foreach ($c in $choices) {
                    $idx = $clb.Items.Add($c.title)
                    if ($Element.value -and ($Element.value -split ',' | ForEach-Object { $_.Trim() }) -contains $c.value) {
                        $clb.SetItemChecked($idx, $true)
                    }
                }
                $clb.Tag = @{ Id = $Element.id; Choices = $choices; IsMulti = $true }
                $result.Control = $clb
            }
            elseif ($isExpanded -and -not $isMultiSel) {
                # Panel of RadioButtons
                $panel          = [System.Windows.Forms.Panel]::new()
                $panel.Name     = $Element.id
                $panel.Tag      = @{ Id = $Element.id; Choices = $choices; IsMulti = $false }
                $panel.Width    = $ctrlWidth
                $panel.Height   = ($choices.Count * 24) + 4
                $panel.AutoSize = $false
                $rbY = 0
                foreach ($c in $choices) {
                    $rb           = [System.Windows.Forms.RadioButton]::new()
                    $rb.Text      = $c.title
                    $rb.Tag       = $c.value
                    $rb.Font      = $inputFont
                    $rb.AutoSize  = $true
                    $rb.Location  = [System.Drawing.Point]::new(0, $rbY)
                    if ($Element.value -eq $c.value) { $rb.Checked = $true }
                    $panel.Controls.Add($rb)
                    $rbY += 24
                }
                $result.Control = $panel
            }
            else {
                # ComboBox (compact / default)
                $combo          = [System.Windows.Forms.ComboBox]::new()
                $combo.Name     = $Element.id
                $combo.Tag      = @{ Id = $Element.id; Choices = $choices; IsMulti = $false }
                $combo.Width    = $ctrlWidth
                $combo.Font     = $inputFont
                $combo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
                foreach ($c in $choices) {
                    $combo.Items.Add($c.title) | Out-Null
                }
                if ($Element.value) {
                    $selected = $choices | Where-Object { $_.value -eq $Element.value } | Select-Object -First 1
                    if ($selected) { $combo.SelectedItem = $selected.title }
                }
                $result.Control = $combo
            }
        }

        'Action.Submit' {
            $btn              = [System.Windows.Forms.Button]::new()
            $btn.Text         = if ($Element.title) { $Element.title } else { 'Submit' }
            $btn.Tag          = @{ Type = 'Submit'; Data = $Element.data }
            $btn.Font         = $inputFont
            $btn.AutoSize     = $true
            $btn.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $result.Control   = $btn
            $result.IsAction  = $true
        }

        'Action.OpenUrl' {
            $url              = $Element.url
            $btn              = [System.Windows.Forms.Button]::new()
            $btn.Text         = if ($Element.title) { $Element.title } else { 'Open' }
            $btn.Tag          = @{ Type = 'OpenUrl'; Url = $url }
            $btn.Font         = $inputFont
            $btn.AutoSize     = $true
            $btn.Add_Click({ Start-Process $url })
            $result.Control   = $btn
            $result.IsAction  = $true
        }

        'Action.Execute' {
            $btn              = [System.Windows.Forms.Button]::new()
            $btn.Text         = if ($Element.title) { $Element.title } else { 'Execute' }
            $btn.Tag          = @{ Type = 'Execute'; Verb = $Element.verb; Data = $Element.data }
            $btn.Font         = $inputFont
            $btn.AutoSize     = $true
            $result.Control   = $btn
            $result.IsAction  = $true
        }
    }

    return $result
}
