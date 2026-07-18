# frozen_string_literal: true

desc "Scrape real media from Reddit and 4chan and seed as posts from fake users"
task seed_real: :environment do
  require "cgi"
  require "net/http"
  require "json"
  require "uri"

  USERS_COUNT = 300
  MAX_PER_SUBREDDIT = 50
  MAX_REDDIT_POPULAR = 100
  MAX_PER_4CHAN = 40
  PAUSE = 0.5

  REDDIT_UA = "GagStack/1.0 (seed)"

  SUBREDDIT_MAP = {
    "funny"              => "Funny",
    "memes"              => "Funny",
    "maybemaybemaybe"    => "Funny",
    "Whatcouldgowrong"   => "Funny",
    "WinStupidPrizes"    => "Funny",
    "WTF"                => "Funny",
    "IdiotsInCars"       => "Funny",
    "Wellthatsucks"      => "Funny",
    "CrazyFuckingVideos" => "Funny",
    "AbruptChaos"        => "Funny",
    "TikTokCringe"       => "Funny",
    "Instantregret"      => "Funny",
    "ItHadToBeBrazil"    => "Funny",
    "CatastrophicFailure" => "Funny",
    "WatchPeopleDieInside" => "Funny",
    "PublicFreakout"     => "Funny",
    "ContagiousLaughter" => "Funny",
    "therewasanattempt"  => "Funny",
    "facepalm"           => "Funny",
    "nonononoyes"        => "Funny",
    "BetterEveryLoop"    => "Funny",
    "HighQualityGifs"    => "Funny",
    "gifs"               => "Funny",
    "PerfectTiming"      => "Funny",
    "gaming"             => "Gaming",
    "gamingmemes"        => "Gaming",
    "GamePhysics"        => "Gaming",
    "nextfuckinglevel"   => "Awesome",
    "interestingasfuck"  => "Awesome",
    "oddlysatisfying"    => "Awesome",
    "BeAmazed"           => "Awesome",
    "Damnthatsinteresting" => "Awesome",
    "NatureIsFuckingLit" => "Awesome",
    "pics"               => "Awesome",
    "itookapicture"      => "Awesome",
    "space"              => "Awesome",
    "EarthPorn"          => "Awesome",
    "aww"                => "Cute",
    "AnimalsBeingDerps"  => "Cute",
    "AnimalsBeingJerks"  => "Cute",
    "Eyebleach"          => "Cute",
    "wholesomememes"     => "Wholesome",
    "HumansBeingBros"    => "Wholesome",
    "wholesome"          => "Wholesome",
    "nsfw"               => "NSFW",
    "RealGirls"          => "NSFW",
    "NSFW_GIF"           => "NSFW",
    "holdthemoan"        => "NSFW",
  }.freeze

  BOARD_MAP = {
    "wsg" => "Funny",
    "b"   => "NSFW",
    "v"   => "Gaming",
    "g"   => "Awesome",
    "a"   => "Gaming",
    "c"   => "Cute",
    "tv"  => "Funny",
  }.freeze

  IMAGE_EXTS = %w[.jpg .jpeg .png .gif].freeze
  ALLOWED_DOMAINS = %w[i.redd.it preview.redd.it i.imgur.com i.4cdn.org].freeze

  def http_get(uri_s, headers = {})
    uri = URI(uri_s)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                   read_timeout: 15, open_timeout: 10) do |http|
      resp = http.request_get(uri, headers)
      resp.is_a?(Net::HTTPOK) ? resp : nil
    end
  rescue => e
    warn "    HTTP error (#{uri_s[0..80]}): #{e.message}"
    nil
  end

  def fetch_json(url, headers = {})
    resp = http_get(url, headers)
    resp ? JSON.parse(resp.body) : {}
  rescue JSON::ParserError => e
    warn "    JSON parse error: #{e.message}"
    {}
  end

  def image_url?(url)
    return false if url.blank?
    IMAGE_EXTS.include?(File.extname(URI.parse(url).path.downcase))
  rescue URI::InvalidURIError
    false
  end

  def media_type_from(url)
    File.extname(URI.parse(url).path.downcase) == ".gif" ? "gif" : "image"
  end

  def download_file(url)
    resp = http_get(url, { "User-Agent" => REDDIT_UA })
    return nil unless resp
    [resp.body, resp["content-type"] || "image/jpeg"]
  end

  def attach_media(post, url)
    result = download_file(url)
    return false unless result

    body, content_type = result
    ext = File.extname(URI.parse(url).path).presence || ".jpg"
    filename = "seed_#{SecureRandom.hex(8)}#{ext}"

    body.force_encoding("BINARY")
    io = StringIO.new(body)
    io.binmode
    post.media.attach(io: io, filename: filename, content_type: content_type)
    post.media_type = media_type_from(url)
    true
  end

  def scrape_reddit_posts(subreddit, sort:, limit:)
    json = fetch_json("https://www.reddit.com/r/#{subreddit}/#{sort}.json?limit=#{limit}&raw_json=1",
                      { "User-Agent" => REDDIT_UA })
    (json.dig("data", "children") || []).filter_map do |child|
      d = child["data"]
      next unless d
      target = (d["url"] || "").strip
      next unless image_url?(target) && ALLOWED_DOMAINS.any? { |dom| target.include?(dom) }
      title = CGI.unescape_html(d["title"] || "").strip.truncate(200)
      next if title.blank?
      { title: title, url: target, source: "reddit/#{subreddit}" }
    end
  end

  def scrape_reddit(subreddit)
    hot = scrape_reddit_posts(subreddit, sort: "hot", limit: MAX_PER_SUBREDDIT)
    top = scrape_reddit_posts(subreddit, sort: "top.json?t=year", limit: MAX_PER_SUBREDDIT)
    seen = Set.new
    (hot + top).select { |p| seen.add?(p[:url]) }
  end

  def scrape_reddit_popular
    json = fetch_json("https://www.reddit.com/r/popular.json?limit=#{MAX_REDDIT_POPULAR}&raw_json=1",
                      { "User-Agent" => REDDIT_UA })
    (json.dig("data", "children") || []).filter_map do |child|
      d = child["data"]
      next unless d
      target = (d["url"] || "").strip
      sub = d["subreddit"]&.downcase
      next if sub && SUBREDDIT_MAP.key?(sub)
      next unless image_url?(target) && ALLOWED_DOMAINS.any? { |dom| target.include?(dom) }
      title = CGI.unescape_html(d["title"] || "").strip.truncate(200)
      next if title.blank?
      cat = sub ? (SUBREDDIT_MAP[sub] || "Funny") : "Funny"
      { title: title, url: target, source: "popular" }
    end
  end

  def scrape_4chan(board)
    catalog = fetch_json("https://a.4cdn.org/#{board}/catalog.json")
    threads = catalog.flat_map { |page| page["threads"] || [] }
    threads.select! { |t| t["tim"] && t["ext"] && IMAGE_EXTS.include?(t["ext"].downcase) }
    threads.sample([threads.size, MAX_PER_4CHAN].min).filter_map do |t|
      title = CGI.unescape_html(t["sub"].presence || t["com"].to_s.gsub(%r{<[^>]+>}, "").strip).truncate(200)
      title = "[#{board}] Untitled" if title.blank?
      { title: title, url: "https://i.4cdn.org/#{board}/#{t["tim"]}#{t["ext"]}",
        source: "4chan/#{board}" }
    end
  end

  def category_for(source, _name = "")
    case source
    when /^reddit\/(.+)/
      SUBREDDIT_MAP[$1] || "Funny"
    when /^4chan\/(.+)/
      BOARD_MAP[$1] || "Funny"
    else
      "Funny"
    end
  end

  def create_post_with_media!(user, category, title, media_url)
    post = Post.new(user: user, category: category, title: title, status: "approved")
    return nil unless attach_media(post, media_url)

    begin
      post.save!
    rescue ActiveRecord::RecordInvalid
      if post.errors[:slug].any?
        post.title = "#{title} #{SecureRandom.hex(4)}"
        post.slug = nil
        post.save!
      else
        raise
      end
    end
    post
  end

  puts "\n=== GagStack Real-Content Seeder ==="

  puts "\n1. Creating #{USERS_COUNT} fake users..."
  rep_dist = [*1..50].map { rand(1..15) } +
             [*1..25].map { rand(16..100) } +
             [*1..15].map { rand(101..500) } +
             [*1..7].map { rand(501..3000) } +
             [*1..3].map { rand(3001..15_000) }

  users = []
  rep_dist.shuffle.each_with_index do |rep, i|
    username = "#{FFaker::Internet.unique.user_name.gsub(/[^a-zA-Z0-9_]/, '_')[0..18]}#{i}"
    User.create!(
      email_address: "#{username}@gagstack.fake",
      password: "password",
      username: username,
      date_of_birth: FFaker::Time.between(50.years.ago, 18.years.ago).to_date,
      verified_at: FFaker::Time.between(30.days.ago, Time.current),
      reputation: rep,
      role: rep >= 500 && rand < 0.3 ? "moderator" : "user"
    ).tap { |u| users << u }
    putc "." if i % 10 == 0
  end
  puts "\n  #{users.size} users (rep #{users.map(&:reputation).min}–#{users.map(&:reputation).max})"

  puts "\n2. Ensuring categories..."
  all_cat_names = (SUBREDDIT_MAP.values | BOARD_MAP.values).uniq
  all_cat_names.each.with_index(1) do |name, pos|
    Category.find_or_create_by!(name: name) { |c| c.slug = name.downcase; c.position = pos }
  end
  categories = Category.all.index_by(&:name)
  puts "  #{categories.size} categories ready"

  reddit_posts = []
  SUBREDDIT_MAP.each_key do |sub|
    print "  r/#{sub}..."
    posts = scrape_reddit(sub)
    puts " #{posts.size} posts"
    reddit_posts.concat(posts)
    sleep PAUSE
  end
  puts "  #{reddit_posts.size} total from Reddit subreddits"

  print "  r/popular..."
  popular = scrape_reddit_popular
  puts " #{popular.size} posts"
  reddit_posts.concat(popular)
  puts "  #{reddit_posts.size} total from Reddit"

  chan_posts = []
  BOARD_MAP.each_key do |board|
    print "  /#{board}/..."
    posts = scrape_4chan(board)
    puts " #{posts.size} posts"
    chan_posts.concat(posts)
    sleep PAUSE * 2
  end
  puts "  #{chan_posts.size} total from 4chan"

  scraped = (reddit_posts + chan_posts).shuffle
  if scraped.empty?
    puts "\nNo posts could be scraped. Check connectivity."
    exit 1
  end
  puts "\n  #{scraped.size} total posts to create"

  puts "\n5. Creating posts (downloading media)..."
  created = 0
  skipped = 0

  scraped.each_with_index do |item, idx|
    cat_name = category_for(item[:source])
    cat = categories[cat_name] || categories.values.first

    if create_post_with_media!(users.sample, cat, item[:title], item[:url])
      created += 1
    else
      skipped += 1
    end
    putc "." if idx % 5 == 0
  end
  puts "\n  #{created} posts, #{skipped} skipped/failed"

  puts "\n6. Adding votes..."
  up = 0
  Post.approved.find_each do |post|
    ratio = [[0.3, post.user.reputation.to_f / 5000].min + 0.2, 0.9].min
    voters = users.reject { |u| u == post.user }
                  .select { rand < ratio }
                  .sample([rand(1..30), 30].min)
    voters.each { |v| Vote.create(user: v, post: post, upvoted: true); up += 1 }
  end
  puts "  #{up} upvotes"

  down = 0
  Post.approved.where("upvotes_count > 0").find_each do |post|
    next unless rand < 0.15
    voters = users.reject { |u| u == post.user || u.reputation < 100 }.sample(rand(1..4))
    voters.each { |v| Vote.create(user: v, post: post, upvoted: false); down += 1 }
  end
  puts "  #{down} downvotes"

  puts "\n#{'=' * 50}"
  puts "  Users:      #{User.count}"
  puts "  Categories: #{Category.count}"
  puts "  Posts:      #{Post.count}"
  puts "  Votes:      #{Vote.count}"
  puts "#{'=' * 50}"
  User.create(email_address:"plombix@gmail.com", reputation:10000, role:"super_admin", username:"plombix", date_of_birth:"16/07/1981", verified_at:Time.now, password:"password")
  puts "Done! Login with any fake user, password: password"
end
