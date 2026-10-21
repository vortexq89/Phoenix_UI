local _, ns = ...

--[[ ns.Secret — the single gate for Midnight secret values (Patch 12.0.0, "Secret values" on warcraft.wiki.gg).
    A value reported secret may be passed to display sinks (SetText, SetValue, SetTexture …) but never
    compared, tested, used in arithmetic or stored. ]]
ns.Secret = {
    IsSecret = issecretvalue,
}
