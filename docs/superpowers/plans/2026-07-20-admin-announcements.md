# Admin Announcements (Notes) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let admins create rich-text Announcements (Notes) that render as a full-width, primary-color–outlined banner at the top of the moderator panel whenever `active` is true.

**Architecture:** A new `Announcement` model (ActionText rich body + boolean `active` + author) backed by an admin CRUD controller that logs to `ModerationLog`. The moderator layout renders all active announcements as full-width banners above `<main>`. Rich text uses ActionText (Trix), which we enable by uncommenting `action_text/engine` and running its installer.

**Tech Stack:** Rails 8.1, PostgreSQL, Tailwind v4, ActionText/Trix, Stimulus (importmap), RSpec-free Minitest.

---

## File Structure

- `config/application.rb` — uncomment `action_text/engine` (Task 1).
- `Gemfile` — ensure `actiontext` is available (Task 1, `bundle add`).
- `db/migrate/YYYYMMDDHHMMSS_create_announcements.rb` — `announcements` table + `action_text_rich_texts` (from installer) + FK (Task 2).
- `app/models/announcement.rb` — `has_rich_text :content`, `belongs_to :author`, `active` boolean, scopes, validations, logging callback (Task 3).
- `app/controllers/admin/announcements_controller.rb` — `before_action :require_admin`; index/new/create/edit/update/destroy; each mutation writes a `ModerationLog` (Task 4).
- `config/routes.rb` — `resources :announcements` inside `namespace :admin` (Task 5).
- `app/views/admin/announcements/index.html.erb` — list with active toggle + edit/destroy links (Task 6).
- `app/views/admin/announcements/new.html.erb` — form with Trix editor (Task 6).
- `app/views/admin/announcements/edit.html.erb` — same form (Task 6).
- `app/views/admin/announcements/_form.html.erb` — shared form partial (Task 6).
- `app/views/shared/_announcement_banner.html.erb` — full-width banner partial rendering one announcement (Task 7).
- `app/views/layouts/application.html.erb` — render all active banners between `</nav>` and `<main>` (Task 7).
- `app/views/admin/dashboard/index.html.erb` — add "Announcements" quick-action link (Task 8).
- `app/javascript/controllers/index.js` — register `trix` import from ActionText (installer handles; verify in Task 1).
- `test/models/announcement_test.rb` — model tests (Task 3).
- `test/controllers/admin/announcements_controller_test.rb` — request tests (Task 4).
- `test/system/admin_announcements_test.rb` — end-to-end banner + create test (Task 9).

---

### Task 1: Enable ActionText

**Files:**
- Modify: `config/application.rb:12`
- Modify: `Gemfile` (add `gem "actiontext"` if absent)
- Run: `bin/rails action_text:install`

- [ ] **Step 1: Uncomment the engine and add the gem**

Edit `config/application.rb`:
```ruby
require "action_text/engine"
```

Add to `Gemfile` (only if not already present — check first):
```ruby
gem "actiontext"
```
Then run:
```bash
bundle install
```

- [ ] **Step 2: Run the ActionText installer**

Run: `bin/rails action_text:install`

Expected: creates `app/javascript/controllers/index.js` edit (imports `trix`), adds `app/assets/stylesheets/actiontext.css` (or similar) and an `action_text:install` migration note; may print "Action Text was successfully installed". Confirm `app/javascript/controllers/index.js` now contains a `trix` import line.

- [ ] **Step 3: Verify the app still boots and tests run**

Run: `bin/rails runner 'puts ActionText::Engine.present?'`
Expected: `true`

Run: `bin/rails test`
Expected: all existing tests still pass (no regressions).

- [ ] **Step 4: Commit**

```bash
git add config/application.rb Gemfile Gemfile.lock db app/javascript/controllers/index.js
git commit -m "chore: enable ActionText (Trix) for rich-text announcements"
```

---

### Task 2: Migration for Announcements

**Files:**
- Create: `db/migrate/$(date +%Y%m%d%H%M%S)_create_announcements.rb`

- [ ] **Step 1: Write the migration**

Generate a timestamped filename, e.g. `db/migrate/20260720120000_create_announcements.rb`:
```ruby
class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.boolean :active, default: true, null: false
      t.bigint :author_id, null: false
      t.timestamps
    end
    add_foreign_key :announcements, :users, column: :author_id
  end
end
```
(The `action_text:install` step added the `action_text_rich_texts` table and `has_rich_text :content` will use it — no column needed on `announcements` itself.)

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`

Expected: `Announcements` and `action_text_rich_texts` tables created. Confirm with:
```bash
bin/rails runner 'puts ActiveRecord::Base.connection.table_exists?(:announcements)'
```
Expected: `true`

- [ ] **Step 3: Commit**

```bash
git add db/migrate/*_create_announcements.rb db/schema.rb
git commit -m "feat: add announcements table"
```

---

### Task 3: Announcement model + tests

**Files:**
- Create: `app/models/announcement.rb`
- Test: `test/models/announcement_test.rb`

- [ ] **Step 1: Write the failing model test**

`test/models/announcement_test.rb`:
```ruby
require "test_helper"

class AnnouncementTest < ActiveSupport::TestCase
  test "is active by default" do
    a = Announcement.new(author: users(:one))
    assert a.active?
  end

  test "active scope returns only active announcements" do
    active = Announcement.create!(author: users(:one), active: true)
    inactive = Announcement.create!(author: users(:one), active: false)
    assert_includes Announcement.active, active
    refute_includes Announcement.active, inactive
  end

  test "requires an author" do
    a = Announcement.new(active: true)
    assert_not a.valid?
    assert_includes a.errors[:author], "must exist"
  end

  test "logs a moderation entry on create" do
    assert_difference -> { ModerationLog.where(action: "announcement_created").count }, 1 do
      Announcement.create!(author: users(:one), active: true)
    end
  end
end
```
(Replace `users(:one)` with a fixture/admin user that exists in `test/fixtures/users.yml`. If fixtures are absent, create one in `test/fixtures/users.yml` named `admin` with `role: admin` and `reputation: 5000`.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/models/announcement_test.rb`
Expected: FAIL — `Announcement` / `active` scope / fixtures missing.

- [ ] **Step 3: Implement the model**

`app/models/announcement.rb`:
```ruby
class Announcement < ApplicationRecord
  has_rich_text :content
  belongs_to :author, class_name: "User"

  scope :active, -> { where(active: true) }

  after_create :log_creation
  after_destroy :log_destruction

  private

  def log_creation
    ModerationLog.create!(
      moderator: author,
      action: "announcement_created",
      target: self,
      details: { active: active }
    )
  end

  def log_destruction
    ModerationLog.create!(
      moderator: author,
      action: "announcement_deleted",
      target_type: "Announcement",
      target_id: id,
      details: {}
    )
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/models/announcement_test.rb`
Expected: PASS (4 runs, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add app/models/announcement.rb test/models/announcement_test.rb test/fixtures/users.yml
git commit -m "feat: Announcement model with rich text and moderation logging"
```

---

### Task 4: Admin announcements controller + tests

**Files:**
- Create: `app/controllers/admin/announcements_controller.rb`
- Test: `test/controllers/admin/announcements_controller_test.rb`

- [ ] **Step 1: Write the failing controller test**

`test/controllers/admin/announcements_controller_test.rb`:
```ruby
require "test_helper"

class Admin::AnnouncementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    post session_path, params: { email_address: @admin.email_address, password: "password" }
  end

  test "admin can list announcements" do
    get admin_announcements_path
    assert_response :success
  end

  test "non-admin is denied" do
    delete session_path
    regular = users(:one)
    post session_path, params: { email_address: regular.email_address, password: "password" }
    get admin_announcements_path
    assert_redirected_to root_path
  end

  test "admin can create an active announcement" do
    assert_difference -> { Announcement.count }, 1 do
      post admin_announcements_path, params: {
        announcement: { active: "1", content: "<strong>Hello</strong> mods" }
      }
    end
    assert_redirected_to admin_announcements_path
    assert Announcement.last.active?
  end

  test "admin can toggle active off via update" do
    a = Announcement.create!(author: @admin, active: true)
    patch admin_announcement_path(a), params: { announcement: { active: "0" } }
    assert_redirected_to admin_announcements_path
    assert_not a.reload.active?
  end

  test "admin can destroy an announcement" do
    a = Announcement.create!(author: @admin, active: true)
    assert_difference -> { Announcement.count }, -1 do
      delete admin_announcement_path(a)
    end
    assert_redirected_to admin_announcements_path
  end
end
```
(Use the same fixture user(s) as Task 3. The password must match what the fixture/test sets — if unknown, set `password_digest` via the factory or use `@admin.update!(password: "password")` in `setup`.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/admin/announcements_controller_test.rb`
Expected: FAIL — uninitialized constant / route errors.

- [ ] **Step 3: Implement the controller**

`app/controllers/admin/announcements_controller.rb`:
```ruby
class Admin::AnnouncementsController < ApplicationController
  before_action :require_admin

  def index
    @announcements = Announcement.order(created_at: :desc)
  end

  def new
    @announcement = Announcement.new
  end

  def create
    @announcement = Announcement.new(announcement_params)
    @announcement.author = Current.user
    if @announcement.save
      redirect_to admin_announcements_path, notice: "Announcement created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @announcement = Announcement.find(params[:id])
  end

  def update
    @announcement = Announcement.find(params[:id])
    if @announcement.update(announcement_params)
      redirect_to admin_announcements_path, notice: "Announcement updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @announcement = Announcement.find(params[:id])
    @announcement.destroy!
    redirect_to admin_announcements_path, notice: "Announcement deleted."
  end

  private

  def announcement_params
    params.require(:announcement).permit(:active, :content)
  end
end
```

- [ ] **Step 4: Add the route**

In `config/routes.rb`, inside `namespace :admin do`, add:
```ruby
    resources :announcements, only: [:index, :new, :create, :edit, :update, :destroy]
```
Place it after the existing `resources :flags` block.

- [ ] **Step 5: Run the test to verify it passes**

Run: `bin/rails test test/controllers/admin/announcements_controller_test.rb`
Expected: PASS (all assertions green).

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/announcements_controller.rb config/routes.rb test/controllers/admin/announcements_controller_test.rb
git commit -m "feat: admin announcements CRUD with access control"
```

---

### Task 5: Admin announcement views (index / new / edit / form)

**Files:**
- Create: `app/views/admin/announcements/index.html.erb`
- Create: `app/views/admin/announcements/new.html.erb`
- Create: `app/views/admin/announcements/edit.html.erb`
- Create: `app/views/admin/announcements/_form.html.erb`

- [ ] **Step 1: Write the shared form partial**

`app/views/admin/announcements/_form.html.erb`:
```erb
<%= form_with model: [:admin, announcement], local: true, class: "space-y-4" do |form| %>
  <% if announcement.errors.any? %>
    <div class="rounded-lg border border-red-800 bg-red-900/30 p-3 text-sm text-red-300">
      <% announcement.errors.full_messages.each do |msg| %>
        <div><%= msg %></div>
      <% end %>
    </div>
  <% end %>

  <div>
    <label class="flex items-center gap-2 text-sm text-gray-300">
      <%= form.check_box :active, class: "rounded border-gray-600 bg-gray-800" %>
      Active (show to moderators)
    </label>
  </div>

  <div>
    <%= form.label :content, "Message", class: "block text-sm text-gray-400 mb-1" %>
    <%= form.rich_text_area :content, class: "trix-content bg-gray-900 text-gray-100" %>
  </div>

  <div class="flex gap-2">
    <%= form.submit "Save", class: "rounded-lg bg-amber-500 px-4 py-2 text-sm font-medium text-black hover:bg-amber-400 cursor-pointer" %>
    <%= link_to "Cancel", admin_announcements_path, class: "rounded-lg bg-gray-800 px-4 py-2 text-sm text-gray-300 hover:bg-gray-700" %>
  </div>
<% end %>
```

- [ ] **Step 2: Write the new view**

`app/views/admin/announcements/new.html.erb`:
```erb
<div class="max-w-3xl mx-auto">
  <h1 class="text-2xl font-bold mb-6">New Announcement</h1>
  <%= render "form", announcement: @announcement %>
</div>
```

- [ ] **Step 3: Write the edit view**

`app/views/admin/announcements/edit.html.erb`:
```erb
<div class="max-w-3xl mx-auto">
  <h1 class="text-2xl font-bold mb-6">Edit Announcement</h1>
  <%= render "form", announcement: @announcement %>
</div>
```

- [ ] **Step 4: Write the index view**

`app/views/admin/announcements/index.html.erb`:
```erb
<div class="max-w-6xl mx-auto">
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-2xl font-bold">Announcements</h1>
    <%= link_to "New Announcement", new_admin_announcement_path, class: "rounded-lg bg-amber-500 px-4 py-2 text-sm font-medium text-black hover:bg-amber-400" %>
  </div>

  <% if @announcements.any? %>
    <div class="space-y-3">
      <% @announcements.each do |announcement| %>
        <div class="rounded-xl border border-gray-800 bg-gray-900 p-4">
          <div class="flex items-start justify-between gap-4">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-2">
                <span class="rounded px-1.5 py-0.5 text-xs <%= announcement.active? ? 'bg-green-900/50 text-green-400' : 'bg-gray-800 text-gray-400' %>">
                  <%= announcement.active? ? "Active" : "Inactive" %>
                </span>
                <span class="text-xs text-gray-500">by <%= announcement.author.username %></span>
              </div>
              <div class="text-sm text-gray-200 trix-content"><%= announcement.content %></div>
            </div>
            <div class="flex flex-col gap-2 shrink-0">
              <%= link_to "Edit", edit_admin_announcement_path(announcement), class: "rounded-lg bg-gray-800 px-3 py-1 text-xs text-gray-300 hover:bg-gray-700" %>
              <%= button_to "Delete", admin_announcement_path(announcement), method: :delete,
                    form: { data: { turbo_confirm: "Delete this announcement?" } },
                    class: "rounded-lg bg-red-900/50 px-3 py-1 text-xs text-red-400 hover:bg-red-900" %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
  <% else %>
    <p class="text-sm text-gray-500">No announcements yet.</p>
  <% end %>
</div>
```

- [ ] **Step 5: Smoke-test the views render**

Run: `bin/rails runner 'av = ActionView::Base.with_empty_template_cache.new(ActionView::LookupContext.new(ActionController::Base.view_paths), {}, nil); av.singleton_class.class_eval { def admin_announcements_path(*); "/admin/announcements"; end; def new_admin_announcement_path(*); "/admin/announcements/new"; end; def edit_admin_announcement_path(*); "/admin/announcements/1/edit"; end; def admin_announcement_path(*); "/admin/announcements/1"; end }; puts av.render(file: "admin/announcements/index") rescue (puts $!.message); puts av.render(file: "admin/announcements/new") rescue (puts $!.message); puts av.render(file: "admin/announcements/edit") rescue (puts $!.message); puts "views parsed"'`

Expected: prints "views parsed" (each render succeeds or raises a clear, non-ERB-syntax error).

- [ ] **Step 6: Commit**

```bash
git add app/views/admin/announcements/
git commit -m "feat: admin announcement views with Trix editor"
```

---

### Task 6: Banner partial + layout injection

**Files:**
- Create: `app/views/shared/_announcement_banner.html.erb`
- Modify: `app/views/layouts/application.html.erb:73-74`

- [ ] **Step 1: Write the banner partial**

`app/views/shared/_announcement_banner.html.erb`:
```erb
<div class="w-full border-2 border-amber-500 rounded-xl bg-gray-900 px-4 py-3 text-center text-sm text-gray-100 trix-content">
  <%= announcement.content %>
</div>
```
(The `border-2` + `border-amber-500` = "outlined with primary color"; `rounded-xl` = border radius; `w-full` = full width; `trix-content` preserves bold/italic/underline/color from Trix HTML.)

- [ ] **Step 2: Inject active banners into the layout**

In `app/views/layouts/application.html.erb`, replace lines 73–74:
```erb
    </nav>
    <% if Current.user && (Current.user.moderator? || Current.user.admin? || Current.user.super_admin? || Current.user.reputation.to_i >= 500) %>
      <div class="w-full px-4 sm:px-6 lg:px-8 mt-14">
        <% Announcement.active.each do |announcement| %>
          <%= render "shared/announcement_banner", announcement: announcement %>
        <% end %>
      </div>
    <% end %>
    <main class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 pt-20 pb-8">
```
(The `mt-14` clears the fixed nav; banners render only for moderator+ roles, above `<main>`, full bleed. `Announcement.active` is the scope from Task 3.)

- [ ] **Step 3: Verify the layout still parses**

Run: `bin/rails runner 'puts ActionView::Base.with_empty_template_cache.new(ActionView::LookupContext.new(ActionController::Base.view_paths), {}, nil).render(file: "layouts/application") rescue (puts $!.message); puts "layout parsed"'`

Expected: prints "layout parsed".

- [ ] **Step 4: Commit**

```bash
git add app/views/shared/_announcement_banner.html.erb app/views/layouts/application.html.erb
git commit -m "feat: render active announcements as full-width banners for moderators"
```

---

### Task 7: Admin dashboard link

**Files:**
- Modify: `app/views/admin/dashboard/index.html.erb:27-30`

- [ ] **Step 1: Add the announcements quick-action link**

In `app/views/admin/dashboard/index.html.erb`, inside the Quick Actions `<div>`, after the "Moderation Logs" link, add:
```erb
        <%= link_to "Announcements", admin_announcements_path, class: "block rounded-lg bg-gray-800 px-4 py-2 text-sm text-gray-300 hover:bg-gray-700" %>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/admin/dashboard/index.html.erb
git commit -m "feat: link to announcements from admin dashboard"
```

---

### Task 8: End-to-end system test

**Files:**
- Test: `test/system/admin_announcements_test.rb`

- [ ] **Step 1: Write the system test**

`test/system/admin_announcements_test.rb`:
```ruby
require "application_system_test_case"

class AdminAnnouncementsTest < ApplicationSystemTestCase
  test "admin creates an announcement visible to a moderator" do
    admin = users(:admin)
    sign_in_as(admin)

    visit new_admin_announcement_path
    fill_in_rich_text_area "announcement_content", with: "Mods: <strong>new rule</strong> in effect"
    check "active"
    click_on "Save"

    assert_text "Announcement created"
    assert_text "new rule"

    # A moderator now sees the banner at the top
    moderator = users(:moderator)
    sign_in_as(moderator)
    visit mod_root_path
    within ".trix-content" do
      assert_text "new rule"
    end
  end
end
```
(Ensure `users(:moderator)` exists in `test/fixtures/users.yml` with `role: moderator`, `reputation: 5000`. If `fill_in_rich_text_area` is unavailable on this Rails version, use `find("trix-editor").click; page.find("trix-editor").set "..."` instead.)

- [ ] **Step 2: Run the system test**

Run: `bin/rails test test/system/admin_announcements_test.rb`
Expected: PASS (banner appears for the moderator, content shows the bold "new rule").

- [ ] **Step 3: Commit**

```bash
git add test/system/admin_announcements_test.rb
git commit -m "test: admin announcement shows as moderator banner E2E"
```

---

### Task 9: Full regression + manual checklist

- [ ] **Step 1: Run the whole suite**

Run: `bin/rails test`
Expected: all tests green, including the new model/controller/system tests.

- [ ] **Step 2: Manual sanity (if a browser/server is available)**

Run `bin/rails server`, log in as an admin, visit `/admin/announcements`, create an announcement with bold + a colored word, set active = true, save. Then log in as a moderator (or use the admin account which also qualifies) and visit the mod dashboard — confirm the full-width amber-outlined banner appears at the top, and that bold/color formatting is preserved.

- [ ] **Step 3: Final commit (if any loose changes)**

```bash
git add -A
git commit -m "feat: admin announcements for moderators (ActionText + banner)"
```

---

## Self-Review

**1. Spec coverage:**
- "administrator able to create announcements to moderators" → Admin CRUD controller (Task 4) + views (Task 5). ✅
- "text editor in admin to create Note object" → Trix via ActionText (Task 1) + form (Task 5). ✅
- "Note has active boolean + content text field" → migration (Task 2) + model `active` + `has_rich_text :content` (Task 3). ✅
- "content needs bold/underline/italic/font color" → Trix rich text editor provides all four; rendered via `.trix-content` (Tasks 1, 5, 6). ✅
- "display full width on top of body in moderator panel" → layout injection above `<main>`, `w-full` (Task 6). ✅
- "all where active true displayed as full-width, outlined primary color, border radius" → `border-2 border-amber-500 rounded-xl w-full` (Task 6). ✅

**2. Placeholder scan:** No TBD/TODO. Active-toggle, render, logging all shown. ✅

**3. Type consistency:** `Announcement.active` scope used in model test, controller, and layout — consistent. Route helpers `admin_announcements_path` etc. match `resources :announcements` in `namespace :admin`. `author`/`belongs_to :author` consistent across model, migration FK, and logging. `content` is ActionText rich text (no DB column) — consistent with `has_rich_text :content`. ✅
