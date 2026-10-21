"""Phoenix icon names -> Phosphor duotone glyphs (tools/media/phosphor/<glyph>-duotone.svg).
Order is the atlas order; append new icons at the end so existing indices stay stable."""
ICONS = [
    # navigation: pages and modules
    ("home", "house"), ("general", "palette"), ("skins", "paint-brush"), ("actionbars", "squares-four"),
    ("unitframes", "user-square"), ("groupframes", "users-three"), ("castbars", "hourglass-medium"),
    ("auras", "sparkle"), ("nameplates", "identification-badge"), ("tooltip", "chat-centered-text"),
    ("itemlevel", "shield-star"), ("minimap", "compass"), ("datatexts", "chart-bar"), ("cooldowntext", "timer"),
    ("combattext", "text-aa"), ("damagemeter", "chart-bar-horizontal"), ("spellhistory", "clock-counter-clockwise"),
    ("pvp", "sword"), ("chat", "chat-circle-dots"), ("afk", "moon-stars"), ("quality", "magic-wand"),
    ("automation", "robot"), ("mythicplus", "key"), ("profiles", "user-switch"), ("about", "info"),
    # sidebar categories
    ("cat-system", "gear-six"), ("cat-interface", "layout"), ("cat-combat", "crosshair"), ("cat-social", "users"),
    ("cat-utility", "wrench"), ("cat-phoenix", "fire"),
    # actions and controls
    ("search", "magnifying-glass"), ("close", "x"), ("reload", "arrow-clockwise"), ("editmode", "arrows-out-cardinal"),
    ("check", "check"), ("chevron-right", "caret-right"), ("chevron-down", "caret-down"), ("export", "export"),
    ("import", "download-simple"), ("copy", "copy"), ("duplicate", "copy-simple"), ("add", "plus"),
    ("delete", "trash"), ("reset", "arrow-counter-clockwise"), ("rename", "pencil-simple"), ("preview", "eye"),
    ("resize", "arrow-down-right"), ("link", "link"), ("github", "github-logo"), ("web", "globe"),
    ("terminal", "terminal-window"), ("heart", "heart"), ("addon", "puzzle-piece"), ("user", "user"),
    ("spec", "swap"), ("lock", "lock-simple"), ("warning", "warning"), ("success", "check-circle"),
    ("error", "x-circle"), ("theme", "paint-bucket"),
    # data bar
    ("fps", "gauge"), ("latency", "wifi-high"), ("speed", "person-simple-run"), ("durability", "shield"),
    ("gold", "coins"), ("clock", "clock"),
    # fallback for unknown names
    ("question", "question"),
    # bugs (error catcher)
    ("bugs", "bug"), ("taint", "shield-warning"), ("upload", "cloud-arrow-up"), ("bell", "bell-ringing"),
    ("sound", "speaker-high"), ("fingerprint", "fingerprint"), ("filter", "funnel"), ("chevron-left", "caret-left"),
    # movers
    ("movers", "frame-corners"), ("grid", "grid-four"), ("snap", "magnet"), ("opacity", "circle-half"),
    ("arrow-up", "arrow-up"), ("arrow-down", "arrow-down"), ("arrow-left", "arrow-left"), ("arrow-right", "arrow-right"),
    # mythic+ timer
    ("boss", "crown-simple"), ("deaths", "skull"), ("forces", "users-four"),
    # chat
    ("keyboard", "keyboard"),
]
