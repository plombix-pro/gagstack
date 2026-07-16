module AvatarHelper
  PRIVILEGE_CLOCK_POSITIONS = {
    1 => 270,   # 9 o'clock
    2 => 300,   # 10 o'clock
    3 => 330,   # 11 o'clock
    4 => 0,     # 12 o'clock
    5 => 30,    # 1 o'clock
    6 => 60,    # 2 o'clock
    7 => 90,    # 3 o'clock
    8 => 120,   # 4 o'clock
    9 => 150,   # 5 o'clock
    10 => 180,  # 6 o'clock
    11 => 210,  # 7 o'clock
    12 => 240   # 8 o'clock
  }.freeze

  def avatar_tag(user, size: 32, show_dots: false, earned: nil, linked: true)
    avatar = content_tag :div, class: "relative inline-flex shrink-0", style: "width: #{size}px; height: #{size}px" do
      concat avatar_image(user, size)
      if show_dots && earned.present?
        earned.each_with_index do |_, idx|
          pos = idx + 1
          deg = PRIVILEGE_CLOCK_POSITIONS[pos] || 0
          center = size / 2
          dot_radius = center + 4
          rad = deg * Math::PI / 180
          dot_x = center + dot_radius * Math.sin(rad)
          dot_y = center - dot_radius * Math.cos(rad)
          concat content_tag :div, "",
            class: "absolute rounded-full bg-amber-500",
            style: "width: 4px; height: 4px; left: #{dot_x}px; top: #{dot_y}px; transform: translate(-50%, -50%)"
        end
      end
    end
    if linked && user&.slug.present?
      link_to avatar, public_profile_path(user.slug), class: "hover:opacity-80 transition-opacity"
    else
      avatar
    end
  end

  private

  def avatar_image(user, size)
    if user.avatar.attached?
      variant = user.avatar.variant(resize_to_fill: [size, size])
      image_tag variant, class: "rounded-full ring-2 ring-amber-500 object-cover",
        style: "width: #{size}px; height: #{size}px",
        alt: user.username
    else
      font_size = size * 0.4
      content_tag :div,
        user.username.first.upcase,
        class: "rounded-full ring-2 ring-amber-500 flex items-center justify-center font-bold text-amber-500 bg-gray-800",
        style: "width: #{size}px; height: #{size}px; font-size: #{font_size}px"
    end
  end
end
