local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- SecretTag: recognises Midnight secret-value error signatures.
local S = PUI.Sentinel
local SecretTag = {}
S.SecretTag = SecretTag

SecretTag.SIGNATURES = {
  "attempt to compare",          -- "... a secret value" variants
  "secret value",
  "secret string",
  "cannot be accessed when secret",
  "attempt to perform arithmetic on a secret",
  "attempt to index a secret",
  "attempt to concatenate a secret",
}

function SecretTag:IsSecretError(message)
  if type(message) ~= "string" then return false end
  local lower = message:lower()
  if not lower:find("secret", 1, true) then return false end
  for i = 1, #self.SIGNATURES do
    if lower:find(self.SIGNATURES[i], 1, true) then return true end
  end
  return false
end
