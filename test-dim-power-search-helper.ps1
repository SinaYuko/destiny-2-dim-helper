$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'dim-power-search-helper.user.js'
$content = Get-Content -Raw -LiteralPath $scriptPath

$requiredFragments = @(
    '// @version      1.13.0'
    '// @updateURL    https://raw.githubusercontent.com/SinaYuko/destiny-2-dim-helper/main/dim-power-search-helper.user.js'
    '// @downloadURL  https://raw.githubusercontent.com/SinaYuko/destiny-2-dim-helper/main/dim-power-search-helper.user.js'
    '// @match        https://*.destinyitemmanager.com/*'
    '/* Below ${power} - Unlocked Trash Review */ is:equipment power:<${power}'
    '-is:uncommon -exactname:"Ergo Sum" -tier:>=4 -tag:favorite -tag:keep'
    '-tag:archive -is:locked'
    '/* Find Infusion Gear or Equipped Gear Needing Power */ is:equipment'
    '((power:>=${power} -is:locked) or (is:equipped power:<${power}))'
    '[aria-label*="account power" i]'
    "textNode.nodeValue?.trim().toLowerCase() !== 'account power'"
    '/* Untag Infusion Gear Below ${power} */ tag:infuse power:<${power}'
    '-is:uncommon -exactname:"Ergo Sum" -tier:>=4'
    '/* Move Unequipped Gear to Vault */ is:equipment is:movable -is:equipped -is:invault -is:postmaster'
    '/* Duplicate Weapons */ is:weapon is:dupe -is:uncommon'
    '-exactname:"Ergo Sum" -tag:favorite -tag:archive'
    '/* Unlocked Armor Below Tier 5 Trash Review */ is:armor tier:<=4'
    '-is:uncommon -tag:favorite -tag:keep -tag:archive -is:locked'
    '/* Duplicate Armor */ is:armor is:dupe -is:uncommon'
    '/* Archived Gear With Another Copy - Compare Tiers */ is:equipment'
    'is:dupe tag:archive tier:<=3 -is:uncommon -exactname:"Ergo Sum"'
    '/* Missing Catalysts */ catalyst:missing -is:uncommon -exactname:"Ergo Sum"'
    '/* Unfinished Catalysts */ catalyst:incomplete -is:uncommon -exactname:"Ergo Sum"'
    '/* Crafted Weapons Need Levels */ is:crafted weaponlevel:<17 -is:uncommon'
    'if (!search.requiresPower)'
    'bottom: 14px'
    'max-height: calc(100vh - 28px)'
    "const HIDDEN_STORAGE_KEY = 'dim-power-search-helper-hidden'"
    "toggleButton.textContent = hidden ? 'Show DIM Helper' : 'Hide Helper'"
    "hidden ? 'Show DIM Power Search Helper' : 'Hide DIM Power Search Helper'"
    "panel.classList.toggle('dpsh-hidden', hidden)"
    'setPanelHidden(savedHiddenState())'
    "if (!document.getElementById('dim-power-search-helper'))"
)

foreach ($fragment in $requiredFragments) {
    if (-not $content.Contains($fragment)) {
        throw "Missing expected userscript fragment: $fragment"
    }
}

$powerSearchCount = ([regex]::Matches($content, 'requiresPower:\s*true')).Count
if ($powerSearchCount -ne 3) {
    throw "Expected exactly 3 power-dependent searches, found $powerSearchCount."
}

$uncommonExclusionCount = ([regex]::Matches($content, '-is:uncommon')).Count
if ($uncommonExclusionCount -ne 10) {
    throw "Expected 10 searches to exclude Uncommon gear, found $uncommonExclusionCount."
}

$ergoSumExclusionCount = ([regex]::Matches($content, '-exactname:"Ergo Sum"')).Count
if ($ergoSumExclusionCount -ne 8) {
    throw "Expected 8 searches to exclude Ergo Sum, found $ergoSumExclusionCount."
}

$archiveExclusionCount = ([regex]::Matches($content, '-tag:archive')).Count
if ($archiveExclusionCount -ne 5) {
    throw "Expected 5 searches to protect Archive gear, found $archiveExclusionCount."
}

$moveQuery = '/* Move Unequipped Gear to Vault */ is:equipment is:movable -is:equipped -is:invault -is:postmaster'
if (
    -not $content.Contains($moveQuery) -or
    $moveQuery.Contains('-is:uncommon') -or
    $moveQuery.Contains('-exactname:"Ergo Sum"')
) {
    throw 'The movement search must include Uncommon gear and Ergo Sum.'
}

Write-Output 'DIM Power Search Helper checks passed.'
