$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'dim-power-search-helper.user.js'
$content = Get-Content -Raw -LiteralPath $scriptPath

$requiredFragments = @(
    '// @version      1.29.0'
    '// @updateURL    https://raw.githubusercontent.com/SinaYuko/destiny-2-dim-helper/main/dim-power-search-helper.user.js'
    '// @downloadURL  https://raw.githubusercontent.com/SinaYuko/destiny-2-dim-helper/main/dim-power-search-helper.user.js'
    '// @match        https://*.destinyitemmanager.com/*'
    '/* Below ${power} - Unlocked Trash Review */ is:equipment power:<${power}'
    '-is:uncommon -exactname:"Ergo Sum" -tier:>=4 -tag:favorite -tag:keep'
    '-tag:archive -is:locked'
    '/* Junk Tag Trash Review */ tag:junk'
    '/* Find Infusion Gear or Equipped Gear Needing Power */ is:equipment'
    '((power:>=${power} -is:locked) or (is:equipped power:<${power}))'
    '[aria-label*="account power" i]'
    "textNode.nodeValue?.trim().toLowerCase() !== 'account power'"
    '/* Untag Infusion Gear Below ${power} */ tag:infuse power:<${power}'
    '-is:uncommon -exactname:"Ergo Sum" -tier:>=4'
    '/* Move Unequipped Gear to Vault */ is:equipment is:movable -is:equipped -is:invault -is:postmaster'
    '/* Duplicate Weapons */ is:weapon is:dupe -is:uncommon'
    '-exactname:"Ergo Sum" -tag:favorite -tag:archive'
    '/* Weapons Below Tier 4 Trash Review */ is:weapon tier:<=3'
    '-is:exotic -tag:favorite'
    '/* Weapons Below Tier 5 Trash Review */ is:weapon tier:<=4'
    '-is:uncommon -is:exotic -tag:favorite'
    '/* Armor Below Tier 4 Trash Review */ is:armor tier:<=3'
    '-is:exotic -tag:favorite -tag:archive'
    '/* Armor Below Tier 5 Trash Review */ is:armor tier:<=4'
    '-is:uncommon -is:exotic -tag:favorite -tag:archive'
    '/* Archived Armor Below Tier 4 Cleanup */ is:armor tier:<=3'
    '-is:exotic tag:archive -tag:favorite'
    '/* Archived Armor Below Tier 5 Cleanup */ is:armor tier:<=4'
    '-is:uncommon -is:exotic tag:archive -tag:favorite'
    '/* Tier 4 Armor - Tag Keep Candidates */ is:armor tier:4'
    '-is:exotic -tag:keep -tag:favorite'
    '/* Tier 5 Armor - Tag Favorite Candidates */ is:armor tier:5'
    '-is:exotic -tag:favorite'
    '/* Tier 3 Armor Without Duplicates - Archive Candidates */'
    'is:armor tier:3 -is:dupe -is:exotic -tag:favorite -tag:archive'
    '/* Duplicate Armor */ is:armor is:dupe -is:uncommon'
    '/* Archived Gear With Another Copy - Compare Tiers */ is:equipment'
    'is:dupe tag:archive tier:<=3 -is:uncommon -exactname:"Ergo Sum"'
    '/* Missing Catalysts */ catalyst:missing -is:uncommon -exactname:"Ergo Sum"'
    '/* Unfinished Catalysts */ catalyst:incomplete -is:uncommon -exactname:"Ergo Sum"'
    '/* Crafted Weapons Need Levels */ is:crafted weaponlevel:<17 -is:uncommon'
    'if (!search.requiresPower)'
    'bottom: 14px'
    'max-height: calc(100vh - 28px)'
    'width: min(980px, calc(100vw - 28px))'
    'grid-template-columns: repeat(4, minmax(0, 1fr))'
    "section.className = 'dpsh-section'"
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
if ($uncommonExclusionCount -ne 12) {
    throw "Expected 12 searches to exclude Uncommon gear, found $uncommonExclusionCount."
}

$ergoSumExclusionCount = ([regex]::Matches($content, '-exactname:"Ergo Sum"')).Count
if ($ergoSumExclusionCount -ne 8) {
    throw "Expected 8 searches to exclude Ergo Sum, found $ergoSumExclusionCount."
}

$archiveExclusionCount = ([regex]::Matches($content, [regex]::Escape('-tag:archive'))).Count
if ($archiveExclusionCount -ne 7) {
    throw "Expected 7 searches to protect Archive gear, found $archiveExclusionCount."
}

$positiveArchiveCount = ([regex]::Matches($content, '(?<!-)tag:archive')).Count
if ($positiveArchiveCount -ne 3) {
    throw "Expected 3 searches to intentionally include Archive gear, found $positiveArchiveCount."
}

$junkCleanupMatch = [regex]::Match(
    $content,
    "label:\s*'Tagged Junk'.*?query:\s*\(\)\s*=>\s*'([^']+)'",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $junkCleanupMatch.Success) {
    throw 'Could not find the Junk cleanup query.'
}

$junkCleanupQuery = $junkCleanupMatch.Groups[1].Value
if ($junkCleanupQuery -ne '/* Junk Tag Trash Review */ tag:junk') {
    throw "Junk cleanup must only search tag:junk, found: $junkCleanupQuery"
}

$weaponTierFourCleanupMatch = [regex]::Match(
    $content,
    "label:\s*'Trash Weapons Below Tier 4'.*?query:\s*\(\)\s*=>\s*'([^']+)'\s*\+\s*'([^']+)'",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $weaponTierFourCleanupMatch.Success) {
    throw 'Could not find the weapon Tier 4 cleanup query.'
}

$weaponTierFourCleanupQuery = $weaponTierFourCleanupMatch.Groups[1].Value + $weaponTierFourCleanupMatch.Groups[2].Value
foreach ($requiredFilter in @('is:weapon tier:<=3', '-is:exotic', '-tag:favorite')) {
    if (-not $weaponTierFourCleanupQuery.Contains($requiredFilter)) {
        throw "Weapon Tier 4 cleanup must include $requiredFilter."
    }
}
foreach ($blockedFilter in @('-tag:archive', '-tag:keep', '-is:locked', '-exactname:"Ergo Sum"')) {
    if ($weaponTierFourCleanupQuery.Contains($blockedFilter)) {
        throw "Weapon Tier 4 cleanup must not hide $blockedFilter."
    }
}

$weaponTierFiveCleanupMatch = [regex]::Match(
    $content,
    "label:\s*'Trash Weapons Below Tier 5'.*?query:\s*\(\)\s*=>\s*'([^']+)'\s*\+\s*'([^']+)'",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $weaponTierFiveCleanupMatch.Success) {
    throw 'Could not find the weapon Tier 5 cleanup query.'
}

$weaponTierFiveCleanupQuery = $weaponTierFiveCleanupMatch.Groups[1].Value + $weaponTierFiveCleanupMatch.Groups[2].Value
foreach ($requiredFilter in @('is:weapon tier:<=4', '-is:uncommon', '-is:exotic', '-tag:favorite')) {
    if (-not $weaponTierFiveCleanupQuery.Contains($requiredFilter)) {
        throw "Weapon Tier 5 cleanup must include $requiredFilter."
    }
}
foreach ($blockedFilter in @('-tag:archive', '-tag:keep', '-is:locked', '-exactname:"Ergo Sum"')) {
    if ($weaponTierFiveCleanupQuery.Contains($blockedFilter)) {
        throw "Weapon Tier 5 cleanup must not hide $blockedFilter."
    }
}

$tierFourCleanupMatch = [regex]::Match(
    $content,
    "label:\s*'Trash Armor Below Tier 4'.*?query:\s*\(\)\s*=>\s*'([^']+)'\s*\+\s*'([^']+)'",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $tierFourCleanupMatch.Success) {
    throw 'Could not find the Tier 4 cleanup query.'
}

$tierFourCleanupQuery = $tierFourCleanupMatch.Groups[1].Value + $tierFourCleanupMatch.Groups[2].Value
foreach ($blockedProtection in @('-is:uncommon', '-exactname:"Ergo Sum"', '-tag:keep', '-is:locked')) {
    if ($tierFourCleanupQuery.Contains($blockedProtection)) {
        throw "Tier 4 cleanup must not skip $blockedProtection."
    }
}
if (-not $tierFourCleanupQuery.Contains('-tag:archive')) {
    throw 'Tier 4 cleanup must respect Archive-tagged gear.'
}
if (-not $tierFourCleanupQuery.Contains('-is:exotic')) {
    throw 'Tier 4 cleanup must ignore Exotics.'
}
if (-not $tierFourCleanupQuery.Contains('is:armor tier:<=3')) {
    throw 'Tier 4 cleanup must be armor-only.'
}
if ($tierFourCleanupQuery.Contains('is:equipment')) {
    throw 'Tier 4 cleanup must not target all equipment.'
}

$armorCleanupMatch = [regex]::Match(
    $content,
    "label:\s*'Trash Armor Below Tier 5'.*?query:\s*\(\)\s*=>\s*'([^']+)'\s*\+\s*'([^']+)'",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $armorCleanupMatch.Success) {
    throw 'Could not find the armor cleanup query.'
}

$armorCleanupQuery = $armorCleanupMatch.Groups[1].Value + $armorCleanupMatch.Groups[2].Value
foreach ($blockedProtection in @('-tag:keep', '-is:locked')) {
    if ($armorCleanupQuery.Contains($blockedProtection)) {
        throw "Armor cleanup must not skip $blockedProtection."
    }
}
if (-not $armorCleanupQuery.Contains('-tag:archive')) {
    throw 'Armor cleanup must respect Archive-tagged gear.'
}
if (-not $armorCleanupQuery.Contains('-is:exotic')) {
    throw 'Armor cleanup must ignore Exotics.'
}

$archivedTierFourCleanupMatch = [regex]::Match(
    $content,
    "label:\s*'Clean Archived Armor Below Tier 4'.*?query:\s*\(\)\s*=>\s*'([^']+)'\s*\+\s*'([^']+)'",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $archivedTierFourCleanupMatch.Success) {
    throw 'Could not find the archived Tier 4 cleanup query.'
}

$archivedTierFourCleanupQuery = $archivedTierFourCleanupMatch.Groups[1].Value + $archivedTierFourCleanupMatch.Groups[2].Value
foreach ($requiredFilter in @('is:armor tier:<=3', '-is:exotic', 'tag:archive', '-tag:favorite')) {
    if (-not $archivedTierFourCleanupQuery.Contains($requiredFilter)) {
        throw "Archived Tier 4 cleanup must include $requiredFilter."
    }
}
if ($archivedTierFourCleanupQuery.Contains('-is:locked')) {
    throw 'Archived Tier 4 cleanup must not hide locked armor.'
}

$archivedTierFiveCleanupMatch = [regex]::Match(
    $content,
    "label:\s*'Clean Archived Armor Below Tier 5'.*?query:\s*\(\)\s*=>\s*'([^']+)'\s*\+\s*'([^']+)'",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $archivedTierFiveCleanupMatch.Success) {
    throw 'Could not find the archived Tier 5 cleanup query.'
}

$archivedTierFiveCleanupQuery = $archivedTierFiveCleanupMatch.Groups[1].Value + $archivedTierFiveCleanupMatch.Groups[2].Value
foreach ($requiredFilter in @('is:armor tier:<=4', '-is:uncommon', '-is:exotic', 'tag:archive', '-tag:favorite')) {
    if (-not $archivedTierFiveCleanupQuery.Contains($requiredFilter)) {
        throw "Archived Tier 5 cleanup must include $requiredFilter."
    }
}
if ($archivedTierFiveCleanupQuery.Contains('-is:locked')) {
    throw 'Archived Tier 5 cleanup must not hide locked armor.'
}

$tierFourKeepMatch = [regex]::Match(
    $content,
    "label:\s*'Mark Tier 4 Armor Keep'.*?query:\s*\(\)\s*=>\s*'([^']+)'\s*\+\s*'([^']+)'",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $tierFourKeepMatch.Success) {
    throw 'Could not find the Tier 4 Keep-tag query.'
}

$tierFourKeepQuery = $tierFourKeepMatch.Groups[1].Value + $tierFourKeepMatch.Groups[2].Value
foreach ($requiredFilter in @('is:armor tier:4', '-is:exotic', '-tag:keep', '-tag:favorite')) {
    if (-not $tierFourKeepQuery.Contains($requiredFilter)) {
        throw "Tier 4 Keep-tag candidates must include $requiredFilter."
    }
}
foreach ($blockedFilter in @('-tag:archive', '-is:locked')) {
    if ($tierFourKeepQuery.Contains($blockedFilter)) {
        throw "Tier 4 Keep-tag candidates must not hide $blockedFilter."
    }
}

$tierFiveFavoriteMatch = [regex]::Match(
    $content,
    "label:\s*'Mark Tier 5 Armor Favorite'.*?query:\s*\(\)\s*=>\s*'([^']+)'\s*\+\s*'([^']+)'",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $tierFiveFavoriteMatch.Success) {
    throw 'Could not find the Tier 5 Favorite-tag query.'
}

$tierFiveFavoriteQuery = $tierFiveFavoriteMatch.Groups[1].Value + $tierFiveFavoriteMatch.Groups[2].Value
foreach ($requiredFilter in @('is:armor tier:5', '-is:exotic', '-tag:favorite')) {
    if (-not $tierFiveFavoriteQuery.Contains($requiredFilter)) {
        throw "Tier 5 Favorite-tag candidates must include $requiredFilter."
    }
}
foreach ($blockedFilter in @('-tag:archive', '-is:locked')) {
    if ($tierFiveFavoriteQuery.Contains($blockedFilter)) {
        throw "Tier 5 Favorite-tag candidates must not hide $blockedFilter."
    }
}

$archiveSinglesMatch = [regex]::Match(
    $content,
    "label:\s*'Archive Tier 3 Armor Singles'.*?query:\s*\(\)\s*=>\s*'([^']+)'\s*\+\s*'([^']+)'",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $archiveSinglesMatch.Success) {
    throw 'Could not find the Tier 3 archive candidate query.'
}

$archiveSinglesQuery = $archiveSinglesMatch.Groups[1].Value + $archiveSinglesMatch.Groups[2].Value
foreach ($requiredFilter in @('is:armor tier:3', '-is:dupe', '-is:exotic', '-tag:favorite', '-tag:archive')) {
    if (-not $archiveSinglesQuery.Contains($requiredFilter)) {
        throw "Tier 3 archive candidates must include $requiredFilter."
    }
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
