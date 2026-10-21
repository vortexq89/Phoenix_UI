local _, ns = ...

--[[ ns.Anim — tiny tween engine for the config UI. One driver frame whose OnUpdate only runs while
    tweens are active. Honors General → Reduce motion. Never used on in-world frames in combat. ]]
local A = {}
ns.Anim = A
local driver = CreateFrame("Frame")
local tweens = {}  -- key -> tween
local count = 0

local function ease(t) return 1 - (1 - t) ^ 3 end  -- easeOutCubic

local finished = {}
local function step(_, elapsed)
    for key, tw in pairs(tweens) do
        tw.t = tw.t + elapsed
        local p = math.min(1, tw.t / tw.d)
        tw.set(tw.from + (tw.to - tw.from) * ease(p))
        if p >= 1 then
            tweens[key] = nil
            count = count - 1
            if tw.done then finished[#finished + 1] = tw.done end
        end
    end
    -- callbacks run after the traversal so they may start new tweens safely
    for i = #finished, 1, -1 do
        local fn = finished[i]
        finished[i] = nil
        fn()
    end
    if count <= 0 then count = 0; driver:SetScript("OnUpdate", nil) end
end

function A:ReduceMotion()
    return ns.Theme.settings.reduceMotion
end

-- key: any unique value (usually the object); set(value) applies the interpolated value.
function A:Tween(key, duration, from, to, set, done)
    if tweens[key] then tweens[key] = nil; count = count - 1 end
    if duration <= 0 or self:ReduceMotion() then
        set(to)
        if done then done() end
        return
    end
    tweens[key] = { t = 0, d = duration, from = from, to = to, set = set, done = done }
    count = count + 1
    driver:SetScript("OnUpdate", step)
end

-- Colour lerp between two {r,g,b,a} tables.
function A:Color(key, duration, from, to, apply)
    local fr, fg, fb, fa = from[1], from[2], from[3], from[4] or 1
    local tr, tg, tb, ta = to[1], to[2], to[3], to[4] or 1
    self:Tween(key, duration, 0, 1, function(p)
        apply(fr + (tr - fr) * p, fg + (tg - fg) * p, fb + (tb - fb) * p, fa + (ta - fa) * p)
    end)
end

function A:FadeIn(frame, duration, slide)
    frame:SetAlpha(0)
    frame:Show()
    self:Tween(frame, duration or 0.16, 0, 1, function(v) frame:SetAlpha(v) end)
    if slide and frame.PUIAnchor then
        local a = frame.PUIAnchor
        self:Tween(a, duration or 0.16, slide, 0, function(v)
            frame:ClearAllPoints()
            frame:SetPoint(a[1], a[2], a[3], a[4], a[5] - v)
        end)
    end
end

function A:FadeOut(frame, duration)
    self:Tween(frame, duration or 0.12, frame:GetAlpha(), 0, function(v) frame:SetAlpha(v) end, function() frame:Hide() end)
end
