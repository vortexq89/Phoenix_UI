# Original Phoenix window-category icons: 24 grid, 1.6 stroke, round caps. Phoenix UI original work.
import os
OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','media','svg')
P={
'character':'<circle cx="12" cy="7.5" r="3.5"/><path d="M5 20c.8-4 3.6-6 7-6s6.2 2 7 6"/>',
'spellbook':'<path d="M4 5.5C6.5 4.5 9.5 4.5 12 6c2.5-1.5 5.5-1.5 8-.5V19c-2.5-1-5.5-1-8 .5-2.5-1.5-5.5-1.5-8-.5z"/><path d="M12 6v13.5"/><path d="M15.5 9.5l1 1.6 1.8.3-1.3 1.3.3 1.8-1.8-.9"/>',
'talents':'<circle cx="6" cy="6" r="2.2"/><circle cx="18" cy="6" r="2.2"/><circle cx="12" cy="12" r="2.2"/><circle cx="12" cy="19" r="2.2"/><path d="M7.6 7.6l2.8 2.8M16.4 7.6l-2.8 2.8M12 14.2v2.6"/>',
'collections':'<path d="M12 3l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.4 6.8 19.1l1-5.8L3.5 9.2l5.9-.9z"/>',
'mounts':'<path d="M4 18l2-6 4-3 2-4 2 2 3 1 2 3-2 1-2-1-1 3 1 4"/><path d="M8 18v-3M15 18v-3"/>',
'pets':'<circle cx="7" cy="9" r="1.8"/><circle cx="17" cy="9" r="1.8"/><circle cx="10" cy="5.5" r="1.6"/><circle cx="14" cy="5.5" r="1.6"/><path d="M8 17c0-3 2-5 4-5s4 2 4 5c0 2-2 2.5-4 2.5S8 19 8 17z"/>',
'toys':'<rect x="5" y="9" width="14" height="10" rx="2"/><path d="M12 9v10M5 13h14M12 9c-1-3-4-4-5-2s2 2 5 2c3 0 6 0 5-2s-4-1-5 2"/>',
'heirlooms':'<path d="M12 3l6 4v5c0 4-2.6 7-6 9-3.4-2-6-5-6-9V7z"/><path d="M9 12l2 2 4-4"/>',
'transmog':'<path d="M9 4l3 2 3-2 4 3-2 3-2-1v11H9V9L7 10 5 7z"/>',
'groupfinder':'<circle cx="11" cy="11" r="6"/><path d="M15.5 15.5L20 20"/><circle cx="9" cy="10" r="1.2"/><circle cx="13" cy="10" r="1.2"/><path d="M8.5 13.2c1.5 1 3.5 1 5 0"/>',
'social':'<circle cx="9" cy="8" r="3"/><circle cx="17" cy="9" r="2.4"/><path d="M3.5 19c.6-3.3 2.8-5 5.5-5s4.9 1.7 5.5 5M14.5 14.6c2.6-.4 5 1 5.8 4.4"/>',
'loot':'<path d="M4 10h16v9a1 1 0 01-1 1H5a1 1 0 01-1-1z"/><path d="M4 10l2-5h12l2 5M10 13h4"/>',
'bags':'<path d="M6 8h12l1 12H5z"/><path d="M9 8V6a3 3 0 016 0v2"/>',
'merchant':'<path d="M4 9l1.5-4h13L20 9"/><path d="M4 9c0 1.7 1.3 3 2.7 3S9.3 10.7 9.3 9c0 1.7 1.2 3 2.7 3s2.7-1.3 2.7-3c0 1.7 1.2 3 2.6 3S20 10.7 20 9M5.5 12v8h13v-8M10 20v-4h4v4"/>',
'mail':'<rect x="3.5" y="6" width="17" height="12" rx="2"/><path d="M4 7l8 6 8-6"/>',
'auction':'<path d="M13 4l5 5-3 3-5-5z"/><path d="M11.5 10.5L5 17l2 2 6.5-6.5M4 21h9"/>',
'professions':'<path d="M14.5 4.5a4 4 0 00-4.9 5L4 15.1 6.9 18l5.6-5.6a4 4 0 005-4.9l-2.4 2.4-2.1-.6-.6-2.1z"/>',
'achievements':'<path d="M8 4h8v5a4 4 0 01-8 0z"/><path d="M8 6H5a3 3 0 003 4M16 6h3a3 3 0 01-3 4M12 13v4M8.5 20h7M10 17h4v3h-4z"/>',
'journal':'<path d="M6 3.5h11a1 1 0 011 1V20H7a2 2 0 01-2-2V5a1.5 1.5 0 011-1.5z"/><path d="M5 17.5A1.5 1.5 0 016.5 16H18M10 8.5c0-1.4 1-2 2-2s2 .6 2 2c0 1.2-1 1.4-1 2.5M12 13h.01"/>',
'map':'<path d="M3.5 6.5l5.5-2 6 2 5.5-2v13l-5.5 2-6-2-5.5 2z"/><path d="M9 4.5v13M15 6.5v13"/>',
'calendar':'<rect x="4" y="5.5" width="16" height="14" rx="2"/><path d="M4 10h16M8.5 3.5v4M15.5 3.5v4M8 14h2M14 14h2M8 17h2"/>',
'guild':'<path d="M5 4h14v8c0 4-3 6.5-7 8-4-1.5-7-4-7-8z"/><path d="M9 9l3-2 3 2v4l-3 2-3-2z"/>',
'menu':'<circle cx="12" cy="12" r="3"/><path d="M12 3.5v2.2M12 18.3v2.2M3.5 12h2.2M18.3 12h2.2M6 6l1.6 1.6M16.4 16.4L18 18M6 18l1.6-1.6M16.4 7.6L18 6"/>',
'tooltip':'<path d="M4 5h16v11h-8l-4 4v-4H4z"/><path d="M8 9h8M8 12h5"/>',
'pvp':'<path d="M5 4l9 9M4 8V4h4M19 4l-9 9M20 8V4h-4M7 14l-3 3 3 3 3-3M17 14l3 3-3 3-3-3"/>',
'vault':'<rect x="4" y="5" width="16" height="14" rx="2"/><circle cx="12" cy="12" r="3.2"/><path d="M12 8.8v1.2M12 14v1.2M15.2 12H14M10 12H8.8M7 19v1.5M17 19v1.5"/>',
'housing':'<path d="M4 11l8-6.5 8 6.5"/><path d="M6 9.5V20h12V9.5M10 20v-5h4v5"/>',
'editmode':'<rect x="4" y="4" width="7" height="7" rx="1.2"/><rect x="13" y="13" width="7" height="7" rx="1.2"/><path d="M13 7.5h7M7.5 13v7M17.5 4v6M4 17.5h6" stroke-dasharray="2 2"/>',
'popup':'<rect x="3.5" y="5" width="17" height="13" rx="2.5"/><path d="M12 8.5v4.5M12 15.5h.01"/>',
'readycheck':'<circle cx="12" cy="12" r="8.5"/><path d="M8 12.3l2.7 2.7L16.3 9.4"/>',
}
os.makedirs(OUT,exist_ok=True)
for k,v in P.items():
    open(os.path.join(OUT,f'pui_{k}.svg'),'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="#ECE8E2" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><!-- Phoenix UI original icon: {k}. (c) VortexQ8, All Rights Reserved --><g>{v}</g></svg>')
print(len(P))
