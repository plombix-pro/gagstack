# GagStack

A Rails 8 imageboard / meme aggregator — think 9GAG meets a self-hosted
content feed. Users browse a curated stream of images and GIFs, vote, comment,
and flag content, while a lightweight reputation and moderation system keeps the
firehose usable.

GagStack is built API-first: every feature available in the UI is also exposed
through a versioned JSON API, so the same backend can power a mobile app or a
third-party client.

## Features

- **Infinite feed** with cursor-based pagination and three sort modes —
  `hot`, `trending`, and `fresh`. A "Load More" button appends the next page
  via Turbo Streams (no full reload).
- **Posts** with image / GIF media (Active Storage + image processing) and
  title, body (Action Text), and tags.
- **Categories** to organize content, with NSFW categories hidden from
  unauthenticated visitors.
- **Voting** on posts and comments (counter-culture gem `counter_culture`
  keeps tallies denormalized and fast).
- **Comments** with nested replies.
- **Flagging** for spam / abuse, surfaced in a moderator queue.
- **Reputation system** with configurable thresholds. New users have their
  first 5 posts held for moderation (`pending`); once they have 5 approved
  posts, subsequent posts are published immediately.
- **NSFW gating** — NSFW posts and categories are invisible (and URLs
  redirect to the root) for logged-out users.
- **Keyboard navigation** on a post's show page (← / → to move between
  posts) plus click-to-fullscreen media.
- **Authentication** with sessions, registrations, email verification, and
  password reset.
- **Moderation & Admin** dashboards: review flags, approve/remove posts,
  manage users, categories, reputation thresholds, and site-wide
  announcements.
- **JSON API** (`/api/v1`) with token auth for posts, categories, and profiles.
- **Real-content seeding** — `seed_real` pulls from Reddit (48 subreddits +
  `/r/popular`, hot & top) and 4chan (7 boards) so the app launches with a
  populated feed instead of Lorem Ipsum.

## Tech Stack

| Concern        | Choice                                            |
| -------------- | ------------------------------------------------- |
| Framework      | Ruby on Rails 8.1                                 |
| Language       | Ruby 3.x                                          |
| Database       | PostgreSQL                                        |
| Frontend       | Hotwire (Turbo + Stimulus), Importmap, Propshaft  |
| Styling        | Tailwind CSS                                      |
| Realtime       | Solid Cable (Action Cable adapter)                |
| Jobs           | Solid Queue                                       |
| Cache          | Solid Cache                                       |
| Auth           | BCrypt passwords, sessions                        |
| Pagination     | Kaminari (UI) + custom cursor logic (API/feed)    |
| Security       | Rack::Attack (rate limiting), Brakeman in CI      |

## Requirements

- Ruby 3.1+ (see `.ruby-version`)
- PostgreSQL
- Node.js (for Tailwind / asset tooling at build time)

## Getting Started

```bash
# 1. Install dependencies
bundle install

# 2. Set up the database
bin/rails db:create db:migrate

# 3. (Optional) Seed with real content from Reddit + 4chan
bin/rails seed_real

# 4. Start the server
bin/rails server
```

Open <http://localhost:3000>.

### Seeding options

`seed_real` accepts environment variables to tune volume and speed:

```bash
USERS_COUNT=300 \
MAX_PER_SUBREDDIT=50 \
MAX_REDDIT_POPULAR=100 \
MAX_PER_4CHAN=40 \
PAUSE=0.5 \
bin/rails seed_real
```

## Running the Test Suite

```bash
bin/rails test
```

## Project Layout

- `app/services/feed_builder.rb` — builds the paginated, sortable post feed
  and applies NSFW / cursor logic.
- `app/controllers/{posts,categories,mod,admin,api}/*` — UI, moderation,
  admin, and JSON API entry points.
- `lib/tasks/seed_real.rake` — the Reddit / 4chan content importer.
- `app/javascript/controllers/*` — Stimulus controllers (e.g. keyboard
  navigation).

## Deployment

GagStack ships with Kamal and Thruster configuration for zero-downtime Docker
deployments. See `config/deploy.yml` and the Kamal docs for setup.

## License

TODO: add your license.
