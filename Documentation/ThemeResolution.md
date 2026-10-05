# Theme resolution cases

Persist three separate concepts in one `ThemeStoredState` snapshot:

- `selectedThemeID`: the user's committed preference, including a Pro preference retained after expiry.
- `committedThemeID`: the applied base theme to restore on launch.
- `previewThemeID` and `previewExpiresAt`: a temporary override with an absolute deadline.

`lastKnownHasPro` supports appearance restoration and legacy migration; purchases remain the authority for access. A preview never becomes the base merely because it is visible.

## Launch and access

| Case | Expected appearance | Saved preference / base |
| --- | --- | --- |
| First launch, no saved state | Free fallback while checking | Fallback / fallback |
| Saved Free selection, checking | Saved Free base | Unchanged |
| Saved Pro selection and Pro base, checking | Saved Pro base until verification | Unchanged |
| Saved Pro preference and Free base, checking | Free base; no resurrection of the Pro preference | Unchanged |
| Cached Pro flag with an existing Free base | Free base while checking | Unchanged |
| Checking repeats, or products are still loading | Keep base and valid preview | No access transition is committed |
| Pro resolves active, preference is Free | Selected Free theme | Free preference / Free theme |
| Pro resolves active, preference is Pro | Selected Pro theme | Pro preference / Pro theme |
| Access resolves Free, preference is Free | Selected Free theme | Free preference / Free theme |
| Pro expires or is revoked, preference is Pro | Free fallback after verification | Retain Pro preference / save Free fallback and Free access metadata together |
| Kill and relaunch after that Free commit | Free immediately, including while checking | Retain Pro preference / Free base |
| Renewal or restore after expiry | Retained Pro preference, unless superseded by a new selection | Pro preference / Pro theme |
| Verified offline policy grants effective Pro while raw StoreKit state is inactive | Apply the preference using effective `PurchaseManager.hasPro` | Same rules as active Pro |
| Product catalog loading fails | Access resolution still determines the theme | Save resolved access independently of product loading |

## User selection and previews

| Case | Expected appearance | Persistence and deadline |
| --- | --- | --- |
| Select Free while checking or resolved | Selected Free immediately | Replace preference and base; clear preview; later renewal keeps this choice |
| Select Pro while checking | Keep current appearance | Do not change state; picker is disabled and programmatic selection returns `requiresPro` |
| Select Pro with confirmed Pro access | Selected Pro immediately | Replace preference and base; clear preview |
| Select Pro as a Free user, previews enabled | Preview the requested theme | Keep preference and base; save preview with its deadline |
| Select Pro with previews disabled or zero duration | Keep base; request upgrade | No preview or preference change |
| Switch preview, default behavior | New preview theme | Keep the original deadline and base |
| Switch preview, restart duration configured | New preview theme | Save a new deadline; keep base |
| End preview explicitly | Committed base, including a custom Free theme | Clear preview only |
| Preview reaches its deadline, including exactly at expiry | Committed base | Clear expired preview; do not commit it |
| Relaunch during a valid preview | Resume preview while checking | Preserve the absolute deadline; no extra time |
| Relaunch or foreground after preview expiry | Committed base | Remove expired preview |
| Free access resolves during preview | Continue valid preview | Preserve deadline, preference, and base |
| Purchase pending, cancelled, or failed | Continue valid preview | No promotion, no deadline restart, no access grant |
| Purchase or restore succeeds during valid preview, promotion enabled | Keep preview appearance without an intermediate Free theme | Promote preview to preference and base; clear preview in the same commit |
| Purchase succeeds during preview, promotion disabled | Apply the existing preference using Pro access | Keep preference; commit its permitted base; clear preview |
| Purchase resolves at or after preview expiry | Apply existing preference | Expired preview is never promoted |
| Retained Pro preference plus a different preview, then unlock | Valid preview wins if promotion is enabled; otherwise retained preference wins | Commit the chosen theme and clear preview together |
| Preview feature disabled after a previous launch | Committed base | Remove saved preview |
| Reset while Pro, Free, checking, or previewing | Free fallback | Reset preference and base; clear preview; preserve access metadata |

## Storage, catalog, and ownership

| Case | Expected behavior |
| --- | --- |
| Legacy JSON lacks `committedThemeID` | Derive the base once from the old preference and saved access flag, then save the new snapshot |
| Legacy JSON lacks access flag | Default to Free; retain a valid Pro preference for later verified renewal |
| Missing or unreadable snapshot | Start from Free fallback |
| Selected theme removed from catalog | Normalize preference to fallback |
| Committed theme removed, or becomes inaccessible | Normalize base to fallback; keep any other valid preference |
| Preview theme removed, becomes Free, or lacks a valid deadline | Discard the preview |
| Custom catalog and fallback | Apply the same rules; catalog guarantees a Free fallback |
| Widget reads state | Resolve committed base plus valid preview without writing; schedule an entry at preview expiry |
| `refreshFromPersistence()` reads a newer snapshot | Read without writing an old access result back; checking adopts saved presentation, resolved owner reapplies its current access in memory |
| Themed view unmounts | Lifetime purchase binding still saves access transitions before entitlement refresh returns |
| Theme or purchase owner replaced | Rebind to the new owners; the old purchase owner no longer changes the theme |
| Theme owner released | Purchase binding holds it weakly and discards its dead callback |

Use one writable `ThemeManager` per storage key. Persistence stores a single snapshot before emitting the theme callback; it does not provide conflict resolution for multiple independent writers. As with any local storage, a process killed before the first resolved access commit cannot restore a result it never saved.
