# bh-ps-adaptive

A **PowerShell module** that generates a Windows Forms UI from an
[Adaptive Cards](https://adaptivecards.io/) JSON structure, and ships a
**local MCP (Model Context Protocol) server** so AI assistants such as
Claude or GitHub Copilot can collect structured user input through
form-like dialogs.

This module was created with AI-Assistance for speed.
This module is currently in Beta, until I completely verified. Use at your own peril.

---

## Features

| Feature | Description |
| --- | --- |
| `ConvertFrom-AdaptiveCard` | Parse an Adaptive Card JSON and return field metadata — no UI needed |
| `Invoke-AdaptiveCardUI` | Render the card as a WinForms dialog and return the submitted values |
| `Start-AdaptiveCardMCPServer` | Start a stdio MCP server exposing form generation as AI-callable tools |

### Supported Adaptive Card elements

| Element | WinForms control |
| --- | --- |
| `TextBlock` | `Label` |
| `Input.Text` | `TextBox` (multiline when `isMultiline: true`, password when `style: password`) |
| `Input.Number` | `NumericUpDown` |
| `Input.Date` | `DateTimePicker` (date mode) |
| `Input.Time` | `DateTimePicker` (time/spin mode) |
| `Input.Toggle` | `CheckBox` |
| `Input.ChoiceSet` (compact) | `ComboBox` |
| `Input.ChoiceSet` (expanded, single) | `Panel` of `RadioButton` controls |
| `Input.ChoiceSet` (expanded, multi) | `CheckedListBox` |
| `Action.Submit` | `Button` (DialogResult = OK) |
| `Action.OpenUrl` | `Button` (opens URL in default browser) |
| `Container` / `ColumnSet` / `Column` | Recursively flattened |

---

## Requirements

- **PowerShell 7.5+**
- **Windows** for `Invoke-AdaptiveCardUI` (requires `System.Windows.Forms`)
- `ConvertFrom-AdaptiveCard` and `Start-AdaptiveCardMCPServer` are
  cross-platform

---

## Installation

```powershell
# Clone and import directly
git clone https://github.com/ArieHein/bh-ps-adaptive.git
Import-Module .\bh-ps-adaptive\PSAdaptiveCards\PSAdaptiveCards.psd1
```

---

## Usage

### 1 — Parse a card (no UI)

```powershell
$meta = ConvertFrom-AdaptiveCard -Path .\Examples\sample-form.json
$meta.Inputs | Format-Table Id, Type, Label, IsRequired
```

### 2 — Show a form and collect values

```powershell
$values = Invoke-AdaptiveCardUI -Path .\Examples\sample-form.json

# Or from a JSON string
$json = Get-Content .\Examples\sample-form.json -Raw
$values = Invoke-AdaptiveCardUI -Json $json

if ($values) {
    $values | ConvertTo-Json
}
```

### 3 — Start the MCP server

The server speaks **JSON-RPC 2.0 over stdio** (the standard MCP stdio transport).

```powershell
Start-AdaptiveCardMCPServer
```

#### Claude Desktop integration

Add the following to your Claude Desktop `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "adaptive-cards": {
      "command": "pwsh",
      "args": [
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        "Import-Module 'C:\\path\\to\\PSAdaptiveCards\\PSAdaptiveCards.psd1'; Start-AdaptiveCardMCPServer"
      ]
    }
  }
}
```

Once connected, ask the AI: *"Show the user a registration form using this
Adaptive Card JSON …"* and the server will render the WinForms dialog and
return the submitted values to the AI.

#### MCP tools exposed

| Tool | Description |
| --- | --- |
| `generate_form` | Render a card JSON as a WinForms dialog; returns submitted values |
| `parse_card` | Return field metadata without showing any UI |
| `validate_card` | Check whether a string is valid Adaptive Card JSON |
| `list_element_types` | List all supported element types |

---

## Examples

See the [`Examples/`](./Examples/) directory:

- `sample-form.json` — User registration card with all input types
- `sample-deploy.json` — Deployment configuration card
- `example-usage.ps1` — Script that exercises all three functions

---

## Tests

```powershell
# Install Pester if needed
Install-Module Pester -Force -SkipPublisherCheck

# Run tests
Invoke-Pester .\Tests\PSAdaptiveCards.Tests.ps1 -Output Detailed
```

---

## Repository layout

```
PSAdaptiveCards/
├── PSAdaptiveCards.psd1          Module manifest
├── PSAdaptiveCards.psm1          Module root (dot-sources all functions)
├── Private/
│   ├── Get-AdaptiveCardElements.ps1   Flatten nested card body
│   ├── New-WinFormControl.ps1         Map AC element → WinForms control
│   └── Show-AdaptiveCardForm.ps1      Build & show the form dialog
└── Public/
    ├── ConvertFrom-AdaptiveCard.ps1   Parse card JSON → field metadata
    ├── Invoke-AdaptiveCardUI.ps1      Show form, return submitted values
    └── Start-AdaptiveCardMCPServer.ps1  stdio MCP server
Examples/
├── sample-form.json
├── sample-deploy.json
└── example-usage.ps1
Tests/
└── PSAdaptiveCards.Tests.ps1
```
