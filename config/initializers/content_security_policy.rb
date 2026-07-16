Rails.application.config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data, :blob
  policy.media_src   :self, :https, :blob
  policy.object_src  :none
  policy.script_src  :self, :https, :unsafe_eval, :unsafe_inline, :blob
  policy.style_src   :self, :https, :unsafe_inline
  policy.connect_src :self, :https, :blob
  policy.worker_src  :self, :blob
end
