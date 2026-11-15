"""Phoenix chrome icon set v3 (original work, Phoenix UI licence): UI chrome only - micro menu, settings navigation,
GUI tabs, macro window controls, window controls. Never used for class, spec, ability, spell or item icons.
Style: 24-unit grid, 2-unit safe margin, 1.75 stroke, round caps and joins, outline only, one tint (the theme
colours it in game). Writes one SVG per icon to tools/media/chrome/ and a contact sheet."""
import os, sys, cairosvg
OUT = os.path.join(os.path.dirname(__file__), 'chrome')
P = {
# --- micro menu (one per Blizzard micro button, same order as MainMenuBarMicroButtons.xml)
'micro-character':   '<circle cx="12" cy="8" r="3.5"/><path d="M5 20c0-3.9 3.1-7 7-7s7 3.1 7 7"/>',
'micro-professions': '<path d="M14.5 4.5l5 5-2 2-5-5z"/><path d="M13.5 8.5L5 17l2 2 8.5-8.5"/><path d="M4 20l1-3 2 2z"/>',
'micro-spells':      '<path d="M5 4h11a3 3 0 013 3v13H8a3 3 0 01-3-3z"/><path d="M5 17a3 3 0 013-3h11"/><path d="M11 6.5l1 2 2 .5-2 .5-1 2-1-2-2-.5 2-.5z"/>',
'micro-achievements':'<path d="M8 4h8v5a4 4 0 01-8 0z"/><path d="M8 6H5a3 3 0 003 4M16 6h3a3 3 0 01-3 4"/><path d="M12 13v4M8.5 20h7M10 17h4"/>',
'micro-quests':      '<path d="M7 3.5h8l3 3V20H7z"/><path d="M15 3.5V7h3"/><path d="M10 11h5M10 14h5M10 17h3"/>',
'micro-housing':     '<path d="M4 11l8-6.5 8 6.5"/><path d="M6 9.5V20h12V9.5"/><path d="M10 20v-5h4v5"/>',
'micro-guild':       '<path d="M6 4h12v9c0 3.5-2.7 6-6 7.5C8.7 19 6 16.5 6 13z"/><path d="M12 7.5v8M9 10.5h6"/>',
'micro-groupfinder': '<circle cx="9" cy="9" r="3"/><circle cx="16.5" cy="10" r="2.5"/><path d="M3.5 19c0-3 2.5-5.5 5.5-5.5s5.5 2.5 5.5 5.5"/><path d="M15 14.2c2.9-.4 5.5 1.7 5.5 4.8"/>',
'micro-collections': '<path d="M4 7l8-3.5L20 7v10l-8 3.5L4 17z"/><path d="M4 7l8 3.5L20 7M12 10.5v10"/>',
'micro-journal':     '<path d="M4 5.5c2.5-1 5.5-1 8 .5v14c-2.5-1.5-5.5-1.5-8-.5z"/><path d="M20 5.5c-2.5-1-5.5-1-8 .5v14c2.5-1.5 5.5-1.5 8-.5z"/>',
'micro-help':        '<circle cx="12" cy="12" r="8"/><path d="M9.6 9.5a2.5 2.5 0 114 2c-1 .7-1.6 1.2-1.6 2.5"/><circle cx="12" cy="17" r=".6" fill="currentColor"/>',
'micro-shop':        '<path d="M4 8h16l-1.5 12h-13z"/><path d="M8.5 8V6.5a3.5 3.5 0 017 0V8"/>',
'micro-menu':        '<path d="M5 7h14M5 12h14M5 17h14"/>',
# --- settings navigation / GUI tabs
'nav-home':      '<path d="M4 11l8-6.5 8 6.5"/><path d="M6.5 9.5V20h11V9.5"/>',
'nav-bars':      '<rect x="3.5" y="9" width="5" height="6" rx="1"/><rect x="9.5" y="9" width="5" height="6" rx="1"/><rect x="15.5" y="9" width="5" height="6" rx="1"/>',
'nav-frames':    '<rect x="3.5" y="5" width="17" height="6" rx="1.5"/><path d="M5.5 8h8"/><rect x="3.5" y="14" width="11" height="5" rx="1.5"/>',
'nav-interface': '<rect x="3.5" y="4.5" width="17" height="15" rx="2"/><path d="M3.5 9h17M9 9v10.5"/>',
'nav-combat':    '<path d="M5 19L17.5 6.5M14 5h4v4"/><path d="M19 19L6.5 6.5M10 5H6v4"/><path d="M4 20l2-2M20 20l-2-2"/>',
'nav-content':   '<path d="M12 3.5l2.4 5 5.6.8-4 3.9.9 5.5-4.9-2.6-4.9 2.6.9-5.5-4-3.9 5.6-.8z"/>',
'nav-windows':   '<rect x="3.5" y="4" width="12" height="10" rx="1.5"/><path d="M8.5 17.5V19a1.5 1.5 0 001.5 1.5h9a1.5 1.5 0 001.5-1.5v-7a1.5 1.5 0 00-1.5-1.5h-1.5"/>',
'nav-systems':   '<path d="M9 3.5v4M15 3.5v4"/><rect x="6" y="7.5" width="12" height="6" rx="1.5"/><path d="M12 13.5v3a3 3 0 01-3 3H8"/>',
'nav-phoenix':   '<path d="M12 4c1.5 3 4.5 4 4.5 8a4.5 4.5 0 01-9 0c0-1.6.7-2.8 1.5-3.6.2 1.4 1 2.3 2 2.6-.6-2.6 0-5 1-7z"/><path d="M12 20v-3"/>',
'nav-profiles':  '<circle cx="9" cy="9" r="3"/><path d="M3.5 19c0-3 2.5-5.5 5.5-5.5"/><path d="M14 14.5h6.5M14 18h6.5M14 11h6.5"/>',
'nav-look':      '<path d="M12 4a8 8 0 100 16c1.1 0 1.6-.8 1.3-1.7-.4-1 .3-2.3 1.5-2.3H17a3 3 0 003-3 8 8 0 00-8-9z"/><circle cx="8" cy="11" r="1" fill="currentColor"/><circle cx="11" cy="7.5" r="1" fill="currentColor"/><circle cx="15.5" cy="8.5" r="1" fill="currentColor"/>',
'nav-support':   '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3.5"/><path d="M6.3 6.3l3.2 3.2M14.5 14.5l3.2 3.2M17.7 6.3l-3.2 3.2M9.5 14.5l-3.2 3.2"/>',
'tab-layout':    '<rect x="4" y="4" width="7" height="7" rx="1.2"/><rect x="13" y="4" width="7" height="4" rx="1.2"/><rect x="13" y="10" width="7" height="10" rx="1.2"/><rect x="4" y="13" width="7" height="7" rx="1.2"/>',
'tab-appearance':'<path d="M14.5 4.5l5 5L10 19H5v-5z"/><path d="M12.5 6.5l5 5"/>',
'tab-text':      '<path d="M5 6.5V5h14v1.5M12 5v14M9 19h6"/>',
'tab-behaviour': '<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/>',
'tab-colours':   '<circle cx="9" cy="9.5" r="4.5"/><circle cx="15" cy="9.5" r="4.5"/><circle cx="12" cy="14.5" r="4.5"/>',
# --- macro window chrome (the macros' own icons are the player's chosen game icons and are never replaced)
'macro-general':   '<path d="M3.5 12h3M17.5 12h3"/><path d="M7.5 8l-3 4 3 4M16.5 8l3 4-3 4"/><path d="M13.5 6l-3 12"/>',
'macro-character': '<circle cx="9" cy="8.5" r="3"/><path d="M3.5 19c0-3 2.5-5.5 5.5-5.5s5.5 2.5 5.5 5.5"/><path d="M15.5 9.5l1.5-1.5 1.5 1.5-1.5 1.5zM17 4.5v2M17 12v2M20.5 9.5h-2M15 9.5h-1.5" />',
'macro-new':       '<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M12 8v8M8 12h8"/>',
'macro-delete':    '<path d="M5 7h14M10 7V5h4v2"/><path d="M6.5 7l1 13h9l1-13"/><path d="M10 11v5M14 11v5"/>',
'macro-rename':    '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13 7l4 4"/>',
'macro-save':      '<path d="M5 4h11l3 3v13H5z"/><path d="M8 4v5h7V4"/><rect x="8" y="13" width="8" height="7" rx="1"/>',
# --- window controls
'win-close':   '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
'win-move':    '<path d="M12 3.5v17M3.5 12h17"/><path d="M9.5 6L12 3.5 14.5 6M9.5 18l2.5 2.5 2.5-2.5M6 9.5L3.5 12 6 14.5M18 9.5l2.5 2.5-2.5 2.5"/>',
'win-settings':'<circle cx="12" cy="12" r="3"/><path d="M12 3.5v2.5M12 18v2.5M3.5 12H6M18 12h2.5M6 6l1.8 1.8M16.2 16.2L18 18M18 6l-1.8 1.8M7.8 16.2L6 18"/>',
'win-search':  '<circle cx="10.5" cy="10.5" r="6"/><path d="M15 15l5 5"/>',
'win-filter':  '<path d="M4 5h16l-6 7.5V19l-4-2v-4.5z"/>',
'win-lock':    '<rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 018 0v2.5"/>',
'win-reset':   '<path d="M5 12a7 7 0 107-7c-2.3 0-4.3 1.1-5.6 2.8"/><path d="M5.5 3.5v4.5H10"/>',
'win-favorite':'<path d="M12 19.5s-7.5-4.3-7.5-9.7A4.3 4.3 0 0112 7.3a4.3 4.3 0 017.5 2.5c0 5.4-7.5 9.7-7.5 9.7z"/>',
'win-expand':  '<path d="M8 10l4 4 4-4"/>',
}
def svg(body, col='#000', sw=1.75, size=24):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" '
            f'stroke="{col}" color="{col}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">{body}</svg>')
if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for k, b in P.items():
        open(os.path.join(OUT, k + '.svg'), 'w').write(svg(b, '#FFFFFF') + '\n')
    print(len(P), 'icons ->', OUT)
