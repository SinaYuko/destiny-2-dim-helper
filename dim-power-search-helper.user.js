// ==UserScript==
// @name         DIM Power Search Helper
// @namespace    local.destiny2helper
// @version      1.23.0
// @description  Adds named DIM searches that automatically use your displayed maximum power.
// @homepageURL  https://github.com/SinaYuko/destiny-2-dim-helper
// @supportURL   https://github.com/SinaYuko/destiny-2-dim-helper/issues
// @updateURL    https://raw.githubusercontent.com/SinaYuko/destiny-2-dim-helper/main/dim-power-search-helper.user.js
// @downloadURL  https://raw.githubusercontent.com/SinaYuko/destiny-2-dim-helper/main/dim-power-search-helper.user.js
// @match        https://app.destinyitemmanager.com/*
// @match        https://beta.destinyitemmanager.com/*
// @match        https://destinyitemmanager.com/*
// @match        https://*.destinyitemmanager.com/*
// @grant        GM_getValue
// @grant        GM_setValue
// @run-at       document-idle
// ==/UserScript==

(() => {
  'use strict';

  const STORAGE_KEY = 'dim-power-search-helper-threshold';
  const HIDDEN_STORAGE_KEY = 'dim-power-search-helper-hidden';
  const MIN_POWER = 1;
  const MAX_POWER = 9999;
  let powerObserver = null;

  const searches = [
    {
      label: 'Trash Below Power',
      requiresPower: true,
      query: (power) =>
        `/* Below ${power} - Unlocked Trash Review */ is:equipment power:<${power} ` +
        '-is:uncommon -exactname:"Ergo Sum" -tier:>=4 -tag:favorite -tag:keep ' +
        '-tag:archive -is:locked',
    },
    {
      label: 'Tag Infusion Gear',
      requiresPower: true,
      query: (power) =>
        `/* Find Infusion Gear or Equipped Gear Needing Power */ is:equipment ` +
        `((power:>=${power} -is:locked) or (is:equipped power:<${power})) ` +
        '-is:uncommon -exactname:"Ergo Sum" -tag:keep -tag:favorite -tag:archive ' +
        '-tag:infuse',
    },
    {
      label: 'Untag Bad Infusion Gear',
      requiresPower: true,
      query: (power) =>
        `/* Untag Infusion Gear Below ${power} */ tag:infuse power:<${power} ` +
        '-is:uncommon -exactname:"Ergo Sum" -tier:>=4',
    },
    {
      label: 'Move Unequipped Gear to Vault',
      query: () =>
        '/* Move Unequipped Gear to Vault */ is:equipment is:movable -is:equipped -is:invault -is:postmaster',
    },
    {
      label: 'Duplicate Weapons',
      query: () =>
        '/* Duplicate Weapons */ is:weapon is:dupe -is:uncommon ' +
        '-exactname:"Ergo Sum" -tag:favorite -tag:archive',
    },
    {
      label: 'Trash Armor Below Tier 4',
      query: () =>
        '/* Armor Below Tier 4 Trash Review */ is:armor tier:<=3 ' +
        '-is:exotic -tag:favorite -tag:archive',
    },
    {
      label: 'Trash Armor Below Tier 5',
      query: () =>
        '/* Armor Below Tier 5 Trash Review */ is:armor tier:<=4 ' +
        '-is:uncommon -is:exotic -tag:favorite -tag:archive',
    },
    {
      label: 'Mark Tier 4 Armor Keep',
      query: () =>
        '/* Tier 4 Armor - Tag Keep Candidates */ is:armor tier:4 ' +
        '-is:exotic -tag:keep -tag:favorite',
    },
    {
      label: 'Mark Tier 5 Armor Favorite',
      query: () =>
        '/* Tier 5 Armor - Tag Favorite Candidates */ is:armor tier:5 ' +
        '-is:exotic -tag:favorite',
    },
    {
      label: 'Archive Tier 3 Armor Singles',
      query: () =>
        '/* Tier 3 Armor Without Duplicates - Archive Candidates */ ' +
        'is:armor tier:3 -is:dupe -is:exotic -tag:favorite -tag:archive',
    },
    {
      label: 'Duplicate Armor',
      query: () =>
        '/* Duplicate Armor */ is:armor is:dupe -is:uncommon ' +
        '-tag:favorite -tag:archive',
    },
    {
      label: 'Archived Gear With Replacement',
      query: () =>
        '/* Archived Gear With Another Copy - Compare Tiers */ is:equipment ' +
        'is:dupe tag:archive tier:<=3 -is:uncommon -exactname:"Ergo Sum"',
    },
    {
      label: 'Missing Catalysts',
      query: () =>
        '/* Missing Catalysts */ catalyst:missing -is:uncommon -exactname:"Ergo Sum"',
    },
    {
      label: 'Unfinished Catalysts',
      query: () =>
        '/* Unfinished Catalysts */ catalyst:incomplete -is:uncommon -exactname:"Ergo Sum"',
    },
    {
      label: 'Crafted Weapons Need Levels',
      query: () =>
        '/* Crafted Weapons Need Levels */ is:crafted weaponlevel:<17 -is:uncommon ' +
        '-exactname:"Ergo Sum"',
    },
  ];

  const panelStyles = `
    #dim-power-search-helper {
      position: fixed;
      right: 14px;
      bottom: 14px;
      z-index: 2147483647;
      width: 250px;
      max-height: calc(100vh - 28px);
      overflow-y: auto;
      padding: 12px;
      border: 1px solid rgba(255, 255, 255, 0.2);
      border-radius: 8px;
      background: rgba(20, 22, 27, 0.97);
      color: #fff;
      box-shadow: 0 5px 24px rgba(0, 0, 0, 0.45);
      font: 13px/1.35 system-ui, sans-serif;
    }
    #dim-power-search-helper * { box-sizing: border-box; }
    #dim-power-search-helper .dpsh-title {
      font-weight: 700;
    }
    #dim-power-search-helper .dpsh-header {
      margin-bottom: 8px;
    }
    #dim-power-search-helper .dpsh-title {
      margin-bottom: 8px;
    }
    #dim-power-search-helper .dpsh-row {
      display: flex;
      gap: 6px;
      margin-bottom: 7px;
    }
    #dim-power-search-helper input {
      min-width: 0;
      flex: 1;
      padding: 6px;
      border: 1px solid #626873;
      border-radius: 4px;
      background: #111318;
      color: #fff;
    }
    #dim-power-search-helper button {
      width: 100%;
      margin-top: 6px;
      padding: 7px;
      border: 0;
      border-radius: 4px;
      background: #4d78cc;
      color: #fff;
      cursor: pointer;
      font-weight: 600;
    }
    #dim-power-search-helper button:hover { background: #638ddd; }
    #dim-power-search-helper .dpsh-detect {
      width: auto;
      margin: 0;
      background: #50545d;
    }
    #dim-power-search-helper .dpsh-toggle {
      width: 100%;
      margin: 0;
      padding: 7px;
      border: 1px solid #9da4b2;
      background: #353942;
      font-size: 12px;
    }
    #dim-power-search-helper.dpsh-hidden {
      width: auto;
      max-height: none;
      overflow: visible;
      padding: 0;
      border: 0;
      background: transparent;
      box-shadow: none;
    }
    #dim-power-search-helper.dpsh-hidden .dpsh-header {
      margin: 0;
    }
    #dim-power-search-helper.dpsh-hidden .dpsh-title,
    #dim-power-search-helper.dpsh-hidden .dpsh-content {
      display: none;
    }
    #dim-power-search-helper.dpsh-hidden .dpsh-toggle {
      width: auto;
      padding: 8px 10px;
      background: #4d78cc;
      font-size: 12px;
    }
    #dim-power-search-helper .dpsh-status {
      min-height: 18px;
      margin-top: 8px;
      color: #c8cbd1;
      font-size: 12px;
    }
  `;

  let panel;
  let powerInput;
  let status;
  let buttons;
  let toggleButton;

  function validPower(value) {
    const number = Number.parseInt(String(value), 10);
    return number >= MIN_POWER && number <= MAX_POWER ? number : null;
  }

  function savedPower() {
    try {
      return validPower(GM_getValue(STORAGE_KEY, 348)) ?? 348;
    } catch {
      try {
        return validPower(localStorage.getItem(STORAGE_KEY)) ?? 348;
      } catch {
        return 348;
      }
    }
  }

  function savePower(power) {
    try {
      GM_setValue(STORAGE_KEY, power);
    } catch {
      try {
        localStorage.setItem(STORAGE_KEY, String(power));
      } catch {
        // The panel still works for this page even when storage is unavailable.
      }
    }
  }

  function savedHiddenState() {
    try {
      return Boolean(GM_getValue(HIDDEN_STORAGE_KEY, false));
    } catch {
      try {
        return localStorage.getItem(HIDDEN_STORAGE_KEY) === 'true';
      } catch {
        return false;
      }
    }
  }

  function saveHiddenState(hidden) {
    try {
      GM_setValue(HIDDEN_STORAGE_KEY, hidden);
    } catch {
      try {
        localStorage.setItem(HIDDEN_STORAGE_KEY, String(hidden));
      } catch {
        // The hide control still works for this page when storage is unavailable.
      }
    }
  }

  function setPanelHidden(hidden) {
    panel.classList.toggle('dpsh-hidden', hidden);
    toggleButton.textContent = hidden ? 'Show DIM Helper' : 'Hide Helper';
    toggleButton.setAttribute(
      'aria-label',
      hidden ? 'Show DIM Power Search Helper' : 'Hide DIM Power Search Helper',
    );
    toggleButton.setAttribute('aria-expanded', String(!hidden));
    saveHiddenState(hidden);
  }

  function setPower(power, message) {
    powerInput.value = String(power);
    savePower(power);
    status.textContent = message;
  }

  function detectDisplayedPower() {
    const accountPowerAttributes = document.querySelectorAll(
      '[aria-label*="account power" i], [title*="account power" i], ' +
      '[data-tooltip*="account power" i]',
    );

    for (const element of accountPowerAttributes) {
      const text = [
        element.getAttribute('aria-label'),
        element.getAttribute('title'),
        element.getAttribute('data-tooltip'),
        element.textContent,
      ]
        .filter(Boolean)
        .join(' ');

      const match = text.match(/account power[^\d]{0,30}([1-9]\d{0,3})/i);
      const power = match ? validPower(match[1]) : null;
      if (power) {
        return power;
      }
    }

    const textWalker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_TEXT,
    );

    while (textWalker.nextNode()) {
      const textNode = textWalker.currentNode;
      if (textNode.nodeValue?.trim().toLowerCase() !== 'account power') {
        continue;
      }

      const labelElement = textNode.parentElement;
      const accountPowerControl =
        labelElement?.closest('button, label, [role="radio"], [role="button"]') ||
        labelElement?.parentElement;
      const match = accountPowerControl?.textContent?.match(
        /account power[^\d]{0,30}([1-9]\d{0,3})/i,
      );
      const power = match ? validPower(match[1]) : null;
      if (power) {
        return power;
      }
    }

    return null;
  }

  function findSearchInput() {
    const inputs = [
      ...document.querySelectorAll(
        'input[type="search"], input[placeholder*="search" i], input[aria-label*="search" i]',
      ),
    ];
    return inputs.find((input) => input.offsetParent !== null) ?? inputs[0] ?? null;
  }

  function setNativeInputValue(input, value) {
    const valueSetter = Object.getOwnPropertyDescriptor(
      HTMLInputElement.prototype,
      'value',
    )?.set;
    valueSetter?.call(input, value);
    input.dispatchEvent(new InputEvent('input', {
      bubbles: true,
      inputType: value ? 'insertText' : 'deleteContentBackward',
      data: value || null,
    }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
  }

  function findClearSearchButton(input) {
    const searchArea = input.closest('form, [role="search"], [class*="search" i]') || input.parentElement;
    if (!searchArea) {
      return null;
    }

    const buttons = [...searchArea.querySelectorAll('button')];
    return buttons.find((button) => {
      const label = [
        button.getAttribute('aria-label'),
        button.getAttribute('title'),
        button.textContent,
      ]
        .filter(Boolean)
        .join(' ')
        .trim();
      return /clear|reset|remove/i.test(label);
    }) ?? null;
  }

  async function clearCurrentSearch(input) {
    input.focus();

    const clearButton = findClearSearchButton(input);
    if (clearButton) {
      clearButton.click();
      await new Promise((resolve) => window.setTimeout(resolve, 100));
    }

    // Select-all deletion follows the same input path as a user clearing DIM.
    input.dispatchEvent(new KeyboardEvent('keydown', {
      key: 'a',
      code: 'KeyA',
      ctrlKey: true,
      bubbles: true,
    }));
    input.dispatchEvent(new KeyboardEvent('keydown', {
      key: 'Backspace',
      code: 'Backspace',
      bubbles: true,
    }));
    setNativeInputValue(input, '');
    await new Promise((resolve) => window.setTimeout(resolve, 100));
  }

  async function runSearch(query) {
    const input = findSearchInput();
    if (!input) {
      status.textContent = 'Open the DIM Inventory page, then try again.';
      return;
    }

    await clearCurrentSearch(input);
    setNativeInputValue(input, query);
    input.focus();
    input.dispatchEvent(
      new KeyboardEvent('keydown', {
        key: 'Enter',
        code: 'Enter',
        bubbles: true,
      }),
    );
    status.textContent = `Loaded search using power ${powerInput.value}.`;
  }

  function getThreshold() {
    const power = validPower(powerInput.value);
    if (!power) {
      status.textContent = `Enter a power value from ${MIN_POWER} to ${MAX_POWER}.`;
      return null;
    }
    savePower(power);
    return power;
  }

  function mountPanel() {
    if (document.getElementById('dim-power-search-helper')) {
      return true;
    }
    if (!document.body) {
      return false;
    }

    if (!document.getElementById('dim-power-search-helper-styles')) {
      const style = document.createElement('style');
      style.id = 'dim-power-search-helper-styles';
      style.textContent = panelStyles;
      (document.head || document.documentElement).appendChild(style);
    }

    panel = document.createElement('section');
    panel.id = 'dim-power-search-helper';
    panel.innerHTML = `
      <div class="dpsh-header">
        <div class="dpsh-title">DIM Power Searches</div>
        <button class="dpsh-toggle" type="button" aria-expanded="true">Hide Helper</button>
      </div>
      <div class="dpsh-content">
        <div class="dpsh-row">
          <input class="dpsh-power" inputmode="numeric" aria-label="Power threshold">
          <button class="dpsh-detect" type="button">Detect</button>
        </div>
        <div class="dpsh-buttons"></div>
        <div class="dpsh-status" aria-live="polite"></div>
      </div>
    `;
    document.body.appendChild(panel);

    powerInput = panel.querySelector('.dpsh-power');
    status = panel.querySelector('.dpsh-status');
    buttons = panel.querySelector('.dpsh-buttons');
    toggleButton = panel.querySelector('.dpsh-toggle');

    toggleButton.addEventListener('click', () => {
      setPanelHidden(!panel.classList.contains('dpsh-hidden'));
    });
    setPanelHidden(savedHiddenState());

    for (const search of searches) {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = search.label;
      button.addEventListener('click', () => {
        if (!search.requiresPower) {
          runSearch(search.query());
          return;
        }

        const power = getThreshold();
        if (power !== null) {
          runSearch(search.query(power));
        }
      });
      buttons.appendChild(button);
    }

    panel.querySelector('.dpsh-detect').addEventListener('click', () => {
      const detected = detectDisplayedPower();
      if (detected) {
        setPower(detected, `Detected displayed maximum power: ${detected}.`);
      } else {
        status.textContent = 'Could not detect it. Enter the number once; it will be remembered.';
      }
    });

    powerInput.addEventListener('change', () => {
      const power = getThreshold();
      if (power) {
        status.textContent = `Saved power threshold: ${power}.`;
        powerObserver?.disconnect();
      }
    });

    const initialDetectedPower = detectDisplayedPower();
    if (initialDetectedPower) {
      setPower(initialDetectedPower, `Detected displayed maximum power: ${initialDetectedPower}.`);
    } else {
      setPower(savedPower(), 'Using saved power. Waiting for DIM to finish loading.');
      powerObserver = new MutationObserver(() => {
        const detected = detectDisplayedPower();
        if (detected) {
          setPower(detected, `Detected displayed maximum power: ${detected}.`);
          powerObserver?.disconnect();
        }
      });
      powerObserver.observe(document.body, {
        childList: true,
        subtree: true,
        characterData: true,
      });
      window.setTimeout(() => powerObserver?.disconnect(), 30000);
    }

    return true;
  }

  if (!mountPanel()) {
    const mountTimer = window.setInterval(() => {
      if (mountPanel()) {
        window.clearInterval(mountTimer);
      }
    }, 500);
    window.setTimeout(() => window.clearInterval(mountTimer), 30000);
  }

  // DIM is a single-page app and can replace page containers during navigation.
  // Restore the helper if a rerender removes it.
  window.setInterval(() => {
    if (!document.getElementById('dim-power-search-helper')) {
      powerObserver?.disconnect();
      powerObserver = null;
      mountPanel();
    }
  }, 2000);
})();
