# Profile Page Design

## Overview

A public profile page at `/profile/:username` showing the user's posts, votes, and reputation progression.

## Routes

```ruby
get "/profile/:username", to: "profiles#show", as: :profile
```

The `:username` param is the user's `slug` (parameterized username).

## Controller: ProfilesController

- `allow_unauthenticated_access` (public profiles)
- `show` action loads:
  - `@user` — found by slug
  - `@posts` — tab-scoped post collection (default: user's own approved posts, newest first)
  - `@thresholds` — all `ReputationThreshold` ordered by `min_reputation`
  - `@earned` — thresholds the profile owner has earned (based on `@user.reputation`)
  - `@next` — next unearned milestone for the profile owner

### Tab scoping

The `params[:tab]` value controls which posts are shown:

| `tab` | Query |
|-------|-------|
| (nil or "posts") | `@user.posts.approved.order(created_at: :desc)` |
| `upvoted` | `Post.joins(:votes).where(votes: { user: @user, upvoted: true }).approved.order(created_at: :desc)` |
| `downvoted` | `Post.joins(:votes).where(votes: { user: @user, upvoted: false }).approved.order(created_at: :desc)` |
| `commented` | `Post.joins(:comments).where(comments: { user_id: @user.id }).approved.distinct.order(created_at: :desc)` |

## View: app/views/profiles/show.html.erb

Structured in two sections:

### 1. Profile Header

- Avatar placeholder (initials circle)
- Username, join date
- Reputation number (large, amber)
- **Reputation bar**: horizontal bar from 1 (left) to 10,000 (right), filled to current reputation
- **Privilege badges**: all reputation thresholds displayed as pills; earned ones are green, locked ones are gray; the next milestone is highlighted with an amber border and label "Next at NNNN rep"

### 2. Tabbed Post Grid

Four tabs: **Posts** | **Upvoted** | **Downvoted** | **Commented**

Controlled by a Stimulus controller (`profile-tabs`) that toggles visibility:
- All sections rendered server-side (no lazy loading)
- Only the active tab's section is visible
- Each section renders posts as card grid (reuses `_post_card` partial)
- Empty state: "No posts yet" message

### Stimulus Controller: profile-tabs

```js
static targets = ["panel"]
static values = { active: String }

show(event) {
  const tab = event.currentTarget.dataset.tab
  this.activeValue = tab
}

activeValueChanged() {
  this.panelTargets.forEach(p => {
    p.classList.toggle("hidden", p.dataset.tab !== this.activeValue)
  })
}
```

Tab buttons use `data-action="profile-tabs#show"` and `data-tab="posts"`. Panels use `data-profile-tabs-target="panel"` and `data-tab="posts"`.

## Nav Link

In `app/views/layouts/application.html.erb`, change:
```erb
<%= link_to "Profile", "#" %>
```
to:
```erb
<%= link_to "Profile", profile_path(current_user.slug) if Current.user %>
```

## Testing

Tests in `test/system/gagstack_test.rb` under a `# ── Profile ──` section:

- `"visitor can view a user's profile and see their posts"` — visit profile, assert post titles visible
- `"profile tabs filter posts by type"` — switch to upvoted/downvoted/commented tabs, assert correct content
- `"profile shows reputation and milestones"` — verify reputation number, earned badges, next milestone text
- `"profile 404s for unknown username"` — visit `/profile/nonexistent`, assert 404

## Future Considerations (not in scope)

- Avatar upload
- Profile bio / description
- Edit profile page
- Private profiles
