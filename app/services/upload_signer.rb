class UploadSigner
  def initialize(user)
    @user = user
    @expires_in = 3600
  end

  def signed_upload_url
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: "upload",
      content_type: "image/jpeg",
      byte_size: 0
    )
    {
      url: blob.service_url_for_direct_upload(expires_in: @expires_in),
      headers: blob.service_headers_for_direct_upload,
      blob_signed_id: blob.signed_id,
      watermark_key: generate_watermark_key
    }
  end

  private

  def generate_watermark_key
    SecureRandom.hex(16)
  end
end
