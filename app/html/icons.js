// the line icons of the application: 16 px, stroke 1.5, round caps (one family)
var CC_ICONS = {
  overview: '<rect x="2.5" y="2.5" width="4.5" height="4.5" rx="1"/><rect x="9" y="2.5" width="4.5" height="4.5" rx="1"/><rect x="2.5" y="9" width="4.5" height="4.5" rx="1"/><rect x="9" y="9" width="4.5" height="4.5" rx="1"/>',
  reproduce: '<path d="M13 8a5 5 0 1 1-1.5-3.6"/><path d="M13 2.5v3h-3"/>',
  run: '<path d="M5 3l8 5-8 5z"/>',
  compare: '<rect x="2.5" y="2.5" width="11" height="11" rx="1"/><path d="M2.5 6.2h11M2.5 9.8h11M6.2 2.5v11M9.8 2.5v11"/>',
  scenarios: '<path d="M8 14s4.5-4.2 4.5-7.5a4.5 4.5 0 0 0-9 0C3.5 9.8 8 14 8 14z"/><circle cx="8" cy="6.5" r="1.6"/>',
  model: '<path d="M8 1.8l5.5 3.1v6.2L8 14.2l-5.5-3.1V4.9z"/><path d="M2.5 4.9L8 8l5.5-3.1M8 8v6.2"/>',
  provenance: '<circle cx="3.5" cy="8" r="1.8"/><circle cx="12.5" cy="8" r="1.8"/><path d="M5.3 8h5.4"/>',
  about: '<circle cx="8" cy="8" r="5.8"/><path d="M8 7.2v3.8M8 5h.01"/>',
  help: '<circle cx="8" cy="8" r="5.8"/><path d="M6.3 6.2a1.8 1.8 0 1 1 2.4 1.7c-.5.2-.7.6-.7 1.1v.3M8 11.3h.01"/>',
  shield: '<path d="M8 1.8l5 2v4c0 3.2-2.2 5.3-5 6.4-2.8-1.1-5-3.2-5-6.4v-4z"/>',
  collapse: '<path d="M3 3v10M13 4.5L9.5 8 13 11.5"/>',
  chev: '<path d="M6 3.5L10.5 8 6 12.5"/>'
};
function ccIcon(name, extra) {
  return '<svg class="icon ' + (extra || '') + '" viewBox="0 0 16 16">' + (CC_ICONS[name] || '') + '</svg>';
}
